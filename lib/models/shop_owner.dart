class ShopOwner {
  final String id;
  final String username;
  final String shopName;
  final DateTime createdAt;

  const ShopOwner({
    required this.id,
    required this.username,
    required this.shopName,
    required this.createdAt,
  });

  /// Built from a row that only ever selects the public columns —
  /// [ShopOwnersProvider.load] explicitly excludes `password_hash` — even
  /// though the database itself doesn't enforce that restriction (see
  /// supabase/migrations/20260626123501_shop_owners.sql).
  factory ShopOwner.fromMap(Map<String, dynamic> map) => ShopOwner(
    id: map['id'] as String,
    username: map['username'] as String,
    shopName: map['shop_name'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
