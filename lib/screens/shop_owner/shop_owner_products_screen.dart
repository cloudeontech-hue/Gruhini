import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../state/auth_provider.dart';
import '../../state/products_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';
import '../../widgets/responsive_center.dart';
import 'shop_owner_product_form_screen.dart';

enum _ProductsFilter { all, active, inactive }

class ShopOwnerProductsScreen extends StatefulWidget {
  const ShopOwnerProductsScreen({super.key});

  @override
  State<ShopOwnerProductsScreen> createState() =>
      _ShopOwnerProductsScreenState();
}

class _ShopOwnerProductsScreenState extends State<ShopOwnerProductsScreen> {
  _ProductsFilter _filter = _ProductsFilter.all;

  void _openProductForm(BuildContext context, {Product? product}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopOwnerProductFormScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final productsProvider = context.watch<ProductsProvider>();
    if (!productsProvider.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final products = productsProvider.products
        .where((p) => p.shopOwnerId == auth.shopOwnerId)
        .where((p) {
          switch (_filter) {
            case _ProductsFilter.all:
              return true;
            case _ProductsFilter.active:
              return p.inStock;
            case _ProductsFilter.inactive:
              return !p.inStock;
          }
        })
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_ProductsFilter>(
              segments: const [
                ButtonSegment(value: _ProductsFilter.all, label: Text('All')),
                ButtonSegment(
                  value: _ProductsFilter.active,
                  label: Text('Active'),
                ),
                ButtonSegment(
                  value: _ProductsFilter.inactive,
                  label: Text('Inactive'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) =>
                  setState(() => _filter = selection.first),
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products yet',
                    subtitle: 'Tap "Add Product" to list your first item.',
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
                            onTap: () =>
                                _openProductForm(context, product: product),
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
                              '${formatPrice(product.price)} · ${product.unit}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(
                                    product.inStock
                                        ? 'In Stock'
                                        : 'Out of Stock',
                                  ),
                                  backgroundColor: product.inStock
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.errorContainer,
                                  visualDensity: VisualDensity.compact,
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'stock':
                                        productsProvider.toggleStock(
                                          product.id,
                                        );
                                        break;
                                      case 'delete':
                                        productsProvider.deleteProduct(
                                          product.id,
                                        );
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
                              ],
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
