import 'products_data.dart';

import '../models/order.dart';

final List<Order> ordersData = [
  Order(
    id: 'o1',
    customerName: 'Asha Rao',
    customerPhone: '9876543210',
    items: const [
      OrderLineItem(productName: 'Murukku', price: 120, quantity: 2),
      OrderLineItem(productName: 'Banana Chips', price: 90, quantity: 1),
    ],
    total: 330,
    placedAt: DateTime(2026, 6, 18),
    shopOwnerId: defaultShopOwnerId,
    status: OrderStatus.delivered,
  ),
  Order(
    id: 'o2',
    customerName: 'Asha Rao',
    customerPhone: '9876543210',
    items: const [
      OrderLineItem(productName: 'Mysore Pak', price: 180, quantity: 1),
      OrderLineItem(productName: 'Badam Milk', price: 150, quantity: 1),
    ],
    total: 330,
    placedAt: DateTime(2026, 6, 20),
    shopOwnerId: defaultShopOwnerId,
    status: OrderStatus.packed,
  ),
];
