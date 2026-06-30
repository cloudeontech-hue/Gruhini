import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../state/business_settings_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/responsive_center.dart';

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

class OrderTrackingScreen extends StatelessWidget {
  final Order order;

  const OrderTrackingScreen({super.key, required this.order});

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
    final currentIndex = _trackingSteps.indexWhere(
      (s) => s.status == order.status,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Order #${order.shortId}')),
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
            OutlinedButton(
              onPressed: () => _contactSupport(context),
              child: const Text('Need Help? Contact Support'),
            ),
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
