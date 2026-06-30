import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'checkout/delivery_address_screen.dart';
import '../state/cart_provider.dart';
import '../state/products_provider.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/product_image.dart';
import '../widgets/responsive_center.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items;
    // Subscribe so cart line items refresh immediately if an admin updates
    // a product (e.g. its photo) while it's already sitting in the cart.
    context.watch<ProductsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              subtitle:
                  'Add some homemade snacks, sweets or pickles to get started.',
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.goldLight,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 16,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Free delivery on orders above ₹500',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ResponsiveCenter(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: ProductImage(product: item.product),
                              ),
                            ),
                            title: Text(item.product.name),
                            subtitle: Text(
                              '${formatPrice(item.product.price)} · ${item.product.unit}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () =>
                                      cart.decrement(item.product.id),
                                ),
                                Text('${item.quantity}'),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => cart.add(item.product),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remove',
                                  onPressed: () => cart.remove(item.product.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ResponsiveCenter(
                      maxWidth: 720,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(child: Text('Subtotal')),
                              Text(formatPrice(cart.total)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Expanded(child: Text('Delivery Fee')),
                              Text(
                                'Free',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Total',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              Text(
                                formatPrice(cart.total),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DeliveryAddressScreen(),
                              ),
                            ),
                            child: const Text('Proceed to Checkout'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
