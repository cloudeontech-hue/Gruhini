import 'dart:async';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_web/razorpay_web.dart' as rzp_web;

import 'razorpay_edge_functions.dart';
import 'razorpay_service.dart' show RazorpayOrderResult;

/// Web and Windows Razorpay Checkout path — razorpay_flutter (used by
/// [RazorpayService] for Android/iOS) has no support for either platform.
/// Uses the community package `razorpay_web` (not affiliated with or
/// endorsed by Razorpay):
/// - On **web**, it dynamically injects Razorpay's own `checkout.js` into
///   the page and opens the standard browser popup/redirect Checkout.
/// - On **Windows**, it embeds `checkout.js` inside a WebView2-backed
///   dialog via `flutter_inappwebview` (there is no first-party browser
///   context to inject into, since it's a native desktop app).
///
/// Both cases go through the exact same `razorpay_web` `Razorpay` class and
/// event API, so one service class covers both — see
/// scripts/MIGRATION_RAZORPAY.md for build requirements/caveats on each
/// platform. Only the Windows path is unverified by me (no Windows machine
/// available); the web path uses `razorpay_web`'s own web plugin
/// registration (declared in its pubspec, no manual `web/index.html`
/// changes needed) and was exercised via `flutter analyze`/`flutter test`
/// (which run on this Linux host as a web-shaped Dart environment) but not
/// a real browser payment.
///
/// Mirrors [RazorpayService]'s shape (same [RazorpayOrderResult], same
/// create/verify Edge Function calls via razorpay_edge_functions.dart) so
/// PaymentMethodScreen can treat both services almost identically; the only
/// difference is `razorpay_web`'s `Razorpay.open()` takes an optional
/// [BuildContext] that Windows needs (to host the checkout dialog) and web
/// ignores.
///
/// Every [pay] call is tracked by its own [_RazorpayAttempt], and the
/// success/error/external-wallet listeners registered for that call are
/// closures over that specific attempt object - not shared mutable fields
/// read by every callback regardless of which attempt they came from. This
/// matters once retries are possible (tap Pay Now, fail, tap it again): a
/// stale callback from an earlier attempt can never be misread as belonging
/// to the current one.
class RazorpayWebService {
  /// Safety net for a gap in razorpay_web's web implementation: if the
  /// dynamically-injected `checkout.js` `<script>` tag fails to load (e.g.
  /// blocked by an ad-blocker, offline, CSP), its `load` event never fires
  /// and nothing ever completes the payment - there's no `error` listener
  /// upstream to catch that. This timeout is a heuristic, not a true
  /// "script load failed" signal (there's no such signal to listen for
  /// without patching the DOM ourselves), so it's deliberately generous -
  /// long enough that a customer slowly entering card details or an OTP
  /// during a real, successfully-opened checkout won't get bumped by it.
  static const _initializationTimeout = Duration(minutes: 3);

  rzp_web.Razorpay? _razorpay;

  /// Non-null only while a [pay] call is in flight and hasn't yet returned
  /// (including the timeout case) - gates the "already in progress" guard
  /// below. Deliberately *not* how late (post-timeout) events are routed;
  /// each attempt's own closures handle that via [_RazorpayAttempt] itself,
  /// so this can be cleared the moment [pay] returns without affecting a
  /// still-open checkout's ability to report back later.
  _RazorpayAttempt? _inFlight;

