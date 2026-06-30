import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';
import '../../state/business_settings_provider.dart';
import '../../state/theme_provider.dart';
import '../../utils/image_picker_helper.dart';
import '../../widgets/responsive_center.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load image: $error')));
      }
      return;
    }
    if (bytes == null) return;

    setState(() => _isUploadingQr = true);
    try {
      await business.uploadQr(bytes);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload QR code: $error')),
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
    final isHeadAdmin = context.watch<AuthProvider>().role == AppRole.headAdmin;

    return ResponsiveCenter(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isHeadAdmin) ...[
            Text(
              'UPI & Payment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
          ],
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save UPI ID: $error')),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save business info: $error')),
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
