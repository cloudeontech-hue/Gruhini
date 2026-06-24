import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/cart_provider.dart';
import '../state/products_provider.dart';
import '../utils/formatters.dart';
import '../widgets/product_image.dart';

class ProductDetailsScreen extends StatelessWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final quantity = cart.quantityOf(product.id);
    // Subscribe so this screen refreshes immediately if an admin updates
    // this product (e.g. its photo) while it's open.
    context.watch<ProductsProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(product.name),
              background: ProductImage(product: product),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(product.category.label)),
                    Chip(label: Text(product.unit)),
                    Chip(
                      label: Text(product.inStock ? 'In Stock' : 'Out of Stock'),
                      backgroundColor: product.inStock
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.errorContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  formatPrice(product.price),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  product.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (!product.inStock)
                  const Text('This item is currently out of stock.')
                else if (quantity == 0)
                  FilledButton.icon(
                    onPressed: () => cart.add(product),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Add to Cart'),
                  )
                else
                  Row(
                    children: [
                      IconButton.filled(
                        icon: const Icon(Icons.remove),
                        onPressed: () => cart.decrement(product.id),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$quantity',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton.filled(
                        icon: const Icon(Icons.add),
                        onPressed: () => cart.add(product),
                      ),
                      const Spacer(),
                      Text(
                        'In cart',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
