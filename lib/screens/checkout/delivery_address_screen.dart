import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';
import '../../state/business_settings_provider.dart';
import '../../utils/delivery_fee.dart';
import '../../widgets/address_form_fields.dart';
import 'order_summary_screen.dart';

class DeliveryAddressScreen extends StatefulWidget {
  const DeliveryAddressScreen({super.key});

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _address = AddressFieldControllers();
  bool _addingNew = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  /// The pincode actually being delivered to - from the form's own field
  /// while adding/editing an address, or extracted from the composed
  /// saved-address string (AddressFieldControllers.compose() always ends
  /// it with "- NNNNNN") when reusing a saved one.
  String _pincodeFor(AuthProvider auth, bool needsForm) {
    if (needsForm) return _address.pincode.text.trim();
    final match = RegExp(r'-\s*(\d{6})\s*$').firstMatch(auth.customerAddress);
    return match?.group(1) ?? '';
  }

  Future<void> _continue(AuthProvider auth) async {
    final needsForm = _addingNew || auth.customerAddress.trim().isEmpty;
    if (needsForm && !_formKey.currentState!.validate()) return;

    final business = context.read<BusinessSettingsProvider>();
    final pincode = _pincodeFor(auth, needsForm);
    if (!isPincodeServiceable(pincode, business.settingsSnapshot)) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Not deliverable here'),
          content: Text(
            'Sorry, we don\'t currently deliver to $pincode. '
            'Please try a different address.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (needsForm) {
      setState(() => _isSaving = true);
      await auth.updateCustomerAddress(_address.compose());
      if (mounted) setState(() => _isSaving = false);
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OrderSummaryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasSaved = auth.customerAddress.trim().isNotEmpty;
    final showForm = _addingNew || !hasSaved;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Address')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deliver to',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            hasSaved
                                ? 'Choose a saved address or add a new one'
                                : 'Add your delivery address',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Saved address card ───────────────────────────────────
                if (hasSaved) ...[
                  _SavedAddressCard(
                    address: auth.customerAddress,
                    selected: !_addingNew,
                    onTap: () => setState(() => _addingNew = false),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Add new address toggle ───────────────────────────────
                if (hasSaved && !_addingNew)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _addingNew = true),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add New Address'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: colorScheme.primary),
                    ),
                  ),

                // ── New address form ─────────────────────────────────────
                if (showForm) ...[
                  if (hasSaved) ...[
                    const SizedBox(height: 4),
                    Divider(color: colorScheme.outlineVariant),
                    const SizedBox(height: 4),
                    Text(
                      'New Address',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Form(
                    key: _formKey,
                    child: AddressFormFields(controllers: _address),
                  ),
                ],
              ],
            ),
          ),

          // ── Bottom CTA ────────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _isSaving ? null : () => _continue(auth),
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save & Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedAddressCard extends StatelessWidget {
  final String address;
  final bool selected;
  final VoidCallback onTap;

  const _SavedAddressCard({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  IconData _labelIcon(String address) {
    final lower = address.toLowerCase();
    if (lower.startsWith('[work]')) return Icons.work_outline;
    if (lower.startsWith('[other]')) return Icons.location_on_outlined;
    return Icons.home_outlined;
  }

  String _labelText(String address) {
    final match = RegExp(r'^\[(\w+)\]').firstMatch(address);
    return match?.group(1) ?? 'Home';
  }

  String _cleanAddress(String address) =>
      address.replaceFirst(RegExp(r'^\[\w+\]\s*'), '');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.25)
              : colorScheme.surface,
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _labelIcon(address),
                size: 18,
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelText(address),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cleanAddress(address),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
