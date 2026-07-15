import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../state/navigation_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';

class OrderPlacedScreen extends StatelessWidget {
  final List<Order> orders;

  const OrderPlacedScreen({super.key, required this.orders});

  void _returnToRoot(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final total = orders.fold(0.0, (sum, o) => sum + o.total);
    final placedAt = orders.first.placedAt;
    final orderIds = orders.map((o) => '#${o.shortId}').join(', ');
    final paymentVerified = orders.first.paymentVerified;
    final statusColor = paymentVerified
        ? AppColors.statusActive
        : AppColors.statusPending;
    final statusLabel = paymentVerified
        ? 'Verified'
        : 'Payment Verification';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Order Placed!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  paymentVerified
                      ? 'Your order has been placed successfully. Payment is verified.'
                      : 'Your order has been placed successfully. Payment is being verified.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _SummaryRow(label: 'Order ID', value: orderIds),
                        _SummaryRow(
                          label: 'Order Date',
                          value:
                              '${placedAt.day}/${placedAt.month}/${placedAt.year}',
                        ),
                        _SummaryRow(
                          label: 'Total Amount',
                          value: formatPrice(total),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Payment Status'),
                            Chip(
                              label: Text(statusLabel),
                              backgroundColor: statusColor.withValues(
                                alpha: 0.15,
                              ),
                              labelStyle: TextStyle(color: statusColor),
                              side: BorderSide.none,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    context.read<NavigationProvider>().goToOrders();
                    _returnToRoot(context);
                  },
                  child: const Text('View My Orders'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    context.read<NavigationProvider>().goToHome();
                    _returnToRoot(context);
                  },
                  child: const Text('Continue Shopping'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
