import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../state/auth_provider.dart';
import '../state/orders_provider.dart';
import '../utils/formatters.dart';
import '../widgets/responsive_center.dart';
import 'invoice_screen.dart';

/// Shared by both the head admin (web) and shop owner (mobile) order
/// screens — payment verification and fulfillment are identical,
/// money-sensitive logic regardless of who's looking at it, so there's one
/// implementation rather than two copies that could drift apart.
class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isUpdating = false;

  String get _verifiedBy {
    final auth = context.read<AuthProvider>();
    return auth.role == AppRole.headAdmin
        ? 'Head Admin'
        : auth.shopOwnerUsername;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isUpdating = true);
    try {
      await action();
    } catch (error) {
      debugPrint('Could not update order: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update this order. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _rejectPayment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Payment'),
        content: const Text('This will cancel the order. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => context.read<OrdersProvider>().rejectPayment(
        widget.order.id,
        verifiedBy: _verifiedBy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watching OrdersProvider keeps this screen reactive: verifyPayment /
    // rejectPayment / updateStatus all mutate this same Order instance in
    // place, so widget.order already reflects the latest state.
    context.watch<OrdersProvider>();
    final order = widget.order;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order.shortId}'),
        actions: [
          IconButton(
            tooltip: 'View Invoice',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => InvoiceScreen(order: order)),
            ),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: 'Customer Details',
              children: [
                _Row('Name', order.customerName),
                _Row('Phone', order.customerPhone),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Delivery Address',
              children: [
                Text(
                  order.deliveryAddress.isNotEmpty
                      ? order.deliveryAddress
                      : 'Not provided',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Order Items',
              children: [
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${item.productName} x${item.quantity}'),
                        ),
                        Text(formatPrice(item.subtotal)),
                      ],
                    ),
                  ),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      formatPrice(order.total),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Payment Details',
              children: [
                _Row('Method', order.paymentMethod.toUpperCase()),
                _Row('Status', order.paymentStatus.label),
                if (order.transactionId != null &&
                    order.transactionId!.isNotEmpty)
                  _Row('Transaction ID', order.transactionId!),
                if (order.verifiedBy != null)
                  _Row('Verified By', order.verifiedBy!),
                const SizedBox(height: 8),
                Text(
                  'Payment Screenshot',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (order.paymentScreenshotUrl == null ||
                    order.paymentScreenshotUrl!.isEmpty)
                  const Text('No screenshot uploaded.')
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      order.paymentScreenshotUrl!,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Text('Could not load screenshot.'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _buildActions(context, order),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, Order order) {
    final orders = context.read<OrdersProvider>();
    final buttons = <Widget>[];

    if (order.status == OrderStatus.paymentVerification &&
        !order.paymentVerified) {
      buttons.add(
        FilledButton(
          onPressed: _isUpdating
              ? null
              : () => _run(
                  () => orders.verifyPayment(order.id, verifiedBy: _verifiedBy),
                ),
          child: const Text('Verify Payment'),
        ),
      );
      buttons.add(
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _isUpdating ? null : _rejectPayment,
          child: const Text('Reject Payment'),
        ),
      );
    } else if (order.status == OrderStatus.paymentVerification &&
        order.paymentVerified) {
      buttons.add(
        FilledButton(
          onPressed: _isUpdating
              ? null
              : () => _run(
                  () => orders.updateStatus(order.id, OrderStatus.accepted),
                ),
          child: const Text('Accept Order'),
        ),
      );
    } else if (order.status == OrderStatus.accepted) {
      buttons.add(
        FilledButton(
          onPressed: _isUpdating
              ? null
              : () => _run(
                  () => orders.updateStatus(order.id, OrderStatus.preparing),
                ),
          child: const Text('Start Preparing'),
        ),
      );
    } else if (order.status == OrderStatus.preparing) {
      buttons.add(
        FilledButton(
          onPressed: _isUpdating
              ? null
              : () => _run(
                  () =>
                      orders.updateStatus(order.id, OrderStatus.outForDelivery),
                ),
          child: const Text('Mark Out for Delivery'),
        ),
      );
    } else if (order.status == OrderStatus.outForDelivery) {
      buttons.add(
        FilledButton(
          onPressed: _isUpdating
              ? null
              : () => _run(
                  () => orders.updateStatus(order.id, OrderStatus.delivered),
                ),
          child: const Text('Mark Delivered'),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final button in buttons)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: button),
        if (_isUpdating)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
