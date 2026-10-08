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
  static const _shopOwnerIdKey = 'shop_owner_id';
  static const _shopOwnerNameKey = 'shop_owner_name';
  static const _shopNameKey = 'shop_name';
  static const _adminIdKey = 'admin_id';
  static const _adminUsernameKey = 'admin_username';

  AppRole _role = AppRole.none;
  String _customerName = '';
  String _customerPhone = '';
  String _customerAddress = '';
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
    _shopOwnerId = prefs.getString(_shopOwnerIdKey) ?? '';
    _shopOwnerUsername = prefs.getString(_shopOwnerNameKey) ?? '';
    _shopName = prefs.getString(_shopNameKey) ?? '';
    _adminId = prefs.getString(_adminIdKey) ?? '';
    _adminUsername = prefs.getString(_adminUsernameKey) ?? '';
    _isLoaded = true;
    notifyListeners();
  }

  /// Test-only bypass for [loginAsCustomerViaOtp]'s real
  /// get_or_create_customer RPC, which needs a live Supabase connection
  /// the test environment doesn't have — same reasoning as
  /// [simulateAdminLoginForTest] above.
  @visibleForTesting
  void simulateCustomerLoginForTest({
    required String name,
    required String phone,
    String address = '',
  }) {
    _role = AppRole.customer;
    _customerName = name;
    _customerPhone = phone;
    _customerAddress = address;
    notifyListeners();
  }

  /// Logs in (or, for a brand-new phone number, silently creates) a
  /// customer account via the get_or_create_customer() RPC —
  /// supabase/migrations/20260910120400_customer_otp_auth.sql. Call this only *after*
  /// LoginScreen has already verified the phone number with Firebase
  /// Phone Auth (a real SMS OTP) — there's no password to check
  /// server-side any more, since Firebase's verification already proved
  /// ownership of the phone number more strongly than a password ever
  /// did. The same phone number reconnects to the same real account from
  /// any device or after a logout, exactly like the password-based
  /// version did, just without a password to remember or reset.
  Future<void> loginAsCustomerViaOtp({
    required String name,
    required String phone,
  }) async {
    List rows;
    try {
      rows = await supabase.rpc(
        'get_or_create_customer',
        params: {'p_phone': phone.trim(), 'p_name': name.trim()},
      ) as List;
    } catch (e) {
      debugPrint('get_or_create_customer unavailable ($e).');
      throw AuthException(
        'Could not reach the server. Please check your connection and try again.',
      );
    }

    if (rows.isEmpty) {
      throw AuthException('Could not sign you in. Please try again.');
    }

    final row = rows.first as Map<String, dynamic>;
    _role = AppRole.customer;
    // Use the server's stored name/address, not what was just typed — a
    // returning customer's real profile, not a blank slate.
    _customerName = row['name'] as String;
    _customerPhone = row['phone'] as String;
    _customerAddress = row['address'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, _role.name);
    await prefs.setString(_customerNameKey, _customerName);
    await prefs.setString(_customerPhoneKey, _customerPhone);
    await prefs.setString(_customerAddressKey, _customerAddress);
    notifyListeners();
  }

  /// Checks whether [googleUid] (Firebase's uid for a signed-in Google
  /// account) is already linked to a customer, via
  /// get_customer_by_google_uid() — supabase/migrations/20260915122700_customer_google_auth.sql.
  /// Call this right after Firebase confirms the Google sign-in, to decide
  /// whether LoginScreen needs to ask for a phone number (first time ever
  /// seeing this Google account) or can skip straight to
  /// [loginAsCustomerViaGoogle] with an already-known phone.
  Future<Map<String, dynamic>?> findCustomerByGoogleUid(
    String googleUid,
  ) async {
    try {
      final rows =
          await supabase.rpc(
                'get_customer_by_google_uid',
                params: {'p_google_uid': googleUid},
              )
              as List;
      return rows.isEmpty ? null : rows.first as Map<String, dynamic>;
    } catch (e) {
      debugPrint('get_customer_by_google_uid unavailable ($e).');
      return null;
    }
  }

  /// Logs in via link_google_customer() —
  /// supabase/migrations/20260915122700_customer_google_auth.sql. Call this only *after*
  /// Firebase has already confirmed the Google sign-in - [googleUid] is
  /// Firebase's uid for that account, which is what actually proves
  /// identity here; [phone] only matters the first time a given Google
  /// account is seen (every later call re-links the same row and ignores
  /// [phone]/[name], same convention as [loginAsCustomerViaOtp]).
  Future<void> loginAsCustomerViaGoogle({
    required String googleUid,
    required String phone,
    required String name,
  }) async {
    List rows;
    try {
      rows = await supabase.rpc(
        'link_google_customer',
        params: {
          'p_google_uid': googleUid,
          'p_phone': phone.trim(),
          'p_name': name.trim(),
        },
      ) as List;
    } catch (e) {
      debugPrint('link_google_customer unavailable ($e).');
      throw AuthException(
        'Could not reach the server. Please check your connection and try again.',
      );
    }

    if (rows.isEmpty) {
      throw AuthException('Could not sign you in. Please try again.');
    }

    final row = rows.first as Map<String, dynamic>;
    _role = AppRole.customer;
    _customerName = row['name'] as String;
    _customerPhone = row['phone'] as String;
    _customerAddress = row['address'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, _role.name);
    await prefs.setString(_customerNameKey, _customerName);
    await prefs.setString(_customerPhoneKey, _customerPhone);
    await prefs.setString(_customerAddressKey, _customerAddress);
    notifyListeners();
  }

  Future<void> updateCustomerPhone(String phone) async {
    _customerPhone = phone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customerPhoneKey, phone);
    notifyListeners();
  }

  /// Also syncs to Supabase (not just local SharedPreferences) so the
  /// address survives a logout/login, a cleared local storage, or logging
  /// in on a different device - see supabase/migrations/20260821151700_customer_password_auth.sql
  /// for the column-level UPDATE grant this needs. Best-effort: a network
  /// hiccup shouldn't block the local save that the customer is actively
  /// looking at right now.
  Future<void> updateCustomerAddress(String address) async {
    _customerAddress = address;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customerAddressKey, address);
    notifyListeners();
    try {
      await supabase
          .from('customers')
          .update({'address': address})
          .eq('id', _customerPhone);
    } catch (error) {
      debugPrint('Could not sync address to server: $error');
    }
  }

  /// Test-only: sets head-admin state directly, without the real
  /// authenticate_admin RPC (no live Supabase connection in the test
  /// environment). There is no dev-credential bypass in [loginAsHeadAdmin]
  /// itself - that was removed as a release-security fix, since it shipped
  /// as reachable, decompilable code in every build.
  @visibleForTesting
  void simulateAdminLoginForTest({required String username}) {
    _role = AppRole.headAdmin;
    _adminId = 'test-admin';
    _adminUsername = username;
    notifyListeners();
  }

  /// Authenticates against the `admins` table via the `authenticate_admin`
  /// security-definer RPC. Credentials are verified server-side with bcrypt;
  /// no password ever leaves the device in hashed form.
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
      debugPrint('authenticate_admin RPC call failed: $e');
      throw AuthException('Could not reach the server. Please try again.');
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

  /// Single staff sign-in for both Admins and Shop Owners — see
  /// StaffLoginScreen. Tries the `authenticate_admin` RPC first, then
  /// `authenticate_shop_owner`, and sets whichever role matched, so staff
  /// only need one login screen instead of picking their own role first.
  ///
  /// Deliberately does its own RPC calls rather than chaining
  /// [loginAsHeadAdmin] and [loginAsShopOwner]: both of those throw
  /// [AuthException] for *both* wrong credentials and a network failure,
  /// so chaining them would report a server outage as "invalid username or
  /// password". Calling the RPCs here keeps those two cases separable.
  Future<void> loginAsStaff({
    required String username,
    required String password,
  }) async {
    final params = {'p_username': username.trim(), 'p_password': password};

    List adminRows;
    List ownerRows;
    try {
      adminRows = await supabase.rpc('authenticate_admin', params: params) as List;
      ownerRows = adminRows.isEmpty
          ? await supabase.rpc('authenticate_shop_owner', params: params) as List
          : const [];
    } catch (e) {
      debugPrint('Staff authentication RPC failed: $e');
      throw AuthException('Could not reach the server. Please try again.');
    }

    final prefs = await SharedPreferences.getInstance();

    if (adminRows.isNotEmpty) {
      final row = adminRows.first as Map<String, dynamic>;
      _role = AppRole.headAdmin;
      _adminId = row['id'] as String;
      _adminUsername = row['username'] as String;
      await prefs.setString(_roleKey, _role.name);
      await prefs.setString(_adminIdKey, _adminId);
      await prefs.setString(_adminUsernameKey, _adminUsername);
      notifyListeners();
      return;
    }

    if (ownerRows.isNotEmpty) {
      final row = ownerRows.first as Map<String, dynamic>;
      _role = AppRole.shopOwner;
      _shopOwnerId = row['id'] as String;
      _shopOwnerUsername = row['username'] as String;
      _shopName = row['shop_name'] as String;
      await prefs.setString(_roleKey, _role.name);
      await prefs.setString(_shopOwnerIdKey, _shopOwnerId);
      await prefs.setString(_shopOwnerNameKey, _shopOwnerUsername);
      await prefs.setString(_shopNameKey, _shopName);
      notifyListeners();
      return;
    }

    throw AuthException('Invalid username or password.');
  }

  /// Looks up the shop owner via the `authenticate_shop_owner` RPC (see
  /// supabase/migrations/20260702132100_security_hardening_bcrypt_auth.sql), which verifies the password with
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

  /// Deletes this customer's profile from the `customers` table (best
  /// effort - a Supabase hiccup shouldn't block the local part, same
  /// philosophy as [_saveNewCustomer]) and clears the local session exactly
  /// like [logout].
  ///
  /// Order records are intentionally kept, keyed by phone number rather
  /// than deleted alongside the profile - retaining transaction history for
  /// accounting/dispute-resolution purposes is standard practice for a paid
  /// service and is disclosed in the privacy policy.
  Future<void> deleteAccount() async {
    final phone = _customerPhone;
    if (phone.isNotEmpty) {
      try {
        await supabase.from('customers').delete().eq('id', phone);
      } catch (error) {
        debugPrint('Could not delete customer record: $error');
      }
    }
    await logout();
  }

  Future<void> logout() async {
    _role = AppRole.none;
    _customerName = '';
    _customerPhone = '';
    _customerAddress = '';
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
    await prefs.remove(_shopOwnerIdKey);
    await prefs.remove(_shopOwnerNameKey);
    await prefs.remove(_shopNameKey);
    await prefs.remove(_adminIdKey);
    await prefs.remove(_adminUsernameKey);
    notifyListeners();
  }
}
