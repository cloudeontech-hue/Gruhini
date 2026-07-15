import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../state/auth_provider.dart';
import '../../state/orders_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/responsive_center.dart';
import '../order_details_screen.dart';

class ShopOwnerOrdersScreen extends StatefulWidget {
  const ShopOwnerOrdersScreen({super.key});

  @override
  State<ShopOwnerOrdersScreen> createState() => _ShopOwnerOrdersScreenState();
}

class _ShopOwnerOrdersScreenState extends State<ShopOwnerOrdersScreen> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ordersProvider = context.watch<OrdersProvider>();
    if (!ordersProvider.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final orders = ordersProvider.orders
        .where((o) => o.shopOwnerId == auth.shopOwnerId)
        .where((o) => _filter == null || o.status == _filter)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: OrderStatus.values.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
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
                    subtitle: 'Orders from customers will appear here.',
                  )
                : ResponsiveCenter(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Card(
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderDetailsScreen(order: order),
                              ),
                            ),
                            title: Text(
                              '${order.customerName} · #${order.shortId}',
                            ),
                            subtitle: Text(
                              '${order.placedAt.day}/${order.placedAt.month}/${order.placedAt.year}',
                            ),
                            // FittedBox guards against the price+chip column
                            // overflowing the tile's default trailing height
                            // - it scales down rather than clipping/overflowing.
                            trailing: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatPrice(order.total),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Chip(
                                    label: Text(order.status.label),
                                    backgroundColor: AppColors.statusColor(
                                      order.status,
                                    ).withValues(alpha: 0.15),
                                    labelStyle: TextStyle(
                                      color: AppColors.statusColor(
                                        order.status,
                                      ),
                                    ),
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
