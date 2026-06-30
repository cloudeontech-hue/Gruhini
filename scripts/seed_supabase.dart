// One-time migration: uploads the bundled product photos to Supabase
// Storage and inserts the existing seed products/customers/orders into the
// tables created by scripts/supabase_schema.sql.
//
// Run once with: dart run scripts/seed_supabase.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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
  await client.from('shop_owners').upsert({
    'id': defaultShopOwnerId,
    'username': 'gruhini',
    'password_hash': sha256.convert(utf8.encode('shop123')).toString(),
    'shop_name': 'Gruhini Foods',
  });

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
