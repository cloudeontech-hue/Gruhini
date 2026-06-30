/// Maps the single shared `business_settings` row — see
/// scripts/supabase_schema_payments.sql and [BusinessSettingsProvider].
class BusinessSettings {
  final String businessName;
  final String supportPhone;
  final String upiId;
  final String upiQrUrl;

  const BusinessSettings({
    required this.businessName,
    required this.supportPhone,
    required this.upiId,
    required this.upiQrUrl,
  });

  factory BusinessSettings.fromMap(Map<String, dynamic> map) =>
      BusinessSettings(
        businessName: map['business_name'] as String? ?? 'Gruhini Foods',
        supportPhone: map['support_phone'] as String? ?? '',
        upiId: map['upi_id'] as String? ?? '',
        upiQrUrl: map['upi_qr_url'] as String? ?? '',
      );
}
