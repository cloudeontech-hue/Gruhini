import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  static const _cartKey = 'cart_items';

  final Map<String, CartItem> _items = {};

  /// True once [restoreFromCatalog] has run - guards against restoring
  /// more than once (e.g. every time HomeScreen rebuilds while the
  /// product catalog is still loading) and against a fresh empty cart's
  /// first save wiping out a not-yet-restored persisted one.
  bool _restored = false;

  List<CartItem> get items => _items.values.toList();

  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get total => _items.values.fold(0, (sum, item) => sum + item.subtotal);

  int quantityOf(String productId) => _items[productId]?.quantity ?? 0;

  void add(Product product) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity++;
    } else {
      _items[product.id] = CartItem(product: product);
    }
    notifyListeners();
    unawaited(_persist());
  }

  void decrement(String productId) {
    final item = _items[productId];
    if (item == null) return;
    if (item.quantity <= 1) {
      _items.remove(productId);
    } else {
      item.quantity--;
    }
    notifyListeners();
    unawaited(_persist());
  }

  void remove(String productId) {
    _items.remove(productId);
    notifyListeners();
    unawaited(_persist());
  }

  void clear() {
    _items.clear();
    notifyListeners();
    unawaited(_persist());
  }

  /// Adds every line item of a past [items] list (see Order.items) back
  /// into the cart, for the "Reorder" action. Matches each line against
  /// [catalog] by [OrderLineItem.productId] first, falling back to
  /// [OrderLineItem.productName] for orders placed before that field
  /// existed. A product that's been removed or gone out of stock since is
  /// skipped and reported in `unavailable` rather than blocking the rest.
  ({int addedCount, List<String> unavailable}) addFromOrder(
    List<OrderLineItem> items,
    List<Product> catalog,
  ) {
    final unavailable = <String>[];
    var addedCount = 0;
    for (final item in items) {
      final match =
          catalog.where((p) => p.id == item.productId).firstOrNull ??
          catalog.where((p) => p.name == item.productName).firstOrNull;
      if (match == null || !match.inStock) {
        unavailable.add(item.productName);
        continue;
      }
      for (var i = 0; i < item.quantity; i++) {
        add(match);
      }
      addedCount++;
    }
    return (addedCount: addedCount, unavailable: unavailable);
  }

  /// Persists just `{productId: quantity}` - not the full [Product]
  /// objects, which would go stale (price/stock/name can change) and
  /// bloat local storage. Called after every mutation; failures are
  /// swallowed since losing a just-made cart edit to a storage hiccup
  /// shouldn't crash the UI interaction that triggered it.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quantities = {
        for (final item in _items.values) item.product.id: item.quantity,
      };
      await prefs.setString(_cartKey, jsonEncode(quantities));
    } catch (error) {
      debugPrint('Could not save cart: $error');
    }
  }

  /// Restores a cart persisted by [_persist], matching each saved
  /// productId against the live [catalog] so price/stock/name always
  /// reflect what's current rather than a stale snapshot. A product no
  /// longer in the catalog (removed, or catalog not loaded yet) is
  /// silently dropped from the restored cart rather than blocking the
  /// rest. Call once catalog is non-empty - typically from the screen
  /// that first shows the product grid, guarded so it only ever runs
  /// once per app session (see [restored]).
  Future<void> restoreFromCatalog(List<Product> catalog) async {
    if (_restored) return;
    _restored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cartKey);
      if (raw == null || raw.isEmpty) return;
      final quantities = (jsonDecode(raw) as Map<String, dynamic>).map(
        (id, qty) => MapEntry(id, (qty as num).toInt()),
      );
      final byId = {for (final p in catalog) p.id: p};
      for (final entry in quantities.entries) {
        final product = byId[entry.key];
        if (product == null) continue;
        _items[entry.key] = CartItem(product: product, quantity: entry.value);
      }
      if (_items.isNotEmpty) notifyListeners();
    } catch (error) {
      debugPrint('Could not restore cart: $error');
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
