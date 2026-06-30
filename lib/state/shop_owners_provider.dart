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
      _shopOwners.where((s) => s.id == shopOwnerId).firstOrNull?.shopName ??
      'Unknown shop';

  Future<void> load() async {
    try {
      final rows = await supabase
          .from('shop_owners')
          .select('id, username, shop_name, created_at');
      _shopOwners
        ..clear()
        ..addAll(rows.map(ShopOwner.fromMap));
    } catch (error) {
      // Don't leave isLoaded stuck false on a backend hiccup (e.g. a
      // misconfigured RLS/grant) - that would freeze every screen that
      // gates on this provider in a permanent loading spinner.
      debugPrint('Could not load shop owners: $error');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addShopOwner({
    required String username,
    required String password,
    required String shopName,
  }) async {
    final id =
        's${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
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

  /// Verifies [currentPassword] and updates to [newPassword] via the
  /// `change_shop_owner_password` RPC (see
  /// scripts/supabase_schema_shop_owners.sql), which does the comparison
  /// inside the database so the app never reads password_hash directly.
  /// Returns false if [currentPassword] didn't match.
  Future<bool> changePassword({
    required String id,
    required String currentPassword,
    required String newPassword,
  }) async {
    final result = await supabase.rpc(
      'change_shop_owner_password',
      params: {
        'p_id': id,
        'p_current_password_hash': hashPassword(currentPassword),
        'p_new_password_hash': hashPassword(newPassword),
      },
    );
    return result == true;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
