import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../services/supabase_client.dart';

class OrdersProvider extends ChangeNotifier {
  final List<Order> _orders = [];
  bool _isLoaded = false;

  /// Monotonic counter mixed into generated order ids. A single checkout can
  /// place several orders back-to-back (one per shop owner — see
  /// [placeOrder]), often within the same millisecond, so the timestamp
  /// alone isn't enough to keep them unique.
  int _orderSeq = 0;

  List<Order> get orders => List.unmodifiable(_orders.reversed);
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    final rows = await supabase.from('orders').select().order('placed_at');
    _orders
      ..clear()
      ..addAll(rows.map(Order.fromMap));
    _isLoaded = true;
    notifyListeners();
  }

  /// Splits the cart into one order per shop owner — a single cart can span
  /// multiple shops, but each shop only sees/manages orders for its own
  /// products, so they can't share one [Order] row.
  Future<List<Order>> placeOrder({
    required List<CartItem> cartItems,
    required String customerName,
    required String customerPhone,
  }) async {
    final itemsByShop = <String, List<CartItem>>{};
    for (final item in cartItems) {
      itemsByShop.putIfAbsent(item.product.shopOwnerId, () => []).add(item);
    }

    final newOrders = <Order>[];
    for (final entry in itemsByShop.entries) {
      final order = Order(
        id: 'o${DateTime.now().microsecondsSinceEpoch}_${_orderSeq++}_${Random().nextInt(1000)}',
        customerName: customerName,
        customerPhone: customerPhone,
        items: entry.value
            .map((c) => OrderLineItem(
                  productName: c.product.name,
                  price: c.product.price,
                  quantity: c.quantity,
                ))
            .toList(),
        total: entry.value.fold(0, (sum, c) => sum + c.subtotal),
        placedAt: DateTime.now(),
        shopOwnerId: entry.key,
      );
      await supabase.from('orders').insert(order.toMap());
      _orders.add(order);
      newOrders.add(order);
    }
    notifyListeners();
    return newOrders;
  }

  Future<void> updateStatus(String orderId, OrderStatus status) async {
    final order = _orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return;
    order.status = status;
    await supabase.from('orders').update({'status': status.name}).eq('id', orderId);
    notifyListeners();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
