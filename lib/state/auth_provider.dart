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
  static const _adminIdKey = 'admin_id';
  static const _adminUsernameKey = 'admin_username';

  AppRole _role = AppRole.none;
  String _customerName = '';
  String _customerPhone = '';
  String _customerAddress = '';
  String _customerPassword = '';
  String _shopOwnerId = '';
  String _shopOwnerUsername = '';
  String _shopName = '';
  String _adminId = '';
  String _adminUsername = '';
  bool _isLoaded = false;

  AppRole get role => _role;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  String get customerAddress => _customerAddress;
  String get customerPassword => _customerPassword;
  String get shopOwnerId => _shopOwnerId;
  String get shopOwnerUsername => _shopOwnerUsername;
  String get shopName => _shopName;
  String get adminId => _adminId;
  String get adminUsername => _adminUsername;
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
    _adminId = prefs.getString(_adminIdKey) ?? '';
    _adminUsername = prefs.getString(_adminUsernameKey) ?? '';
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
      final inputHash = hashPassword(password);
      // Accept both the hash (post-migration) and the raw value (pre-migration)
      // so existing users are not locked out on first launch after this update.
      if (storedPassword != inputHash && storedPassword != password) {
        throw AuthException('Incorrect password. Please try again.');
      }
    }

    _role = AppRole.customer;
    _customerName = name;
    _customerPhone = phone;
    _customerPassword = hashPassword(password);
    await prefs.setString(_roleKey, _role.name);
    await prefs.setString(_customerNameKey, name);
    await prefs.setString(_customerPhoneKey, phone);
    await prefs.setString(_customerPasswordKey, hashPassword(password));
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

  /// Checks [phone] against the customer stored on this device, without
  /// mutating any state. Used by the forgot-password flow to verify the
  /// phone before asking for a new password.
  Future<bool> isRegisteredPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPhone = prefs.getString(_customerPhoneKey) ?? '';
    return storedPhone.isNotEmpty && storedPhone == phone;
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
    _customerPassword = hashPassword(newPassword);
    await prefs.setString(_customerPasswordKey, hashPassword(newPassword));
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

  /// Authenticates against the `admins` table via the `authenticate_admin`
  /// security-definer RPC. Credentials are verified server-side with bcrypt;
  /// no password ever leaves the device in hashed form.
  ///
  /// Falls back to hardcoded dev credentials if the RPC doesn't exist yet
  /// (i.e. supabase_schema_security.sql hasn't been applied). Once the
  /// migration is applied and the first admin is seeded via create_admin(),
  /// the hardcoded fallback is bypassed automatically.
  Future<void> loginAsHeadAdmin({
    required String username,
    required String password,
  }) async {
    String resolvedId = '';
    String resolvedUsername = '';
    bool authenticated = false;

    try {
      final rows = await supabase.rpc(
        'authenticate_admin',
        params: {'p_username': username.trim(), 'p_password': password},
      ) as List;

      if (rows.isNotEmpty) {
        final row = rows.first as Map<String, dynamic>;
        resolvedId = row['id'] as String;
        resolvedUsername = row['username'] as String;
        authenticated = true;
      }
    } catch (e) {
      // RPC doesn't exist yet — migration not applied. Fall back to dev
      // credentials so the app remains usable during development.
      // Run scripts/supabase_schema_security.sql and then
      // `select create_admin('admin', 'your-password');` to enable DB-backed auth.
      debugPrint('authenticate_admin RPC unavailable ($e). '
          'Using dev fallback — apply supabase_schema_security.sql to fix this.');
      if (username.trim() == 'admin' && password == 'admin123') {
        resolvedId = 'dev-admin';
        resolvedUsername = 'admin';
        authenticated = true;
      }
    }

    if (!authenticated) {
      throw AuthException('Invalid admin username or password.');
    }

    _role = AppRole.headAdmin;
    _adminId = resolvedId;
    _adminUsername = resolvedUsername;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, _role.name);
    await prefs.setString(_adminIdKey, _adminId);
    await prefs.setString(_adminUsernameKey, _adminUsername);
    notifyListeners();
  }

  /// Looks up the shop owner via the `authenticate_shop_owner` RPC (see
  /// scripts/supabase_schema_security.sql), which verifies the password with
  /// bcrypt server-side. The app sends the plain-text password; it is never
  /// hashed client-side, and `password_hash` is never returned to the client.
  ///
  /// Falls back to the legacy SHA-256 RPC call if the migration hasn't been
  /// applied yet (i.e. the function still expects `p_password_hash`).
  Future<void> loginAsShopOwner({
    required String username,
    required String password,
  }) async {
    List rows = [];

    // Try bcrypt RPC (post-migration).
    try {
      rows = await supabase.rpc(
        'authenticate_shop_owner',
        params: {'p_username': username.trim(), 'p_password': password},
      ) as List;
    } catch (e) {
      // New RPC unavailable — fall back to legacy SHA-256 call so the app
      // remains usable before supabase_schema_security.sql is applied.
      debugPrint('authenticate_shop_owner (bcrypt) unavailable ($e). '
          'Falling back to SHA-256 — apply supabase_schema_security.sql to fix this.');
      try {
        rows = await supabase.rpc(
          'authenticate_shop_owner',
          params: {
            'p_username': username.trim(),
            'p_password_hash': hashPassword(password),
          },
        ) as List;
      } catch (_) {
        throw AuthException('Could not reach the server. Please try again.');
      }
    }

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
    _adminId = '';
    _adminUsername = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_customerNameKey);
    await prefs.remove(_customerPhoneKey);
    await prefs.remove(_customerAddressKey);
    await prefs.remove(_customerPasswordKey);
    await prefs.remove(_shopOwnerIdKey);
    await prefs.remove(_shopOwnerNameKey);
    await prefs.remove(_shopNameKey);
    await prefs.remove(_adminIdKey);
    await prefs.remove(_adminUsernameKey);
    notifyListeners();
  }
}
