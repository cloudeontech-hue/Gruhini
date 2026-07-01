import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';
import '../../state/cart_provider.dart';
import '../../state/orders_provider.dart';
import '../../utils/image_picker_helper.dart';
import '../../widgets/responsive_center.dart';
import 'order_placed_screen.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  const PaymentConfirmationScreen({super.key});

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  final _transactionIdController = TextEditingController();
  final _notesController = TextEditingController();
  Uint8List? _screenshotBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _transactionIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final bytes = await pickProductImageBytes();
      if (bytes != null) setState(() => _screenshotBytes = bytes);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load image: $error')));
      }
    }
  }

  Future<void> _submit() async {
    // Defensive re-entrancy guard: placeOrder() inserts new rows, so a
    // double-tap before the button's disabled state repaints must not be
    // able to slip through and create duplicate orders off one payment.
    if (_isSubmitting) return;

    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();
    final orders = context.read<OrdersProvider>();

    setState(() => _isSubmitting = true);
    try {
      final placedOrders = await orders.placeOrder(
        cartItems: cart.items,
        customerName: auth.customerName,
        customerPhone: auth.customerPhone,
        deliveryAddress: auth.customerAddress,
        paymentScreenshotBytes: _screenshotBytes,
        transactionId: _transactionIdController.text.trim().isEmpty
            ? null
            : _transactionIdController.text.trim(),
      );
      cart.clear();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OrderPlacedScreen(orders: placedOrders),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not place order: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Payment')),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please confirm your payment by sharing details below. '
                        'Your order will be placed after payment verification by the shop.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Upload Payment Screenshot (Recommended)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickScreenshot,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _screenshotBytes == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.upload_outlined,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap to upload\nChoose image from gallery',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _screenshotBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _transactionIdController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Transaction ID (Optional)',
              ),
            ),
            const SizedBox(height: 12),
            // Not wired to placeOrder/Supabase - there's no orders.notes
            // column in the schema (see scripts/supabase_schema_payments.sql),
            // only payment_screenshot_url/transaction_id are persisted.
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (Optional)'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Order'),
          ),
        ),
      ),
    );
  }
}
