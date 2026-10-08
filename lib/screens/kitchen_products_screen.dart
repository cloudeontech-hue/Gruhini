import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop_owner.dart';
import '../state/products_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/product_card.dart';
import '../widgets/responsive_center.dart';

/// One home kitchen's product catalog - the same grid layout as Home, just
/// filtered to a single shop owner. Reached from [KitchensScreen].
class KitchenProductsScreen extends StatelessWidget {
  final ShopOwner kitchen;

  const KitchenProductsScreen({super.key, required this.kitchen});

  @override
  Widget build(BuildContext context) {
    final products = context
        .watch<ProductsProvider>()
        .products
        .where((p) => p.shopOwnerId == kitchen.id)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(kitchen.shopName)),
      body: ResponsiveCenter(
        child: products.isEmpty
            ? const EmptyState(
                icon: Icons.restaurant_menu_outlined,
                title: 'No products yet',
                subtitle: 'This kitchen hasn\'t listed any products yet.',
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  // Same responsive breakpoints as HomeScreen's grid, for a
                  // consistent card size/count across both screens.
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 1100
                      ? 5
                      : width >= 860
                      ? 4
                      : width >= 600
                      ? 3
                      : 2;
                  return GridView.count(
                    padding: const EdgeInsets.all(12),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.74,
                    children: products
                        .map((p) => ProductCard(product: p))
                        .toList(),
                  );
                },
              ),
      ),
    );
  }
}
