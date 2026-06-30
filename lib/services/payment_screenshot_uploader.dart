import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

const _bucket = 'payment-screenshots';

/// Uploads a customer-picked payment screenshot to Supabase Storage and
/// returns its public URL, for storing as [Order.paymentScreenshotUrl].
/// [batchId] identifies the checkout attempt (not a single order id, since
/// one checkout can split into several [Order] rows - see
/// [OrdersProvider.placeOrder] - that all share the same screenshot).
Future<String> uploadPaymentScreenshot(String batchId, Uint8List bytes) async {
  final path = '$batchId.jpg';
  await supabase.storage
      .from(_bucket)
      .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
  return supabase.storage.from(_bucket).getPublicUrl(path);
}
