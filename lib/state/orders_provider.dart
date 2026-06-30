import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../services/payment_screenshot_uploader.dart';
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
    try {
      final rows = await supabase.from('orders').select().order('placed_at');
      _orders
        ..clear()
        ..addAll(rows.map(Order.fromMap));
    } catch (error) {
      // Don't leave isLoaded stuck false on a backend hiccup - that would
      // freeze every screen that gates on this provider in a permanent
      // loading spinner.
      debugPrint('Could not load orders: $error');
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// Splits the cart into one order per shop owner — a single cart can span
  /// multiple shops, but each shop only sees/manages orders for its own
  /// products, so they can't share one [Order] row. Every order starts at
  /// [OrderStatus.paymentVerification]/[PaymentStatus.pending] - this app is
  /// prepaid-only via UPI, so there's no "place now, pay on delivery" path.
  /// If [paymentScreenshotBytes] is given, it's uploaded once and the same
  /// URL is stamped onto every split order, since they all came from one
  /// payment covering the whole cart.
  Future<List<Order>> placeOrder({
    required List<CartItem> cartItems,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    Uint8List? paymentScreenshotBytes,
    String? transactionId,
  }) async {
    final batchId =
        'o${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1000)}';
    String? screenshotUrl;
    if (paymentScreenshotBytes != null) {
      try {
        screenshotUrl = await uploadPaymentScreenshot(
          batchId,
          paymentScreenshotBytes,
        );
      } catch (error) {
        // Order proceeds without screenshot if the storage bucket is missing
        // or the upload fails for any reason — the admin can still verify
        // payment via the transaction ID.
        debugPrint('Could not upload payment screenshot: $error');
      }
    }

    final itemsByShop = <String, List<CartItem>>{};
    for (final item in cartItems) {
      itemsByShop.putIfAbsent(item.product.shopOwnerId, () => []).add(item);
    }

    final newOrders = <Order>[];
    for (final entry in itemsByShop.entries) {
      final order = Order(
        id: '${batchId}_${_orderSeq++}',
        customerName: customerName,
        customerPhone: customerPhone,
        deliveryAddress: deliveryAddress,
        items: entry.value
            .map(
              (c) => OrderLineItem(
                productName: c.product.name,
                price: c.product.price,
                quantity: c.quantity,
              ),
            )
            .toList(),
        total: entry.value.fold(0, (sum, c) => sum + c.subtotal),
        placedAt: DateTime.now(),
        shopOwnerId: entry.key,
        paymentScreenshotUrl: screenshotUrl,
        transactionId: transactionId,
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
    await supabase
        .from('orders')
        .update({'status': status.name})
        .eq('id', orderId);
    notifyListeners();
  }

  /// Marks an order's payment as verified without advancing its fulfillment
  /// [OrderStatus] - "Accept Order" (a separate, explicit action) is what
  /// moves it to [OrderStatus.accepted]. Mutates the existing [Order]
  /// instance in place, same pattern as [updateStatus], so screens already
  /// holding a reference to it (e.g. an open order details screen) pick up
  /// the change automatically.
  Future<void> verifyPayment(
    String orderId, {
    required String verifiedBy,
  }) async {
    final order = _orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return;

    final verifiedAt = DateTime.now();
    order.paymentStatus = PaymentStatus.verified;
    order.paymentVerified = true;
    order.verifiedAt = verifiedAt;
    order.verifiedBy = verifiedBy;

    await supabase
        .from('orders')
        .update({
          'payment_status': PaymentStatus.verified.name,
          'payment_verified': true,
          'verified_at': verifiedAt.toIso8601String(),
          'verified_by': verifiedBy,
        })
        .eq('id', orderId);
    notifyListeners();
  }

  /// Rejects an order's payment and cancels the order in one step - there's
  /// no separate "accept" step on the rejection path.
  Future<void> rejectPayment(
    String orderId, {
    required String verifiedBy,
  }) async {
    final order = _orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return;

    final verifiedAt = DateTime.now();
    order.paymentStatus = PaymentStatus.rejected;
    order.paymentVerified = false;
    order.verifiedAt = verifiedAt;
    order.verifiedBy = verifiedBy;
    order.status = OrderStatus.cancelled;

    await supabase
        .from('orders')
        .update({
          'payment_status': PaymentStatus.rejected.name,
          'payment_verified': false,
          'verified_at': verifiedAt.toIso8601String(),
          'verified_by': verifiedBy,
          'status': OrderStatus.cancelled.name,
        })
        .eq('id', orderId);
    notifyListeners();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
