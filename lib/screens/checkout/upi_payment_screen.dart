import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/business_settings_provider.dart';
import '../../state/cart_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/delivery_fee.dart';
import '../../utils/formatters.dart';
import '../../widgets/responsive_center.dart';
import 'payment_confirmation_screen.dart';

class UpiPaymentScreen extends StatelessWidget {
  const UpiPaymentScreen({super.key});

  Future<void> _copyUpiId(BuildContext context, String upiId) async {
    await Clipboard.setData(ClipboardData(text: upiId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI ID copied to clipboard.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessSettingsProvider>();
    final cartTotal = context.watch<CartProvider>().total;
    final total =
        cartTotal + calculateDeliveryFee(cartTotal, business.settingsSnapshot);

    return Scaffold(
      appBar: AppBar(title: const Text('Pay via UPI')),
      body: !business.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveCenter(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Text(
                      business.businessName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Total Amount',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Center(
                    child: Text(
                      formatPrice(total),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.gold, width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: 0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: business.upiQrUrl.isEmpty
                          ? Center(
                              child: Text(
                                'QR code not configured yet.\nUse the UPI ID below.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            )
                          : Image.network(
                              business.upiQrUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.qr_code_2, size: 96),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'UPI ID',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  business.upiId,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_outlined),
                            tooltip: 'Copy UPI ID',
                            onPressed: () =>
                                _copyUpiId(context, business.upiId),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _PaymentStep(
                            number: 1,
                            text:
                                'Open any UPI app (PhonePe, GPay, Paytm, BHIM, etc.)',
                          ),
                          _PaymentStep(
                            number: 2,
                            text: 'Scan the QR code or pay to the UPI ID above',
                          ),
                          _PaymentStep(number: 3, text: 'Complete the payment'),
                          _PaymentStep(
                            number: 4,
                            text: 'Tap "I Have Paid" below',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (business.supportPhone.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Having issues with payment? Contact us: ${business.supportPhone}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PaymentConfirmationScreen(),
              ),
            ),
            child: const Text('I Have Paid'),
          ),
        ),
      ),
    );
  }
}

class _PaymentStep extends StatelessWidget {
  final int number;
  final String text;
  final bool isLast;

  const _PaymentStep({
    required this.number,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.goldLight,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
