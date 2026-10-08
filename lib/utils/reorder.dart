import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../state/cart_provider.dart';
import '../state/navigation_provider.dart';
import '../state/products_provider.dart';

/// Adds [order]'s items back into the cart (see
/// [CartProvider.addFromOrder]), shows a summary of what was added/skipped,
/// and — if anything was added — switches the customer root to the Cart tab
/// so they can see the result immediately. Safe to call from anywhere with
/// access to a [BuildContext] under the customer root (order list, order
/// tracking detail, etc.).
Future<void> reorderInto(BuildContext context, Order order) async {
  final cart = context.read<CartProvider>();
  final products = context.read<ProductsProvider>().products;
  final result = cart.addFromOrder(order.items, products);

  if (!context.mounted) return;

  if (result.addedCount == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('None of these items are available right now.'),
      ),
    );
    return;
  }

  final addedText =
      '${result.addedCount} item${result.addedCount == 1 ? '' : 's'} added to cart.';
  final message = result.unavailable.isEmpty
      ? addedText
      : '$addedText Not available right now: ${result.unavailable.join(', ')}.';
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  context.read<NavigationProvider>().goToCart();
  Navigator.of(context).popUntil((route) => route.isFirst);
}