  Future<RazorpayOrderResult> pay({
    required BuildContext context,
    required double amount,
    required String businessName,
    required String description,
    required String customerName,
    required String customerPhone,
    /// Called if a genuine Razorpay result arrives after this [pay] call
    /// already returned via [_initializationTimeout] - see the class doc.
    /// The checkout may still have been open and completed for real at
    /// that point; this is the only way such a result is ever reported,
    /// since nothing is awaiting the returned Future anymore.
    void Function(RazorpayOrderResult result)? onLateResult,
  }) async {
    if (_inFlight != null) {
      return RazorpayOrderResult.failure('A payment is already in progress.');
    }

    final keyId = dotenv.env['RAZORPAY_KEY_ID'];
    if (keyId == null || keyId.isEmpty) {
      return RazorpayOrderResult.initializationFailed(
        'Payments are not configured yet.',
      );
    }

    // Detach the previous attempt's listeners (if this is a retry after a
    // failure/timeout on the same screen visit) before creating a new
    // Razorpay instance below. Not strictly required for correctness (each
    // attempt's closures are already self-contained - see class doc), but
    // stops a stale JS-side checkout from doing pointless work indefinitely.
    _razorpay?.clear();

    final attempt = _RazorpayAttempt(onLateResult);
    _inFlight = attempt;

    // Built fresh per payment attempt (razorpay_web's Razorpay() constructor
    // is a trivial EventEmitter wrapper with no platform-channel side
    // effects) rather than kept as a persistent field, so each attempt gets
    // its own clean listener lifecycle.
    final razorpay = rzp_web.Razorpay();
    _razorpay = razorpay;
    razorpay.on(
      rzp_web.Razorpay.EVENT_PAYMENT_SUCCESS,
      (response) => _onSuccess(attempt, response),
    );
    razorpay.on(
      rzp_web.Razorpay.EVENT_PAYMENT_ERROR,
      (response) => _onError(attempt, response),
    );
    razorpay.on(
      rzp_web.Razorpay.EVENT_EXTERNAL_WALLET,
      (response) => _onExternalWallet(attempt, response),
    );

    try {
      final data = await createRazorpayOrder(amount: amount);
      final razorpayOrderId = data['orderId'] as String;

      // context is used after the await above (order creation is a network
      // round-trip) to host the checkout dialog on Windows - re-check it's
      // still valid rather than handing a stale/deactivated context to
      // razorpay_web. (Web ignores context entirely, but the check is cheap
      // and harmless there too.)
      if (!context.mounted) {
        return RazorpayOrderResult.failure('Payment screen was closed.');
      }

      razorpay.open({
        'key': keyId,
        'amount': data['amount'],
        'currency': data['currency'] ?? 'INR',
        'order_id': razorpayOrderId,
        'name': businessName,
        'description': description,
        'prefill': {'contact': customerPhone, 'name': customerName},
      }, context: context);

      return await attempt.completer.future.timeout(
        _initializationTimeout,
        // Not proof the checkout is dead - see the class/field doc above.
        // Marking attempt.timedOut (rather than completing/abandoning it)
        // means a genuine _onSuccess/_onError arriving after this fires is
        // still observed and reported via onLateResult.
        onTimeout: () {
          attempt.timedOut = true;
          return RazorpayOrderResult.initializationFailed(
            'The payment page could not be loaded.',
          );
        },
      );
    } on RazorpayEdgeFunctionException catch (e) {
      // Failed before Razorpay ever opened (order creation, not the payment
      // itself) - counts as an initialization failure, same as a missing key.
      return RazorpayOrderResult.initializationFailed(e.message);
    } catch (error) {
      return RazorpayOrderResult.initializationFailed(
        'Could not start payment: $error',
      );
    } finally {
      // pay() is done returning either way - a new attempt may start. This
      // is independent of whether *this* attempt can still report a late
      // result: that's routed via the closure-captured `attempt` object
      // itself (see _onSuccess etc.), not this field.
      if (identical(_inFlight, attempt)) {
        _inFlight = null;
      }
    }
  }

  Future<void> _onSuccess(
    _RazorpayAttempt attempt,
    rzp_web.PaymentSuccessResponse response,
  ) async {
    if (attempt.resolved) return;

    final orderId = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (orderId == null || paymentId == null || signature == null) {
      attempt.resolve(
        RazorpayOrderResult.failure('Payment response was incomplete.'),
      );
      return;
    }

    try {
      final data = await verifyRazorpayPayment(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );
      if (data['verified'] != true) {
        attempt.resolve(
          RazorpayOrderResult.failure(
            data['error'] as String? ?? 'Payment could not be verified.',
          ),
        );
        return;
      }
      attempt.resolve(
        RazorpayOrderResult.success(
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          verifiedAmountPaise: data['amount'] as int?,
        ),
      );
    } on RazorpayEdgeFunctionException catch (e) {
      attempt.resolve(RazorpayOrderResult.failure(e.message));
    } catch (error) {
      attempt.resolve(
        RazorpayOrderResult.failure('Payment could not be verified: $error'),
      );
    }
  }

  void _onError(
    _RazorpayAttempt attempt,
    rzp_web.PaymentFailureResponse response,
  ) {
    if (attempt.resolved) return;

    if (response.code == rzp_web.Razorpay.PAYMENT_CANCELLED) {
      attempt.resolve(RazorpayOrderResult.cancelled());
    } else {
      attempt.resolve(
        RazorpayOrderResult.failure(response.message ?? 'Payment failed.'),
      );
    }
  }

  void _onExternalWallet(
    _RazorpayAttempt attempt,
    rzp_web.ExternalWalletResponse response,
  ) {
    if (attempt.resolved) return;
    // No reliable success signal follows this event in the SDK - fail
    // closed rather than guessing the wallet payment went through.
    attempt.resolve(
      RazorpayOrderResult.failure(
        'Please complete the payment in ${response.walletName ?? 'your wallet app'}, '
        'then check "My Orders" — if it did not go through, try again.',
      ),
    );
  }

  void dispose() => _razorpay?.clear();
}

/// Per-[RazorpayWebService.pay]-call state, captured by that call's event
/// listener closures so a stale/duplicate callback can never be misapplied
/// to a different (or no-longer-running) attempt.
class _RazorpayAttempt {
  final Completer<RazorpayOrderResult> completer = Completer();
  final void Function(RazorpayOrderResult result)? onLateResult;

  /// Set by [RazorpayWebService.pay]'s timeout - see its doc.
  bool timedOut = false;

  bool _resolved = false;
  bool get resolved => _resolved;

  _RazorpayAttempt(this.onLateResult);

  /// Routes [result] to whichever consumer can actually observe it: the
  /// original [RazorpayWebService.pay] caller (still awaiting [completer])
  /// normally, or [onLateResult] if that call already returned via the
  /// initialization timeout. No-ops if already called once for this attempt
  /// (e.g. a duplicate event firing twice for the same payment).
  void resolve(RazorpayOrderResult result) {
    if (_resolved) return;
    _resolved = true;
    if (timedOut) {
      onLateResult?.call(result);
    } else {
      completer.complete(result);
    }
  }
}
