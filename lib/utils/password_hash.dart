import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Client-side hash used so shop owner passwords are never sent or stored
/// in plain text. Not a substitute for proper salted hashing (e.g. bcrypt)
/// done server-side — adequate for this app's current threat model only.
String hashPassword(String password) => sha256.convert(utf8.encode(password)).toString();
