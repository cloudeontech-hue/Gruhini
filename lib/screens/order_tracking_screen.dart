import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../state/business_settings_provider.dart';
import '../state/orders_provider.dart';
import '../widgets/rate_order_dialog.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/reorder.dart';
import '../widgets/responsive_center.dart';
import 'invoice_screen.dart';

const _trackingSteps = [
  (
    status: OrderStatus.paymentVerification,
    label: 'Payment Verification',
    description: 'We are verifying your payment.',
  ),
  (
    status: OrderStatus.accepted,
    label: 'Accepted',
    description: 'Your order has been accepted.',
  ),
  (
    status: OrderStatus.preparing,
    label: 'Preparing',
    description: 'Your order is being prepared.',
  ),
  (
    status: OrderStatus.outForDelivery,
    label: 'Out for Delivery',
    description: 'Your order is on its way.',
  ),
  (
    status: OrderStatus.delivered,
    label: 'Delivered',
    description: 'Your order has been delivered.',
  ),
];

class OrderTrackingScreen extends StatefulWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _isCancelling = false;

  Order get order => widget.order;

  /// Confirms, then cancels. The dialog spells out that the refund is
  /// processed separately and isn't instant - cancelling a prepaid order
  /// without saying that would read as "money gone".
  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
          'Your order will be cancelled and refunded in full.\n\n'
          'Refunds are credited back to your original payment method '
          'within 5-7 business days.\n\n'
          'Once a shop owner starts preparing your order it can no longer '
          'be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cancelled = await context.read<OrdersProvider>().cancelByCustomer(
        order.id,
      );
      if (!mounted) return;
      setState(() => _isCancelling = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            cancelled
                ? 'Order cancelled. Your refund will be processed shortly.'
                : 'This order can no longer be cancelled - it has already been accepted.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not cancel the order. Please check your connection and try again.',
          ),
        ),
      );
    }
  }

  void _contactSupport(BuildContext context) {
    final phone = context.read<BusinessSettingsProvider>().supportPhone;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Need Help?'),
        content: Text(
          phone.isNotEmpty
              ? 'Contact our support team at $phone for help with this order.'
              : 'Support contact details are not configured yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watched (not read) so the screen repaints when cancelByCustomer
    // mutates this order in place and notifies.
    final ordersProvider = context.watch<OrdersProvider>();
    final canCancel = ordersProvider.canCustomerCancel(order);
    final currentIndex = _trackingSteps.indexWhere(
      (s) => s.status == order.status,
    );

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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${order.shortId}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${order.placedAt.day}/${order.placedAt.month}/${order.placedAt.year}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatPrice(order.total),
                      style: Theme.of(context).textTheme.bodyMedium,
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
                  children: [
                    Text(
                      'Order Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final item in order.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.productName} x${item.quantity}',
                              ),
                            ),
                            Text(formatPrice(item.subtotal)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (order.status == OrderStatus.cancelled)
              Card(
                color: AppColors.statusCancelled.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: AppColors.statusCancelled,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('This order was cancelled.')),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Tracking',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < _trackingSteps.length; i++)
                        _TrackingStep(
                          label: _trackingSteps[i].label,
                          description: _trackingSteps[i].description,
                          done: i < currentIndex,
                          active: i == currentIndex,
                          isLast: i == _trackingSteps.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            if (order.status == OrderStatus.delivered) ...[
              OutlinedButton.icon(
                onPressed: () => showRateOrderDialog(context, order),
                icon: const Icon(Icons.star_border),
                label: const Text('Rate Your Order'),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: () => reorderInto(context, order),
              icon: const Icon(Icons.replay),
              label: const Text('Reorder'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _contactSupport(context),
              child: const Text('Need Help? Contact Support'),
            ),
            // Only offered while the order is still in Payment
            // Verification - past that the shop owner has begun preparing
            // food that can't be un-cooked, per the refunds policy.
            if (canCancel) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isCancelling ? null : _confirmCancel,
                icon: _isCancelling
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : Icon(
                        Icons.cancel_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                label: Text(
                  _isCancelling ? 'Cancelling...' : 'Cancel Order',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackingStep extends StatelessWidget {
  final String label;
  final String description;
  final bool done;
  final bool active;
  final bool isLast;

  const _TrackingStep({
    required this.label,
    required this.description,
    required this.done,
    required this.active,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReached = done || active;
    final color = done
        ? AppColors.gold
        : active
        ? colorScheme.primary
        : colorScheme.outlineVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.circle,
              size: 20,
              color: color,
            ),
            if (!isLast) Container(width: 2, height: 36, color: color),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: isReached ? FontWeight.w600 : FontWeight.normal,
                    color: isReached
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (active)
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
