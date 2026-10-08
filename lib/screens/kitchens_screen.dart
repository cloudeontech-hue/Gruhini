import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop_owner.dart';
import '../state/products_provider.dart';
import '../state/shop_owners_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive_center.dart';
import 'kitchen_products_screen.dart';

/// Lists every home kitchen (shop owner) selling on the platform, so a
/// customer can browse one cook's products specifically instead of only
/// ever seeing every shop owner's items mixed into one flat grid on Home.
class KitchensScreen extends StatelessWidget {
  const KitchensScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shopOwners = context.watch<ShopOwnersProvider>().shopOwners;
    final products = context.watch<ProductsProvider>().products;

    // Only kitchens that actually have at least one product are worth
    // showing - a registered-but-empty shop owner account isn't
    // something a customer can order from yet.
    final activeKitchens = shopOwners
        .where((s) => products.any((p) => p.shopOwnerId == s.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kitchens')),
      body: ResponsiveCenter(
        child: activeKitchens.isEmpty
            ? const EmptyState(
                icon: Icons.storefront_outlined,
                title: 'No kitchens yet',
                subtitle: 'Check back soon for home kitchens to order from.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: activeKitchens.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final kitchen = activeKitchens[index];
                  final itemCount = products
                      .where((p) => p.shopOwnerId == kitchen.id)
                      .length;
                  return _KitchenCard(kitchen: kitchen, itemCount: itemCount);
                },
              ),
      ),
    );
  }
}

class _KitchenCard extends StatelessWidget {
  final ShopOwner kitchen;
  final int itemCount;

  const _KitchenCard({required this.kitchen, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => KitchenProductsScreen(kitchen: kitchen),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.goldLight,
                foregroundColor: AppColors.brand,
                child: Text(
                  kitchen.shopName.isNotEmpty
                      ? kitchen.shopName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kitchen.shopName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '$itemCount item${itemCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
