import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/razorpay_service.dart';
import '../../services/razorpay_web_service.dart';
import '../../state/auth_provider.dart';
import '../../state/business_settings_provider.dart';
import '../../state/cart_provider.dart';
import '../../state/orders_provider.dart';
import '../../utils/delivery_fee.dart';
import '../../widgets/responsive_center.dart';
import 'order_placed_screen.dart';
import 'upi_payment_screen.dart';

/// On Android/iOS, Razorpay Checkout (via the official razorpay_flutter SDK)
/// is the only payment path: it's cryptographically verified server-side
/// (see lib/services/razorpay_service.dart and
/// scripts/MIGRATION_RAZORPAY.md), so no shop-owner manual verification step
/// is needed afterwards. On web and Windows, the same Edge-Function-verified
/// flow is used via the community package razorpay_web instead (see
/// lib/services/razorpay_web_service.dart) since razorpay_flutter doesn't
/// support either platform - web opens Razorpay's checkout.js popup directly
/// in the browser, Windows embeds it in a WebView2 dialog. If Razorpay fails
/// to even initialize on web (misconfigured key, checkout.js couldn't load),
/// this screen automatically navigates to the QR-code +
/// manual-verification flow (UpiPaymentScreen -> PaymentConfirmationScreen)
/// instead of leaving the customer stuck - see [_payWithRazorpay]. That flow
/// also remains the only, directly-buttoned path on Linux/macOS, where no
/// Razorpay integration is wired up at all (out of scope).
class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  // Nullable and only constructed when _razorpaySupported - the Razorpay()
  // constructor itself fires a platform-channel call immediately (see
  // razorpay_flutter's _resync()), which throws MissingPluginException on
  // any platform without the native plugin registered (web, Linux/Windows/
  // macOS desktop). Must not be constructed on those platforms at all, not
  // even lazily - a `late final` field here previously got initialized by
  // dispose() unconditionally reading it, crashing on desktop.
  RazorpayService? _razorpayService;
  // Safe to construct unconditionally, unlike RazorpayService above: its
  // Razorpay() (from package:razorpay_web) is a bare EventEmitter wrapper
  // with no platform-channel call in its constructor, and RazorpayWebService
  // itself doesn't touch the underlying SDK until pay() is called - which
  // only ever happens from the web/Windows-only button.
  final _razorpayWebService = RazorpayWebService();
  bool _isProcessing = false;

  bool get _razorpaySupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get _razorpayWindowsSupported => !kIsWeb && Platform.isWindows;

  bool get _razorpayWebSupported => kIsWeb;

  /// True whenever RazorpayWebService is the one to use - i.e. every
  /// platform _razorpaySupported (native mobile SDK) doesn't cover.
  bool get _razorpayWebServiceSupported =>
      _razorpayWebSupported || _razorpayWindowsSupported;

  @override
  void initState() {
    super.initState();
    if (_razorpaySupported) {
      _razorpayService = RazorpayService();
    }
  }

  @override
  void dispose() {
    _razorpayService?.dispose();
    _razorpayWebService.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showAmountMismatchDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Payment amount mismatch'),
        content: const Text(
          'The confirmed payment amount does not match your cart total. '
          'Your order was not placed. Please contact support before paying again.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOrderPlacementFailureDialog(
    RazorpayOrderResult result, {
    String reason =
        'Your payment was successful, but we could not save your '
        'order due to a connection problem. Please contact support '
        'with the details below — do not pay again.',
  }) async {
    final supportPhone = context.read<BusinessSettingsProvider>().supportPhone;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Payment received, order not placed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reason),
              const SizedBox(height: 12),
              SelectableText('Payment ID: ${result.razorpayPaymentId}'),
              if (supportPhone.isNotEmpty)
                SelectableText('Support: $supportPhone'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(
                ClipboardData(text: result.razorpayPaymentId ?? ''),
              ),
              child: const Text('Copy Payment ID'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  /// Called if a genuine Razorpay result arrives after [_razorpayWebService]
  /// had already given up and returned (see its `_initializationTimeout`) -
  /// meaning the checkout was actually still open and the customer finished
  /// it for real, after this screen had already reacted to what looked like
  /// an initialization failure (e.g. auto-navigating to the QR flow on
  /// web). Deliberately does *not* attempt to place an order from the
  /// current cart/customer state: by the time this fires, the customer may
  /// already have completed the QR fallback and cleared the cart, so
  /// reusing it here could create a bogus or duplicate order. Surfacing the
  /// same dialog used when a verified payment's placeOrder() call itself
  /// fails lets the payment be reconciled manually via its ID instead.
  void _handleLateRazorpayResult(RazorpayOrderResult result) {
    if (!mounted || !result.success) return;
    _showOrderPlacementFailureDialog(
      result,
      reason:
          'A payment confirmation arrived after this screen had already '
          'moved on (it took longer than expected). Please contact support '
          'with the details below to make sure your order is placed — if '
          'you already paid again another way, let them know so you are '
          'not charged twice.',
    );
  }

  Future<void> _payWithRazorpay() async {
    final business = context.read<BusinessSettingsProvider>();
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();
    final orders = context.read<OrdersProvider>();
    // Includes delivery fee - this is the actual amount charged via
    // Razorpay, so it must match what CartScreen/OrderSummaryScreen show
    // the customer before they tap Pay (both use the same
    // calculateDeliveryFee helper against cart.total).
    final total =
        cart.total + calculateDeliveryFee(cart.total, business.settingsSnapshot);

    setState(() => _isProcessing = true);
    // Only ever called from the Pay Now button, which only renders when
    // _razorpaySupported or _razorpayWebServiceSupported (see build()) -
    // _razorpayService is guaranteed non-null by initState() in the former
    // case.
    final result = _razorpaySupported
        ? await _razorpayService!.pay(
            amount: total,
            businessName: business.businessName,
            description: 'Order payment to ${business.businessName}',
            customerName: auth.customerName,
            customerPhone: auth.customerPhone,
          )
        : await _razorpayWebService.pay(
            context: context,
            amount: total,
            businessName: business.businessName,
            description: 'Order payment to ${business.businessName}',
            customerName: auth.customerName,
            customerPhone: auth.customerPhone,
            onLateResult: _handleLateRazorpayResult,
          );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result.cancelled) {
      _showMessage('Payment was cancelled.');
      return;
    }

    // On web only: if Razorpay never managed to initialize (misconfigured
    // key, checkout.js couldn't load), don't strand the customer on a dead
    // "Pay Now" button - fall back to the QR flow automatically, same as
    // Linux/macOS get by default. Mobile/Windows just show the error and
    // let the customer retry Pay Now, since there's no other payment UI to
    // send them to there.
    if (result.initializationFailed && _razorpayWebSupported) {
      _showMessage(
        'Online payment is unavailable right now — showing the QR payment option instead.',
      );
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const UpiPaymentScreen()));
      return;
    }

    if (!result.success) {
      _showMessage(result.errorMessage ?? 'Could not complete payment.');
      return;
    }

    // Razorpay's own confirmed amount (from verify-razorpay-payment
    // re-fetching the order) must match the cart total before we trust this
    // payment enough to save an order against it. A null verifiedAmountPaise
    // means that defense-in-depth re-fetch itself failed - the signature
    // already proved the payment is genuine, so that alone doesn't block.
    if (result.verifiedAmountPaise != null &&
        (result.verifiedAmountPaise! / 100 - total).abs() > 0.01) {
      await _showAmountMismatchDialog();
      return;
    }

    try {
      final placedOrders = await orders.placeOrder(
        cartItems: cart.items,
        customerName: auth.customerName,
        customerPhone: auth.customerPhone,
        deliveryAddress: auth.customerAddress,
        paymentMethod: 'razorpay',
        transactionId: result.razorpayPaymentId,
        razorpayOrderId: result.razorpayOrderId,
        preVerified: true,
      );
      cart.clear();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OrderPlacedScreen(orders: placedOrders),
          ),
        );
      }
    } catch (_) {
      if (mounted) await _showOrderPlacementFailureDialog(result);
    }
  }

  static const _paymentMethods = [
    (
      icon: Icons.qr_code_2_outlined,
      label: 'UPI',
      subtitle: 'Google Pay, PhonePe, Paytm & more',
    ),
    (
      icon: Icons.credit_card_outlined,
      label: 'Credit / Debit Card',
      subtitle: 'Visa, Mastercard, RuPay & more',
    ),
    (
      icon: Icons.account_balance_outlined,
      label: 'Net Banking',
      subtitle: 'All major banks',
    ),
    (
      icon: Icons.account_balance_wallet_outlined,
      label: 'Wallets',
      subtitle: 'Amazon Pay, Freecharge & more',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final razorpayAvailable = _razorpaySupported || _razorpayWebServiceSupported;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Method')),
      body: ResponsiveCenter(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'We do not offer Cash on Delivery. All orders are prepaid.',
                        ),
                      ),
                    ],
                  ),
                ),
                if (razorpayAvailable) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Select a payment method',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final method in _paymentMethods) ...[
                    _PaymentMethodTile(
                      icon: method.icon,
                      label: method.label,
                      subtitle: method.subtitle,
                      onTap: _isProcessing ? null : _payWithRazorpay,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
            if (_isProcessing)
              Positioned.fill(
                child: ColoredBox(
                  color: colorScheme.surface.withValues(alpha: 0.7),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Opening payment...'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: razorpayAvailable
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UpiPaymentScreen(),
                        ),
                      ),
                      child: const Text('Scan QR Code'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Direct payment isn\'t available on this device. '
                      'Please scan the QR code to pay.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _PaymentMethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.primary,
                child: Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
