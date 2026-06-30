import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../state/auth_provider.dart';
import '../../state/customers_provider.dart';
import '../../state/orders_provider.dart';
import '../../state/products_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/responsive_center.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isHeadAdmin = auth.role == AppRole.headAdmin;

    final allProducts = context.watch<ProductsProvider>().products;
    final allOrders = context.watch<OrdersProvider>().orders;
    final customersCount = context.watch<CustomersProvider>().customers.length;

    final products = isHeadAdmin
        ? allProducts
        : allProducts.where((p) => p.shopOwnerId == auth.shopOwnerId).toList();
    final orders = isHeadAdmin
        ? allOrders
        : allOrders.where((o) => o.shopOwnerId == auth.shopOwnerId).toList();
    final revenue = orders.fold(0.0, (sum, o) => sum + o.total);

    return ResponsiveCenter(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              _StatCard(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
                value: '${products.length}',
              ),
              _StatCard(
                icon: Icons.receipt_long_outlined,
                label: 'Orders',
                value: '${orders.length}',
              ),
              if (isHeadAdmin)
                _StatCard(
                  icon: Icons.people_outline,
                  label: 'Customers',
                  value: '$customersCount',
                ),
              _StatCard(
                icon: Icons.currency_rupee,
                label: 'Revenue',
                value: formatPrice(revenue),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent Orders', style: Theme.of(context).textTheme.titleMedium),
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
                    title: Text('${order.customerName} · ${order.shortId}'),
                    subtitle: Text(order.status.label),
                    trailing: Text(formatPrice(order.total)),
                  ),
                ),
              ),
        ],
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
