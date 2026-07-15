// One-time migration: uploads the bundled product photos to Supabase
// Storage and inserts the existing seed products/customers/orders into the
// tables created by scripts/supabase_schema.sql.
//
// Run AFTER scripts/supabase_schema_security.sql has been applied, so the
// create_shop_owner() RPC (which bcrypt-hashes the password server-side) is
// available.
//
// Run once with: dart run scripts/seed_supabase.dart
//
// ignore_for_file: avoid_print - this is a console-run CLI script; print()
// is the intended progress output, not leftover debug logging.
import 'dart:io';

import 'package:gruiny_foods/data/customers_data.dart';
import 'package:gruiny_foods/data/orders_data.dart';
import 'package:gruiny_foods/data/products_data.dart';
import 'package:supabase/supabase.dart';

Map<String, String> _loadEnv(String path) {
  final env = <String, String>{};
  for (final line in File(path).readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final index = trimmed.indexOf('=');
    if (index == -1) continue;
    env[trimmed.substring(0, index)] = trimmed.substring(index + 1);
  }
  return env;
}

Future<void> main() async {
  final env = _loadEnv('.env');
  final client = SupabaseClient(
    env['SUPABASE_URL']!,
    env['SUPABASE_ANON_KEY']!,
  );

  print('Seeding default shop owner (login: gruhini / shop123)...');
  // create_shop_owner() hashes the password with bcrypt server-side.
  // If the shop owner already exists this will throw a unique-constraint error
  // which is safe to ignore (upsert semantics not available on RPCs — the
  // supabase_schema_security.sql migration already re-hashes the gruhini row).
  try {
    await client.rpc('create_shop_owner', params: {
      'p_id': defaultShopOwnerId,
      'p_username': 'gruhini',
      'p_password': 'shop123',
      'p_shop_name': 'Gruhini Foods',
    });
  } catch (_) {
    // Row already exists — skip.
  }

  print('Uploading product images and seeding products...');
  for (final product in productsData) {
    final imageFile = File(product.imagePath);
    final bytes = await imageFile.readAsBytes();
    final storagePath = '${product.id}.jpg';
    await client.storage
        .from('product-images')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    final imageUrl = client.storage
        .from('product-images')
        .getPublicUrl(storagePath);

    await client.from('products').upsert({
      ...product.toMap(),
      'image_path': imageUrl,
    });
    print('  ${product.name} -> $imageUrl');
  }

  print('Seeding customers...');
  for (final customer in customersData) {
    await client.from('customers').upsert(customer.toMap());
  }

  print('Seeding orders...');
  for (final order in ordersData) {
    await client.from('orders').upsert(order.toMap());
  }

  print('Done.');
}
