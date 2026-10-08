/// Maps the single shared `business_settings` row — see
/// supabase/migrations/20260701163100_payments_and_business_settings.sql and [BusinessSettingsProvider].
class BusinessSettings {
  final String businessName;
  final String supportPhone;
  final String upiId;
  final String upiQrUrl;

  /// Flat fee added on top of the cart subtotal - see
  /// supabase/migrations/20260915113600_delivery_fee_and_pincodes.sql. 0 means free delivery.
  final double deliveryFee;

  /// Cart subtotal above which [deliveryFee] is waived, or null to never
  /// waive it regardless of order size.
  final double? freeDeliveryAbove;

  /// Pincodes the business actually delivers to. An empty list means
  /// "everywhere" - no serviceability check is applied at checkout until
  /// this is populated.
  final List<String> serviceablePincodes;

  const BusinessSettings({
    required this.businessName,
    required this.supportPhone,
    required this.upiId,
    required this.upiQrUrl,
    this.deliveryFee = 0,
    this.freeDeliveryAbove,
    this.serviceablePincodes = const [],
  });

  factory BusinessSettings.fromMap(Map<String, dynamic> map) =>
      BusinessSettings(
        businessName: map['business_name'] as String? ?? 'Gruhini Foods',
        supportPhone: map['support_phone'] as String? ?? '',
        upiId: map['upi_id'] as String? ?? '',
        upiQrUrl: map['upi_qr_url'] as String? ?? '',
        deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0,
        freeDeliveryAbove: (map['free_delivery_above'] as num?)?.toDouble(),
        serviceablePincodes:
            (map['serviceable_pincodes'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
      );
}
