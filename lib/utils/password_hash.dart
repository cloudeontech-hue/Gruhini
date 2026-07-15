import 'dart:convert';

import 'package:crypto/crypto.dart';

/// SHA-256 hash for device-local customer password storage only.
/// Passwords for admins and shop owners are never hashed client-side — they
/// are sent as plain text to security-definer Supabase RPCs that use bcrypt.
String hashPassword(String password) =>
    sha256.convert(utf8.encode(password)).toString();
