import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../state/orders_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive_center.dart';
import 'order_tracking_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();
    final orders = ordersProvider.orders
        .where((o) => _filter == null || o.status == _filter)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: !ordersProvider.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: OrderStatus.values.length + 1,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final status = index == 0
                          ? null
                          : OrderStatus.values[index - 1];
                      return ChoiceChip(
                        label: Text(status?.label ?? 'All'),
                        selected: _filter == status,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _filter = status),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: orders.isEmpty
                      ? const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No orders yet',
                          subtitle: 'Your placed orders will show up here.',
                        )
                      : ResponsiveCenter(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: orders.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _OrderCard(order: orders[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  Color _statusColor(OrderStatus status) => AppColors.statusColor(status);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.goldLight,
                    foregroundColor: AppColors.brand,
                    child: Icon(Icons.shopping_bag_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Order #${order.shortId}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(order.status.label),
                    backgroundColor: _statusColor(
                      order.status,
                    ).withValues(alpha: 0.15),
                    labelStyle: TextStyle(color: _statusColor(order.status)),
                    side: BorderSide.none,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${item.productName} x${item.quantity}'),
                ),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.placedAt.day}/${order.placedAt.month}/${order.placedAt.year}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Row(
                    children: [
                      Text(
                        formatPrice(order.total),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'View Details',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
