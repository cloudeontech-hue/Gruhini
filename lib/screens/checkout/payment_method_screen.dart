import 'package:flutter/material.dart';

import '../../widgets/responsive_center.dart';
import 'upi_payment_screen.dart';

/// Only one payment method exists in this app - UPI QR. This screen still
/// exists (rather than skipping straight to [UpiPaymentScreen]) to make the
/// "no Cash on Delivery" policy explicit to the customer before they
/// proceed to pay.
class PaymentMethodScreen extends StatelessWidget {
  const PaymentMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Method')),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.primary, width: 2),
              ),
              child: RadioListTile<bool>(
                value: true,
                groupValue: true,
                onChanged: (_) {},
                secondary: const Icon(Icons.qr_code),
                title: const Text('Pay via UPI QR'),
                subtitle: const Text('Scan and pay using any UPI app'),
              ),
            ),
            const SizedBox(height: 16),
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
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UpiPaymentScreen()),
            ),
            child: const Text('Continue to Pay'),
          ),
        ),
      ),
    );
  }
}
