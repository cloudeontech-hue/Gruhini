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
  /// products, so they can't share one [Order] row. [status] always starts
  /// at [OrderStatus.paymentVerification] regardless of [preVerified] - this
  /// app is prepaid-only, so there's no "place now, pay on delivery" path,
  /// and a pre-verified order still needs the shop owner's explicit "Accept
  /// Order" acknowledgment (see OrderDetailsScreen) rather than silently
  /// appearing already accepted.
  ///
  /// [preVerified] is set by the Razorpay checkout path (see
  /// lib/services/razorpay_service.dart), where [paymentMethod] is
  /// `'razorpay'`, [transactionId] holds the Razorpay *payment* id, and
  /// [razorpayOrderId] holds the Razorpay *order* id - both already
  /// cryptographically confirmed by the verify-razorpay-payment Edge
  /// Function before this is called. It's false (the default) for the
  /// manual QR flow, where [paymentScreenshotBytes]/[transactionId] are
  /// customer-supplied and unverified until a human checks them.
  ///
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
    String paymentMethod = 'upi',
    String? razorpayOrderId,
    bool preVerified = false,
    String verifiedBy = 'razorpay',
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

    final verifiedAt = preVerified ? DateTime.now() : null;
    final newOrders = itemsByShop.entries
        .map(
          (entry) => _buildOrder(
            id: '${batchId}_${_orderSeq++}',
            customerName: customerName,
            customerPhone: customerPhone,
            deliveryAddress: deliveryAddress,
            shopOwnerId: entry.key,
            items: entry.value,
            paymentMethod: paymentMethod,
            paymentScreenshotUrl: screenshotUrl,
            transactionId: transactionId,
            razorpayOrderId: razorpayOrderId,
            preVerified: preVerified,
            verifiedAt: verifiedAt,
            verifiedBy: preVerified ? verifiedBy : null,
          ),
        )
        .toList();

    // A single multi-row insert executes as one atomic SQL statement under
    // PostgREST — either every split order from this cart lands, or none do.
    // That matters most exactly here: a Razorpay payment has already moved
    // real money by this point (see PaymentMethodScreen._payWithRazorpay),
    // so a partial insert would be worse than an all-or-nothing failure the
    // caller can detect and surface to the customer.
    await supabase.from('orders').insert(newOrders.map((o) => o.toMap()).toList());
    _orders.addAll(newOrders);
    notifyListeners();
    return newOrders;
  }

  Order _buildOrder({
    required String id,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String shopOwnerId,
    required List<CartItem> items,
    required String paymentMethod,
    String? paymentScreenshotUrl,
    String? transactionId,
    String? razorpayOrderId,
    required bool preVerified,
    DateTime? verifiedAt,
    String? verifiedBy,
  }) => Order(
    id: id,
    customerName: customerName,
    customerPhone: customerPhone,
    deliveryAddress: deliveryAddress,
    items: items
        .map(
          (c) => OrderLineItem(
            productName: c.product.name,
            price: c.product.price,
            quantity: c.quantity,
          ),
        )
        .toList(),
    total: items.fold(0, (sum, c) => sum + c.subtotal),
    placedAt: DateTime.now(),
    shopOwnerId: shopOwnerId,
    paymentMethod: paymentMethod,
    paymentStatus: preVerified ? PaymentStatus.verified : PaymentStatus.pending,
    paymentScreenshotUrl: paymentScreenshotUrl,
    transactionId: transactionId,
    razorpayOrderId: razorpayOrderId,
    paymentVerified: preVerified,
    verifiedAt: verifiedAt,
    verifiedBy: verifiedBy,
  );

  /// Test-only: exposes [_buildOrder]'s field-mapping logic (the same code
  /// [placeOrder] uses) without requiring a live Supabase connection.
  @visibleForTesting
  Order buildOrderForTest({
    required String id,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String shopOwnerId,
    required List<CartItem> items,
    String paymentMethod = 'upi',
    String? transactionId,
    String? razorpayOrderId,
    bool preVerified = false,
    String? verifiedBy,
  }) => _buildOrder(
    id: id,
    customerName: customerName,
    customerPhone: customerPhone,
    deliveryAddress: deliveryAddress,
    shopOwnerId: shopOwnerId,
    items: items,
    paymentMethod: paymentMethod,
    transactionId: transactionId,
    razorpayOrderId: razorpayOrderId,
    preVerified: preVerified,
    verifiedAt: preVerified ? DateTime.now() : null,
    verifiedBy: preVerified ? (verifiedBy ?? 'razorpay') : null,
  );

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

  /// Test-only: populates orders directly, bypassing Supabase, since widget
  /// tests have no live backend to load from.
  @visibleForTesting
  void seedForTest(List<Order> orders) {
    _orders
      ..clear()
      ..addAll(orders);
    _isLoaded = true;
    notifyListeners();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
