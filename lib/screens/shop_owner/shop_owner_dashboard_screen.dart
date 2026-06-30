import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../state/auth_provider.dart';
import '../../state/orders_provider.dart';
import '../../state/products_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/responsive_center.dart';

class ShopOwnerDashboardScreen extends StatelessWidget {
  final VoidCallback? onViewAllOrders;

  const ShopOwnerDashboardScreen({super.key, this.onViewAllOrders});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final products = context
        .watch<ProductsProvider>()
        .products
        .where((p) => p.shopOwnerId == auth.shopOwnerId)
        .toList();
    final orders = context
        .watch<OrdersProvider>()
        .orders
        .where((o) => o.shopOwnerId == auth.shopOwnerId)
        .toList();
    final revenue = orders.fold(0.0, (sum, o) => sum + o.total);

    return Scaffold(
      appBar: AppBar(title: Text('Welcome back, ${auth.shopName}')),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _StatCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Total Products',
                  value: '${products.length}',
                ),
                _StatCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'Total Orders',
                  value: '${orders.length}',
                ),
                _StatCard(
                  icon: Icons.currency_rupee,
                  label: 'Total Revenue',
                  value: formatPrice(revenue),
                ),
                _StatCard(
                  icon: Icons.trending_up,
                  label: 'This Month',
                  value:
                      '${orders.where((o) => o.placedAt.month == DateTime.now().month).length} orders',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Orders',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (onViewAllOrders != null)
                  TextButton(
                    onPressed: onViewAllOrders,
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (orders.isEmpty)
              Text(
                'No orders yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ...orders
                .take(5)
                .map(
                  (order) => Card(
                    child: ListTile(
                      title: Text('${order.customerName} · #${order.shortId}'),
                      subtitle: Text(
                        '${order.placedAt.day}/${order.placedAt.month}/${order.placedAt.year}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatPrice(order.total)),
                          Chip(
                            label: Text(order.status.label),
                            backgroundColor: AppColors.statusColor(
                              order.status,
                            ).withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: AppColors.statusColor(order.status),
                            ),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.goldLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.brand, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
