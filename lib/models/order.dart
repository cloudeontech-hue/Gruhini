enum OrderStatus { pending, packed, delivered, cancelled }

extension OrderStatusLabel on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.packed:
        return 'Packed';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class OrderLineItem {
  final String productName;
  final double price;
  final int quantity;

  const OrderLineItem({
    required this.productName,
    required this.price,
    required this.quantity,
  });

  double get subtotal => price * quantity;

  factory OrderLineItem.fromMap(Map<String, dynamic> map) => OrderLineItem(
        productName: map['productName'] as String,
        price: (map['price'] as num).toDouble(),
        quantity: map['quantity'] as int,
      );

  Map<String, dynamic> toMap() => {
        'productName': productName,
        'price': price,
        'quantity': quantity,
      };
}

class Order {
  final String id;
  final String customerName;
  final String customerPhone;
  final List<OrderLineItem> items;
  final double total;
  final DateTime placedAt;
  final String shopOwnerId;
  OrderStatus status;

  Order({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.total,
    required this.placedAt,
    required this.shopOwnerId,
    this.status = OrderStatus.pending,
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
        items: (map['items'] as List)
            .map((item) => OrderLineItem.fromMap(item as Map<String, dynamic>))
            .toList(),
        total: (map['total'] as num).toDouble(),
        placedAt: DateTime.parse(map['placed_at'] as String),
        shopOwnerId: map['shop_owner_id'] as String,
        status: OrderStatus.values.firstWhere((s) => s.name == map['status']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'items': items.map((i) => i.toMap()).toList(),
        'total': total,
        'placed_at': placedAt.toIso8601String(),
        'shop_owner_id': shopOwnerId,
        'status': status.name,
      };
}
