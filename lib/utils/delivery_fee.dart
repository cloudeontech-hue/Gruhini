import '../models/business_settings.dart';

/// The single source of truth for what delivery costs on a given cart -
/// used identically by the cart/order-summary display, the actual
/// Razorpay charge, and its amount-verification check. Computing this in
/// three different places (as the pre-delivery-fee code effectively did,
/// since it just hardcoded "Free" everywhere) is exactly how a display
/// value and a charged value drift apart.
double calculateDeliveryFee(double cartSubtotal, BusinessSettings settings) {
  final freeAbove = settings.freeDeliveryAbove;
  if (freeAbove != null && cartSubtotal >= freeAbove) return 0;
  return settings.deliveryFee;
}

/// True if [pincode] is deliverable. An empty [BusinessSettings.
/// serviceablePincodes] list means no restriction has been configured yet -
/// deliver everywhere, matching this app's behavior before serviceability
/// existed at all.
bool isPincodeServiceable(String pincode, BusinessSettings settings) {
  if (settings.serviceablePincodes.isEmpty) return true;
  return settings.serviceablePincodes.contains(pincode.trim());
}
