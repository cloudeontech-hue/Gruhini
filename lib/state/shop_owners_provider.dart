import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/shop_owner.dart';
import '../services/supabase_client.dart';

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

  /// Creates a new shop owner via the `create_shop_owner` security-definer
  /// RPC, which hashes the password with bcrypt server-side. The plain-text
  /// password is sent to the RPC over TLS; it is never hashed client-side.
  Future<void> addShopOwner({
    required String username,
    required String password,
    required String shopName,
  }) async {
    final id =
        's${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
    await supabase.rpc('create_shop_owner', params: {
      'p_id': id,
      'p_username': username,
      'p_password': password,
      'p_shop_name': shopName,
    });
    await load();
  }

  Future<void> deleteShopOwner(String id) async {
    await supabase.from('shop_owners').delete().eq('id', id);
    _shopOwners.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Verifies [currentPassword] and updates to [newPassword] via the
  /// `change_shop_owner_password` RPC (see supabase/migrations/20260702132100_security_hardening_bcrypt_auth.sql),
  /// which does bcrypt verification and re-hashing server-side.
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
        'p_current_password': currentPassword,
        'p_new_password': newPassword,
      },
    );
    return result == true;
  }

  /// Resets a shop owner's password without requiring the current password.
  /// Admin-only action — calls the `reset_shop_owner_password` RPC.
  Future<void> resetShopOwnerPassword({
    required String id,
    required String newPassword,
  }) async {
    await supabase.rpc('reset_shop_owner_password', params: {
      'p_id': id,
      'p_new_password': newPassword,
    });
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
