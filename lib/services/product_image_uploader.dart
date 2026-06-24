import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

const _bucket = 'product-images';

/// Uploads an admin-picked product photo to Supabase Storage and returns
/// its public URL, for storing as [Product.imagePath].
Future<String> uploadProductImage(String productId, Uint8List bytes) async {
  final path = '$productId.jpg';
  await supabase.storage.from(_bucket).uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
  return supabase.storage.from(_bucket).getPublicUrl(path);
}
