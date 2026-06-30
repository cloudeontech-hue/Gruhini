import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_client.dart';
import '../utils/password_hash.dart';

enum AppRole { none, customer, headAdmin, shopOwner }

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthProvider extends ChangeNotifier {
  static const _roleKey = 'app_role';
  static const _customerNameKey = 'customer_name';
  static const _customerPhoneKey = 'customer_phone';
  static const _customerAddressKey = 'customer_address';
  static const _customerPasswordKey = 'customer_password';
  static const _shopOwnerIdKey = 'shop_owner_id';
  static const _shopOwnerNameKey = 'shop_owner_name';
  static const _shopNameKey = 'shop_name';

  /// There is intentionally only ever one head admin account, so it stays
  /// hardcoded rather than living in a table. Shop owners (the "sub admins")
  /// are the ones stored in Supabase, since there can be many of them.
  static const headAdminUsername = 'admin';
  static const headAdminPassword = 'admin123';

  AppRole _role = AppRole.none;
  String _customerName = '';
  String _customerPhone = '';
  String _customerAddress = '';
  String _customerPassword = '';
  String _shopOwnerId = '';
  String _shopOwnerUsername = '';
  String _shopName = '';
  bool _isLoaded = false;

  AppRole get role => _role;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  String get customerAddress => _customerAddress;
  String get customerPassword => _customerPassword;
  String get shopOwnerId => _shopOwnerId;
  String get shopOwnerUsername => _shopOwnerUsername;
  String get shopName => _shopName;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedRole = prefs.getString(_roleKey);
    _role = AppRole.values.firstWhere(
      (r) => r.name == storedRole,
      orElse: () => AppRole.none,
    );
    _customerName = prefs.getString(_customerNameKey) ?? '';
    _customerPhone = prefs.getString(_customerPhoneKey) ?? '';
    _customerAddress = prefs.getString(_customerAddressKey) ?? '';
    _customerPassword = prefs.getString(_customerPasswordKey) ?? '';
    _shopOwnerId = prefs.getString(_shopOwnerIdKey) ?? '';
    _shopOwnerUsername = prefs.getString(_shopOwnerNameKey) ?? '';
    _shopName = prefs.getString(_shopNameKey) ?? '';
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> loginAsCustomer({
    required String name,
    required String phone,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPhone = prefs.getString(_customerPhoneKey) ?? '';
    final storedPassword = prefs.getString(_customerPasswordKey) ?? '';

    // Returning customer on the same device: verify their password.
    if (storedPhone == phone && storedPassword.isNotEmpty) {
      if (storedPassword != password) {
        throw AuthException('Incorrect password. Please try again.');
      }
    }

    _role = AppRole.customer;
    _customerName = name;
    _customerPhone = phone;
    _customerPassword = password;
    await prefs.setString(_roleKey, _role.name);
    await prefs.setString(_customerNameKey, name);
    await prefs.setString(_customerPhoneKey, phone);
    await prefs.setString(_customerPasswordKey, password);
    await _saveNewCustomer(name: name, phone: phone, address: _customerAddress);
    notifyListeners();
  }

  /// Persists first-time customers to Supabase's `customers` table so they
  /// show up in the head admin's Customers screen — keyed by phone number,
  /// the natural unique id customers log in with. Returning customers
  /// (phone already on file) are left untouched.
  Future<void> _saveNewCustomer({
    required String name,
    required String phone,
    required String address,
  }) async {
    try {
      final existing = await supabase
          .from('customers')
          .select('id')
          .eq('id', phone)
          .maybeSingle();
      if (existing != null) return;
      await supabase.from('customers').insert({
        'id': phone,
        'name': name,
        'phone': phone,
        'address': address,
      });
    } catch (error) {
      // Customer login is otherwise local-only (SharedPreferences); don't
      // let a Supabase hiccup (e.g. offline) block the customer from
      // logging in just because we couldn't sync them to the admin list.
      debugPrint('Could not save customer record: $error');
    }
  }

  /// Resets the password for the customer whose phone is stored on this
  /// device. Throws [AuthException] if the phone doesn't match.
  Future<void> resetCustomerPassword({
    required String phone,
    required String newPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPhone = prefs.getString(_customerPhoneKey) ?? '';
    if (storedPhone.isEmpty || storedPhone != phone) {
      throw AuthException(
        'No account found with this phone number on this device.',
      );
    }
    _customerPassword = newPassword;
    await prefs.setString(_customerPasswordKey, newPassword);
    notifyListeners();
  }

  Future<void> updateCustomerPhone(String phone) async {
    _customerPhone = phone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customerPhoneKey, phone);
    notifyListeners();
  }

  Future<void> updateCustomerAddress(String address) async {
    _customerAddress = address;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customerAddressKey, address);
    notifyListeners();
  }

  Future<void> loginAsHeadAdmin({
    required String username,
    required String password,
  }) async {
    if (username.trim() != headAdminUsername || password != headAdminPassword) {
      throw AuthException('Invalid admin username or password.');
    }
    _role = AppRole.headAdmin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, _role.name);
    notifyListeners();
  }

  /// Looks up the shop owner via the `authenticate_shop_owner` RPC (see
  /// scripts/supabase_schema_shop_owners.sql), which does the password_hash
  /// comparison inside the database — the app never reads password_hash
  /// directly, since anon access to that column is revoked.
  Future<void> loginAsShopOwner({
    required String username,
    required String password,
  }) async {
    final rows =
        await supabase.rpc(
              'authenticate_shop_owner',
              params: {
                'p_username': username.trim(),
                'p_password_hash': hashPassword(password),
              },
            )
            as List;

    if (rows.isEmpty) {
      throw AuthException('Invalid shop owner username or password.');
    }

    final row = rows.first as Map<String, dynamic>;
    _role = AppRole.shopOwner;
    _shopOwnerId = row['id'] as String;
    _shopOwnerUsername = row['username'] as String;
    _shopName = row['shop_name'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, _role.name);
    await prefs.setString(_shopOwnerIdKey, _shopOwnerId);
    await prefs.setString(_shopOwnerNameKey, _shopOwnerUsername);
    await prefs.setString(_shopNameKey, _shopName);
    notifyListeners();
  }

  Future<void> logout() async {
    _role = AppRole.none;
    _customerName = '';
    _customerPhone = '';
    _customerAddress = '';
    _customerPassword = '';
    _shopOwnerId = '';
    _shopOwnerUsername = '';
    _shopName = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_customerNameKey);
    await prefs.remove(_customerPhoneKey);
    await prefs.remove(_customerAddressKey);
    await prefs.remove(_customerPasswordKey);
    await prefs.remove(_shopOwnerIdKey);
    await prefs.remove(_shopOwnerNameKey);
    await prefs.remove(_shopNameKey);
    notifyListeners();
  }
}
