import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/product_image_uploader.dart';
import '../services/supabase_client.dart';

class ProductsProvider extends ChangeNotifier {
  final List<Product> _products = [];
  bool _isLoaded = false;

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    try {
      final rows = await supabase.from('products').select();
      _products
        ..clear()
        ..addAll(rows.map(Product.fromMap));
    } catch (error) {
      // Don't leave isLoaded stuck false on a backend hiccup - that would
      // freeze every screen that gates on this provider in a permanent
      // loading spinner.
      debugPrint('Could not load products: $error');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addProduct({
    required String name,
    required ProductCategory category,
    required double price,
    required String unit,
    required String imagePath,
    required String description,
    required String shopOwnerId,
    Uint8List? imageBytes,
  }) async {
    final id =
        'p${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
    final resolvedImagePath = imageBytes != null
        ? await uploadProductImage(id, imageBytes)
        : imagePath;

    final product = Product(
      id: id,
      name: name,
      category: category,
      price: price,
      unit: unit,
      imagePath: resolvedImagePath,
      description: description,
      shopOwnerId: shopOwnerId,
      imageBytes: imageBytes,
    );
    await supabase.from('products').insert(product.toMap());
    _products.add(product);
    notifyListeners();
  }

  /// Mutates the existing [Product] in place rather than replacing it in
  /// the list, so that other parts of the app already holding a reference
  /// to this product (e.g. items already in the cart, or a product details
  /// screen that's currently open) automatically pick up the changes.
  Future<void> updateProduct(
    String id, {
    required String name,
    required ProductCategory category,
    required double price,
    required String unit,
    required String imagePath,
    required String description,
    Uint8List? imageBytes,
  }) async {
    final product = _products.where((p) => p.id == id).firstOrNull;
    if (product == null) return;

    final resolvedImagePath = imageBytes != null
        ? await uploadProductImage(id, imageBytes)
        : imagePath;

    product.name = name;
    product.category = category;
    product.price = price;
    product.unit = unit;
    product.imagePath = resolvedImagePath;
    product.description = description;
    if (imageBytes != null) product.imageBytes = imageBytes;
    await supabase.from('products').update(product.toMap()).eq('id', id);
    notifyListeners();
  }

  Future<void> toggleStock(String id) async {
    final product = _products.where((p) => p.id == id).firstOrNull;
    if (product == null) return;
    product.inStock = !product.inStock;
    await supabase
        .from('products')
        .update({'in_stock': product.inStock})
        .eq('id', id);
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    await supabase.from('products').delete().eq('id', id);
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
