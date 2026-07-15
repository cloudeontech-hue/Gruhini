import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/products_provider.dart';
import '../../state/shop_owners_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';
import '../../widgets/responsive_center.dart';

/// Only ever shown to the head admin - shop owners manage their own catalog
/// through the separate ShopOwnerProductsScreen/ShopOwnerProductFormScreen
/// instead. The head admin can view every shop's products, toggle stock, and
/// delete, but does not add/edit products directly.
class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductsProvider>();
    final shopOwnersProvider = context.watch<ShopOwnersProvider>();
    if (!productsProvider.isLoaded || !shopOwnersProvider.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final products = productsProvider.products;

    return Scaffold(
      body: products.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              subtitle: 'Products added by shop owners will appear here.',
            )
          : ResponsiveCenter(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: ProductImage(product: product),
                        ),
                      ),
                      title: Text(product.name),
                      subtitle: Text(
                        '${shopOwnersProvider.shopNameFor(product.shopOwnerId)} · '
                        '${formatPrice(product.price)} · ${product.unit}\n'
                        '${product.inStock ? "In Stock" : "Out of Stock"}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          final provider = context.read<ProductsProvider>();
                          switch (value) {
                            case 'stock':
                              provider.toggleStock(product.id);
                              break;
                            case 'delete':
                              provider.deleteProduct(product.id);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'stock',
                            child: Text(
                              product.inStock
                                  ? 'Mark Out of Stock'
                                  : 'Mark In Stock',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
