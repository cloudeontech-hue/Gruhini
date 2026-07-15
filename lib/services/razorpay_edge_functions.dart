import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Thrown by [createRazorpayOrder]/[verifyRazorpayPayment] with a
/// user-facing [message] — callers don't need to know about
/// [FunctionException] or its `details` shape.
class RazorpayEdgeFunctionException implements Exception {
  final String message;
  RazorpayEdgeFunctionException(this.message);
  @override
  String toString() => message;
}

String? _extractErrorMessage(FunctionException e) {
  final details = e.details;
  return details is Map ? details['error'] as String? : null;
}

/// Calls the `create-razorpay-order` Edge Function (see
/// supabase/functions/create-razorpay-order/index.ts) and returns its
/// decoded `{orderId, amount, currency}` response. Shared by both
/// lib/services/razorpay_service.dart (Android/iOS) and
/// lib/services/razorpay_web_service.dart (Web/Windows) — see
/// scripts/MIGRATION_RAZORPAY.md for the deployment this depends on.
Future<Map<String, dynamic>> createRazorpayOrder({
  required double amount,
}) async {
  try {
    final res = await supabase.functions.invoke(
      'create-razorpay-order',
      body: {
        'amount': amount,
        'receipt': 'rcpt_${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    return res.data as Map<String, dynamic>;
  } on FunctionException catch (e) {
    throw RazorpayEdgeFunctionException(
      _extractErrorMessage(e) ?? 'Could not start payment.',
    );
  }
}

/// Calls the `verify-razorpay-payment` Edge Function (see
/// supabase/functions/verify-razorpay-payment/index.ts) and returns its
/// decoded `{verified, amount, currency}` response on a 2xx reply. The
/// function itself returns a non-2xx status (caught here as
/// [RazorpayEdgeFunctionException]) for every failure mode, including a
/// signature mismatch - a 2xx response is always `verified: true` per its
/// contract, but callers should still check the field defensively rather
/// than assume it.
Future<Map<String, dynamic>> verifyRazorpayPayment({
  required String orderId,
  required String paymentId,
  required String signature,
}) async {
  try {
    final res = await supabase.functions.invoke(
      'verify-razorpay-payment',
      body: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      },
    );
    return res.data as Map<String, dynamic>;
  } on FunctionException catch (e) {
    throw RazorpayEdgeFunctionException(
      _extractErrorMessage(e) ?? 'Payment could not be verified.',
    );
  }
}
