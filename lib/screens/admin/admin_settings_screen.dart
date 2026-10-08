import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/business_settings_provider.dart';
import '../../state/theme_provider.dart';
import '../../utils/image_picker_helper.dart';
import '../../widgets/responsive_center.dart';

/// Only ever shown to the head admin - shop owners manage their own profile
/// via the separate ShopOwnerProfileScreen instead, so the UPI/business info
/// sections here are unconditional.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _isUploadingQr = false;

  Future<void> _changeQr(BusinessSettingsProvider business) async {
    Uint8List? bytes;
    try {
      bytes = await pickProductImageBytes();
    } catch (error) {
      debugPrint('Could not load QR image: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load that image. Please try again.')),
        );
      }
      return;
    }
    if (bytes == null) return;

    setState(() => _isUploadingQr = true);
    try {
      await business.uploadQr(bytes);
    } catch (error) {
      debugPrint('Could not upload QR code: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not upload the QR code. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final business = context.watch<BusinessSettingsProvider>();

    return ResponsiveCenter(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('UPI & Payment', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _UpiSettingsCard(
            business: business,
            isUploadingQr: _isUploadingQr,
            onChangeQr: () => _changeQr(business),
            onRemoveQr: () => business.removeQr(),
          ),
          const SizedBox(height: 24),
          Text(
            'Business Info',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _BusinessInfoCard(business: business),
          const SizedBox(height: 24),
          Text(
            'Delivery',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _DeliverySettingsCard(business: business),
          const SizedBox(height: 24),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                themeProvider.isDarkMode
                    ? Icons.dark_mode
                    : Icons.dark_mode_outlined,
              ),
              title: const Text('Dark Mode'),
              value: themeProvider.isDarkMode,
              onChanged: (value) => themeProvider.setDarkMode(value),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'App version 1.0.0',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _UpiSettingsCard extends StatefulWidget {
  final BusinessSettingsProvider business;
  final bool isUploadingQr;
  final VoidCallback onChangeQr;
  final VoidCallback onRemoveQr;

  const _UpiSettingsCard({
    required this.business,
    required this.isUploadingQr,
    required this.onChangeQr,
    required this.onRemoveQr,
  });

  @override
  State<_UpiSettingsCard> createState() => _UpiSettingsCardState();
}

class _UpiSettingsCardState extends State<_UpiSettingsCard> {
  late final _upiIdController = TextEditingController(
    text: widget.business.upiId,
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.business.updateDetails(
        businessName: widget.business.businessName,
        supportPhone: widget.business.supportPhone,
        upiId: _upiIdController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('UPI ID saved.')));
      }
    } catch (error) {
      debugPrint('Could not save UPI ID: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the UPI ID. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upiQrUrl = widget.business.upiQrUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: upiQrUrl.isEmpty
                    ? const Center(
                        child: Text(
                          'No QR uploaded',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          upiQrUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.qr_code_2, size: 64),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: widget.isUploadingQr ? null : widget.onChangeQr,
                    child: widget.isUploadingQr
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Change QR'),
                  ),
                ),
                if (upiQrUrl.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onRemoveQr,
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _upiIdController,
              decoration: const InputDecoration(labelText: 'UPI ID'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save UPI ID'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessInfoCard extends StatefulWidget {
  final BusinessSettingsProvider business;

  const _BusinessInfoCard({required this.business});

  @override
  State<_BusinessInfoCard> createState() => _BusinessInfoCardState();
}

class _BusinessInfoCardState extends State<_BusinessInfoCard> {
  late final _nameController = TextEditingController(
    text: widget.business.businessName,
  );
  late final _phoneController = TextEditingController(
    text: widget.business.supportPhone,
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.business.updateDetails(
        businessName: _nameController.text.trim(),
        supportPhone: _phoneController.text.trim(),
        upiId: widget.business.upiId,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Business info saved.')));
      }
    } catch (error) {
      debugPrint('Could not save business info: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your business info. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Business Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Support Phone'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delivery fee, free-delivery threshold, and the deliverable pincode
/// list - see supabase/migrations/20260915113600_delivery_fee_and_pincodes.sql and
/// lib/utils/delivery_fee.dart for how these are actually applied at
/// checkout.
class _DeliverySettingsCard extends StatefulWidget {
  final BusinessSettingsProvider business;

  const _DeliverySettingsCard({required this.business});

  @override
  State<_DeliverySettingsCard> createState() => _DeliverySettingsCardState();
}

class _DeliverySettingsCardState extends State<_DeliverySettingsCard> {
  late final _feeController = TextEditingController(
    text: widget.business.deliveryFee == 0
        ? ''
        : widget.business.deliveryFee.toStringAsFixed(0),
  );
  late final _freeAboveController = TextEditingController(
    text: widget.business.freeDeliveryAbove?.toStringAsFixed(0) ?? '',
  );
  late final _pincodeController = TextEditingController();
  late final List<String> _pincodes = List.of(
    widget.business.serviceablePincodes,
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _feeController.dispose();
    _freeAboveController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _addPincode() {
    final value = _pincodeController.text.trim();
    if (value.length != 6 || _pincodes.contains(value)) return;
    setState(() {
      _pincodes.add(value);
      _pincodeController.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.business.updateDeliverySettings(
        deliveryFee: double.tryParse(_feeController.text.trim()) ?? 0,
        freeDeliveryAbove: double.tryParse(_freeAboveController.text.trim()),
        pincodes: _pincodes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery settings saved.')),
        );
      }
    } catch (error) {
      debugPrint('Could not save delivery settings: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save delivery settings. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Delivery Fee (₹)',
                helperText: 'Leave blank or 0 for free delivery',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _freeAboveController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Free Delivery Above (₹)',
                helperText:
                    'Optional - waives the fee for carts at or above this amount',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Deliverable Pincodes',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              'Leave empty to deliver everywhere with no restriction.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (_pincodes.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final pincode in _pincodes)
                    Chip(
                      label: Text(pincode),
                      onDeleted: () =>
                          setState(() => _pincodes.remove(pincode)),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Add pincode',
                      counterText: '',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addPincode(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addPincode,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add pincode',
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
