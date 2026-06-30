import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/cart_provider.dart';
import '../state/products_provider.dart';
import '../utils/formatters.dart';
import '../widgets/product_image.dart';
import 'checkout/delivery_address_screen.dart';

class ProductDetailsScreen extends StatelessWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final quantity = cart.quantityOf(product.id);
    context.watch<ProductsProvider>();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      bottomNavigationBar: quantity > 0
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} in cart',
                          style: textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        Text(
                          formatPrice(cart.total),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DeliveryAddressScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: const Text('Proceed to Checkout'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            title: Text(product.name),
            flexibleSpace: FlexibleSpaceBar(
              background: ProductImage(product: product),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    product.name,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Price / unit
                  Text(
                    '${formatPrice(product.price)} / ${product.unit}',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Description
                  if (product.description.isNotEmpty)
                    Text(
                      product.description,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(product.category.label)),
                      Chip(label: Text(product.unit)),
                      Chip(
                        label: Text(
                          product.inStock ? 'In Stock' : 'Out of Stock',
                        ),
                        backgroundColor: product.inStock
                            ? colorScheme.primaryContainer
                            : colorScheme.errorContainer,
                        labelStyle: TextStyle(
                          color: product.inStock
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Cart controls
                  if (!product.inStock)
                    Text(
                      'This item is currently out of stock.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    )
                  else if (quantity == 0)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => cart.add(product),
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: const Text('Add to Cart'),
                      ),
                    )
                  else
                    Row(
                      children: [
                        IconButton.filled(
                          icon: const Icon(Icons.remove),
                          onPressed: () => cart.decrement(product.id),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text('$quantity', style: textTheme.titleLarge),
                        ),
                        IconButton.filled(
                          icon: const Icon(Icons.add),
                          onPressed: () => cart.add(product),
                        ),
                        const Spacer(),
                        Text(
                          formatPrice(product.price * quantity),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
