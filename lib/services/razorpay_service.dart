import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'razorpay_edge_functions.dart';

/// Outcome of [RazorpayService.pay]. Exactly one of [success]/[cancelled]/
/// [initializationFailed]/(neither, i.e. a plain failure) is true.
class RazorpayOrderResult {
  final bool success;
  final bool cancelled;

  /// True only when Razorpay itself never got a chance to show the
  /// customer anything - the key isn't configured, order creation failed
  /// before checkout opened, or (web only) checkout.js never finished
  /// loading. Distinct from a plain [failure] (Razorpay opened fine but the
  /// payment itself was declined/errored) because callers may want to react
  /// differently - e.g. PaymentMethodScreen falls back to the QR flow on
  /// web only in this case, not on every payment failure.
  final bool initializationFailed;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;

  /// Razorpay's own confirmed payment amount in paise, from
  /// verify-razorpay-payment re-fetching the order — null if that
  /// defense-in-depth re-fetch itself failed (the signature check, which
  /// already proves the payment is genuine, still passed).
  final int? verifiedAmountPaise;
  final String? errorMessage;

  const RazorpayOrderResult._({
    required this.success,
    required this.cancelled,
    this.initializationFailed = false,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.verifiedAmountPaise,
    this.errorMessage,
  });

  factory RazorpayOrderResult.success({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    int? verifiedAmountPaise,
  }) => RazorpayOrderResult._(
    success: true,
    cancelled: false,
    razorpayOrderId: razorpayOrderId,
    razorpayPaymentId: razorpayPaymentId,
    verifiedAmountPaise: verifiedAmountPaise,
  );

  factory RazorpayOrderResult.failure(String message) =>
      RazorpayOrderResult._(success: false, cancelled: false, errorMessage: message);

  factory RazorpayOrderResult.cancelled() =>
      const RazorpayOrderResult._(success: false, cancelled: true);

  factory RazorpayOrderResult.initializationFailed(String message) =>
      RazorpayOrderResult._(
        success: false,
        cancelled: false,
        initializationFailed: true,
        errorMessage: message,
      );
}

/// Wraps the razorpay_flutter Checkout SDK plus the two Supabase Edge
/// Functions (`create-razorpay-order`, `verify-razorpay-payment`) that keep
/// RAZORPAY_KEY_SECRET server-side — see scripts/MIGRATION_RAZORPAY.md.
/// Android/iOS only; razorpay_flutter has no web support.
class RazorpayService {
  final Razorpay _razorpay = Razorpay();
  Completer<RazorpayOrderResult>? _completer;

  RazorpayService() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  Future<RazorpayOrderResult> pay({
    required double amount,
    required String businessName,
    required String description,
    required String customerName,
    required String customerPhone,
  }) async {
    if (_completer != null) {
      return RazorpayOrderResult.failure('A payment is already in progress.');
    }

    final keyId = dotenv.env['RAZORPAY_KEY_ID'];
    if (keyId == null || keyId.isEmpty) {
      return RazorpayOrderResult.initializationFailed(
        'Payments are not configured yet.',
      );
    }

    _completer = Completer<RazorpayOrderResult>();
    try {
      final data = await createRazorpayOrder(amount: amount);
      final razorpayOrderId = data['orderId'] as String;

      _razorpay.open({
        'key': keyId,
        'amount': data['amount'],
        'currency': data['currency'] ?? 'INR',
        'order_id': razorpayOrderId,
        'name': businessName,
        'description': description,
        'prefill': {'contact': customerPhone, 'name': customerName},
      });

      return await _completer!.future;
    } on RazorpayEdgeFunctionException catch (e) {
      // Failed before Razorpay ever opened (order creation, not the payment
      // itself) - counts as an initialization failure, same as a missing key.
      _completer = null;
      return RazorpayOrderResult.initializationFailed(e.message);
    } catch (error) {
      _completer = null;
      return RazorpayOrderResult.initializationFailed(
        'Could not start payment: $error',
      );
    }
  }

  Future<void> _onSuccess(PaymentSuccessResponse response) async {
    final completer = _completer;
    _completer = null;
    if (completer == null) return;

    final orderId = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (orderId == null || paymentId == null || signature == null) {
      completer.complete(
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
        completer.complete(
          RazorpayOrderResult.failure(
            data['error'] as String? ?? 'Payment could not be verified.',
          ),
        );
        return;
      }
      completer.complete(
        RazorpayOrderResult.success(
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          verifiedAmountPaise: data['amount'] as int?,
        ),
      );
    } on RazorpayEdgeFunctionException catch (e) {
      completer.complete(RazorpayOrderResult.failure(e.message));
    } catch (error) {
      completer.complete(
        RazorpayOrderResult.failure('Payment could not be verified: $error'),
      );
    }
  }

  void _onError(PaymentFailureResponse response) {
    final completer = _completer;
    _completer = null;
    if (completer == null) return;

    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      completer.complete(RazorpayOrderResult.cancelled());
    } else {
      completer.complete(
        RazorpayOrderResult.failure(response.message ?? 'Payment failed.'),
      );
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    final completer = _completer;
    _completer = null;
    // No reliable success signal follows this event in the SDK - fail
    // closed rather than guessing the wallet payment went through.
    completer?.complete(
      RazorpayOrderResult.failure(
        'Please complete the payment in ${response.walletName ?? 'your wallet app'}, '
        'then check "My Orders" — if it did not go through, try again.',
      ),
    );
  }

  void dispose() => _razorpay.clear();
}
