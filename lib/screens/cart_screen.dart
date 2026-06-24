import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../state/cart_provider.dart';
import '../state/orders_provider.dart';
import '../state/products_provider.dart';
import '../utils/formatters.dart';
import '../widgets/product_image.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  /// Delivery address is required to place an order. If the customer
  /// already has one on file (set previously via Profile or a past
  /// checkout), this is a no-op; otherwise it blocks checkout until one is
  /// entered.
  Future<bool> _ensureAddress(BuildContext context, AuthProvider auth) async {
    if (auth.customerAddress.trim().isNotEmpty) return true;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final address = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delivery Address Required'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Address'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (address == null) return false;
    await auth.updateCustomerAddress(address);
    return true;
  }

  Future<void> _checkout(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();
    final orders = context.read<OrdersProvider>();

    if (!await _ensureAddress(context, auth)) return;
    if (!context.mounted) return;

    try {
      final placedOrders = await orders.placeOrder(
        cartItems: cart.items,
        customerName: auth.customerName,
        customerPhone: auth.customerPhone,
      );
      cart.clear();

      if (context.mounted) {
        final message = placedOrders.length > 1
            ? '${placedOrders.length} orders placed successfully!'
            : 'Order placed successfully!';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not place order: $error')),
        );
      }
    }
  }

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
          ? const Center(child: Text('Your cart is empty.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
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
                          subtitle:
                              Text('${formatPrice(item.product.price)} · ${item.product.unit}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => cart.decrement(item.product.id),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => cart.add(item.product),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total', style: Theme.of(context).textTheme.bodyMedium),
                              Text(
                                formatPrice(cart.total),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: () => _checkout(context),
                          child: const Text('Place Order'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
