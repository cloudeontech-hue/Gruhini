import 'dart:typed_data';

enum ProductCategory { snacks, sweets, pickles }

extension ProductCategoryLabel on ProductCategory {
  String get label {
    switch (this) {
      case ProductCategory.snacks:
        return 'Snacks';
      case ProductCategory.sweets:
        return 'Sweets';
      case ProductCategory.pickles:
        return 'Pickles';
    }
  }
}

class Product {
  final String id;
  String name;
  ProductCategory category;
  double price;
  String unit;
  String imagePath;
  String description;
  bool inStock;

  /// The shop owner this product belongs to. Customers see products from
  /// every shop owner; each shop owner only sees/manages their own.
  final String shopOwnerId;

  /// Bytes of an admin-picked replacement photo. When set, this takes
  /// priority over [imagePath] everywhere the product image is rendered.
  Uint8List? imageBytes;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.unit,
    required this.imagePath,
    required this.description,
    required this.shopOwnerId,
    this.inStock = true,
    this.imageBytes,
  });

  /// An independent copy of this product. [ProductsProvider] seeds itself
  /// with copies (rather than sharing instances with the static catalog
  /// data) so that in-place edits don't leak into the shared seed list.
  Product copy() => Product(
    id: id,
    name: name,
    category: category,
    price: price,
    unit: unit,
    imagePath: imagePath,
    description: description,
    shopOwnerId: shopOwnerId,
    inStock: inStock,
    imageBytes: imageBytes,
  );

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'] as String,
    name: map['name'] as String,
    category: ProductCategory.values.firstWhere(
      (c) => c.name == map['category'],
    ),
    price: (map['price'] as num).toDouble(),
    unit: map['unit'] as String,
    imagePath: map['image_path'] as String,
    description: map['description'] as String,
    shopOwnerId: map['shop_owner_id'] as String,
    inStock: map['in_stock'] as bool,
  );

  /// Row payload for Supabase. [imageBytes] is a transient, local-only
  /// picker preview and is never persisted directly — it's uploaded to
  /// Storage first and the resulting URL is what ends up in [imagePath].
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category.name,
    'price': price,
    'unit': unit,
    'image_path': imagePath,
    'description': description,
    'shop_owner_id': shopOwnerId,
    'in_stock': inStock,
  };
}
