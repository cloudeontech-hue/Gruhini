import 'package:flutter/foundation.dart';

import '../models/business_settings.dart';
import '../services/business_asset_uploader.dart';
import '../services/supabase_client.dart';

const _rowId = 'default';

/// Holds the single shared `business_settings` row (UPI ID/QR, business
/// name, support phone) that the UPI payment screen and admin settings
/// screen both read from — see supabase/migrations/20260701163100_payments_and_business_settings.sql.
class BusinessSettingsProvider extends ChangeNotifier {
  BusinessSettings _settings = const BusinessSettings(
    businessName: 'Gruhini Foods',
    supportPhone: '',
    upiId: '',
    upiQrUrl: '',
  );
  bool _isLoaded = false;

  String get businessName => _settings.businessName;
  String get supportPhone => _settings.supportPhone;
  String get upiId => _settings.upiId;
  String get upiQrUrl => _settings.upiQrUrl;
  double get deliveryFee => _settings.deliveryFee;
  double? get freeDeliveryAbove => _settings.freeDeliveryAbove;
  List<String> get serviceablePincodes => _settings.serviceablePincodes;
  bool get isLoaded => _isLoaded;

  /// The full settings row, for callers of [calculateDeliveryFee] /
  /// [isPincodeServiceable] (lib/utils/delivery_fee.dart) that need more
  /// than one field at once rather than reading each getter separately.
  BusinessSettings get settingsSnapshot => _settings;

  Future<void> load() async {
    try {
      final row = await supabase
          .from('business_settings')
          .select()
          .eq('id', _rowId)
          .maybeSingle();
      if (row != null) _settings = BusinessSettings.fromMap(row);
    } catch (error) {
      // Don't leave isLoaded stuck false on a backend hiccup - that would
      // freeze every screen that gates on this provider (e.g. the UPI
      // payment screen) in a permanent loading spinner.
      debugPrint('Could not load business settings: $error');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateDetails({
    required String businessName,
    required String supportPhone,
    required String upiId,
  }) async {
    _settings = BusinessSettings(
      businessName: businessName,
      supportPhone: supportPhone,
      upiId: upiId,
      upiQrUrl: _settings.upiQrUrl,
      deliveryFee: _settings.deliveryFee,
      freeDeliveryAbove: _settings.freeDeliveryAbove,
      serviceablePincodes: _settings.serviceablePincodes,
    );
    await supabase
        .from('business_settings')
        .update({
          'business_name': businessName,
          'support_phone': supportPhone,
          'upi_id': upiId,
        })
        .eq('id', _rowId);
    notifyListeners();
  }

  /// [pincodes] should already be trimmed/deduplicated by the caller (the
  /// admin settings UI) - stored as-is.
  Future<void> updateDeliverySettings({
    required double deliveryFee,
    double? freeDeliveryAbove,
    required List<String> pincodes,
  }) async {
    _settings = BusinessSettings(
      businessName: _settings.businessName,
      supportPhone: _settings.supportPhone,
      upiId: _settings.upiId,
      upiQrUrl: _settings.upiQrUrl,
      deliveryFee: deliveryFee,
      freeDeliveryAbove: freeDeliveryAbove,
      serviceablePincodes: pincodes,
    );
    await supabase
        .from('business_settings')
        .update({
          'delivery_fee': deliveryFee,
          'free_delivery_above': freeDeliveryAbove,
          'serviceable_pincodes': pincodes,
        })
        .eq('id', _rowId);
    notifyListeners();
  }

  Future<void> uploadQr(Uint8List bytes) async {
    final url = await uploadBusinessQr(bytes);
    _settings = BusinessSettings(
      businessName: _settings.businessName,
      supportPhone: _settings.supportPhone,
      upiId: _settings.upiId,
      upiQrUrl: url,
      deliveryFee: _settings.deliveryFee,
      freeDeliveryAbove: _settings.freeDeliveryAbove,
      serviceablePincodes: _settings.serviceablePincodes,
    );
    await supabase
        .from('business_settings')
        .update({'upi_qr_url': url})
        .eq('id', _rowId);
    notifyListeners();
  }

  Future<void> removeQr() async {
    _settings = BusinessSettings(
      businessName: _settings.businessName,
      supportPhone: _settings.supportPhone,
      upiId: _settings.upiId,
      upiQrUrl: '',
      deliveryFee: _settings.deliveryFee,
      freeDeliveryAbove: _settings.freeDeliveryAbove,
      serviceablePincodes: _settings.serviceablePincodes,
    );
    await supabase
        .from('business_settings')
        .update({'upi_qr_url': ''})
        .eq('id', _rowId);
    notifyListeners();
  }
}
