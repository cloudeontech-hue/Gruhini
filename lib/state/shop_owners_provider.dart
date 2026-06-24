import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/shop_owner.dart';
import '../services/supabase_client.dart';
import '../utils/password_hash.dart';

class ShopOwnersProvider extends ChangeNotifier {
  final List<ShopOwner> _shopOwners = [];
  bool _isLoaded = false;

  List<ShopOwner> get shopOwners => List.unmodifiable(_shopOwners);
  bool get isLoaded => _isLoaded;

  String shopNameFor(String shopOwnerId) =>
      _shopOwners.where((s) => s.id == shopOwnerId).firstOrNull?.shopName ?? 'Unknown shop';

  Future<void> load() async {
    final rows = await supabase.from('shop_owners').select('id, username, shop_name, created_at');
    _shopOwners
      ..clear()
      ..addAll(rows.map(ShopOwner.fromMap));
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addShopOwner({
    required String username,
    required String password,
    required String shopName,
  }) async {
    final id = 's${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
    await supabase.from('shop_owners').insert({
      'id': id,
      'username': username,
      'password_hash': hashPassword(password),
      'shop_name': shopName,
    });
    await load();
  }

  Future<void> deleteShopOwner(String id) async {
    await supabase.from('shop_owners').delete().eq('id', id);
    _shopOwners.removeWhere((s) => s.id == id);
    notifyListeners();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
