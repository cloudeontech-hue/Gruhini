enum OrderStatus {
  paymentVerification,
  accepted,
  preparing,
  outForDelivery,
  delivered,
  cancelled,
}

extension OrderStatusLabel on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.paymentVerification:
        return 'Payment Verification';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

enum PaymentStatus { pending, verified, rejected }

extension PaymentStatusLabel on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending Verification';
      case PaymentStatus.verified:
        return 'Verified';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }
}

class OrderLineItem {
  final String productName;
  final double price;
  final int quantity;

  /// Null for orders placed before this field existed - Reorder (see
  /// lib/utils/reorder.dart) falls back to matching by [productName]
  /// against the live catalog for those.
  final String? productId;

  const OrderLineItem({
    required this.productName,
    required this.price,
    required this.quantity,
    this.productId,
  });

  double get subtotal => price * quantity;

  factory OrderLineItem.fromMap(Map<String, dynamic> map) => OrderLineItem(
    productName: map['productName'] as String,
    price: (map['price'] as num).toDouble(),
    quantity: map['quantity'] as int,
    productId: map['productId'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'productName': productName,
    'price': price,
    'quantity': quantity,
    'productId': productId,
  };
}

class Order {
  final String id;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final List<OrderLineItem> items;
  final double total;
  final DateTime placedAt;
  final String shopOwnerId;
  OrderStatus status;

  /// 'upi' for the manual QR flow (web/desktop), 'razorpay' for the
  /// cryptographically-verified mobile flow - this app is prepaid-only, no
  /// Cash on Delivery either way.
  final String paymentMethod;
  PaymentStatus paymentStatus;
  String? paymentScreenshotUrl;
  String? transactionId;
  bool paymentVerified;
  DateTime? verifiedAt;
  String? verifiedBy;

  /// Razorpay's order id (distinct from [transactionId], which holds the
  /// Razorpay *payment* id for this payment method) - null for the manual
  /// UPI flow. See supabase/migrations/20260710115900_razorpay_order_id.sql.
  String? razorpayOrderId;

  Order({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.items,
    required this.total,
    required this.placedAt,
    required this.shopOwnerId,
    this.status = OrderStatus.paymentVerification,
    this.paymentMethod = 'upi',
    this.paymentStatus = PaymentStatus.pending,
    this.paymentScreenshotUrl,
    this.transactionId,
    this.paymentVerified = false,
    this.verifiedAt,
    this.verifiedBy,
    this.razorpayOrderId,
  });

  /// A short, display-friendly order number derived from [id].
  /// Falls back gracefully for ids shorter than the usual generated length.
  String get shortId {
    final body = id.length > 1 ? id.substring(1) : id;
    return body.length <= 5 ? body : body.substring(0, 5);
  }

  factory Order.fromMap(Map<String, dynamic> map) => Order(
    id: map['id'] as String,
    customerName: map['customer_name'] as String,
    customerPhone: map['customer_phone'] as String,
    deliveryAddress: map['delivery_address'] as String? ?? '',
    items: (map['items'] as List)
        .map((item) => OrderLineItem.fromMap(item as Map<String, dynamic>))
        .toList(),
    total: (map['total'] as num).toDouble(),
    placedAt: DateTime.parse(map['placed_at'] as String),
    shopOwnerId: map['shop_owner_id'] as String,
    status: OrderStatus.values.firstWhere(
      (s) => s.name == map['status'],
      orElse: () => OrderStatus.paymentVerification,
    ),
    paymentMethod: map['payment_method'] as String? ?? 'upi',
    paymentStatus: PaymentStatus.values.firstWhere(
      (s) => s.name == map['payment_status'],
      orElse: () => PaymentStatus.pending,
    ),
    paymentScreenshotUrl: map['payment_screenshot_url'] as String?,
    transactionId: map['transaction_id'] as String?,
    paymentVerified: map['payment_verified'] as bool? ?? false,
    verifiedAt: map['verified_at'] != null
        ? DateTime.parse(map['verified_at'] as String)
        : null,
    verifiedBy: map['verified_by'] as String?,
    razorpayOrderId: map['razorpay_order_id'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'delivery_address': deliveryAddress,
    'items': items.map((i) => i.toMap()).toList(),
    'total': total,
    'placed_at': placedAt.toIso8601String(),
    'shop_owner_id': shopOwnerId,
    'status': status.name,
    'payment_method': paymentMethod,
    'payment_status': paymentStatus.name,
    'payment_screenshot_url': paymentScreenshotUrl,
    'transaction_id': transactionId,
    'payment_verified': paymentVerified,
    'verified_at': verifiedAt?.toIso8601String(),
    'verified_by': verifiedBy,
    'razorpay_order_id': razorpayOrderId,
  };
}
