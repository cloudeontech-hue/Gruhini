import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

const _bucket = 'business-assets';

/// Uploads the head admin's UPI QR code image to Supabase Storage and
/// returns its public URL, for storing as [BusinessSettings.upiQrUrl]. The
/// path is fixed (there's only ever one QR code), so a cache-busting query
/// param is appended to the URL - otherwise widgets/CDNs that cached the
/// previous image at the same path would keep showing it after a re-upload.
Future<String> uploadBusinessQr(Uint8List bytes) async {
  const path = 'upi_qr.jpg';
  await supabase.storage
      .from(_bucket)
      .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
  final url = supabase.storage.from(_bucket).getPublicUrl(path);
  return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
}
