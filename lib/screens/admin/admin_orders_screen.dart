import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../state/auth_provider.dart';
import '../../state/orders_provider.dart';
import '../../state/shop_owners_provider.dart';
import '../../utils/formatters.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<OrdersProvider>();
    final shopOwnersProvider = context.watch<ShopOwnersProvider>();
    final auth = context.watch<AuthProvider>();
    if (!ordersProvider.isLoaded || !shopOwnersProvider.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final isHeadAdmin = auth.role == AppRole.headAdmin;
    final orders = isHeadAdmin
        ? ordersProvider.orders
        : ordersProvider.orders.where((o) => o.shopOwnerId == auth.shopOwnerId).toList();

    return orders.isEmpty
        ? const Center(child: Text('No orders yet.'))
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${order.customerName} · #${order.shortId}',
                              style: Theme.of(context).textTheme.titleMedium,
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
                      Text(order.customerPhone, style: Theme.of(context).textTheme.bodySmall),
                      if (isHeadAdmin)
                        Text(
                          shopOwnersProvider.shopNameFor(order.shopOwnerId),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      const SizedBox(height: 8),
                      ...order.items.map((item) => Text('${item.productName} x${item.quantity}')),
                      const SizedBox(height: 12),
                      DropdownButton<OrderStatus>(
                        value: order.status,
                        isExpanded: true,
                        items: OrderStatus.values
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                            .toList(),
                        onChanged: (status) {
                          if (status != null) {
                            ordersProvider.updateStatus(order.id, status);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
