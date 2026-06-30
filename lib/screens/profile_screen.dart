import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../state/theme_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/address_form_fields.dart';
import '../widgets/responsive_center.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;

  Future<void> _showInfoDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openAddressEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AddressEditScreen(
          currentAddress: context.read<AuthProvider>().customerAddress,
          onSave: (newAddress) =>
              context.read<AuthProvider>().updateCustomerAddress(newAddress),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.goldLight,
                foregroundColor: AppColors.brand,
                child: Text(
                  auth.customerName.isNotEmpty
                      ? auth.customerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                auth.customerName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Center(child: Chip(label: Text('Customer'))),
            const SizedBox(height: 24),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Phone'),
                    subtitle: Text(
                      auth.customerPhone.isNotEmpty
                          ? auth.customerPhone
                          : 'Not set',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Address'),
                    subtitle: Text(
                      auth.customerAddress.isNotEmpty
                          ? _cleanAddress(auth.customerAddress)
                          : 'Not set',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openAddressEditor(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.location_city_outlined),
                    title: const Text('My Addresses'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openAddressEditor(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.payment_outlined),
                    title: const Text('Payment Methods'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showInfoDialog(
                      context,
                      'Payment Methods',
                      'All orders are paid via UPI. No other payment methods are currently supported.',
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(
                      themeProvider.isDarkMode
                          ? Icons.dark_mode
                          : Icons.dark_mode_outlined,
                    ),
                    title: const Text('Dark Mode'),
                    value: themeProvider.isDarkMode,
                    onChanged: (value) => themeProvider.setDarkMode(value),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    value: _notificationsEnabled,
                    onChanged: (value) =>
                        setState(() => _notificationsEnabled = value),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help & Support'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showInfoDialog(
                      context,
                      'Help & Support',
                      'Need help with an order? Reach us at support@gruhinifoods.com or call +91 98765 43210.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About Gruhini Foods'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showInfoDialog(
                      context,
                      'About Gruhini Foods',
                      'Gruhini Foods connects you with homemade snacks, sweets and pickles from local home kitchens. App version 1.0.0.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => auth.logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  String _cleanAddress(String address) =>
      address.replaceFirst(RegExp(r'^\[\w+\]\s*'), '');
}

// ── Address Edit Screen ────────────────────────────────────────────────────────

class _AddressEditScreen extends StatefulWidget {
  final String currentAddress;
  final ValueChanged<String> onSave;

  const _AddressEditScreen({
    required this.currentAddress,
    required this.onSave,
  });

  @override
  State<_AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends State<_AddressEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = AddressFieldControllers();
  bool _isSaving = false;

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await Future.microtask(() => widget.onSave(_controllers.compose()));
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address saved successfully.')),
      );
    }
  }

  String _labelText(String address) {
    final match = RegExp(r'^\[(\w+)\]').firstMatch(address);
    return match?.group(1) ?? 'Home';
  }

  IconData _labelIcon(String label) {
    if (label == 'Work') return Icons.work_outline;
    if (label == 'Other') return Icons.location_on_outlined;
    return Icons.home_outlined;
  }

  String _cleanAddress(String address) =>
      address.replaceFirst(RegExp(r'^\[\w+\]\s*'), '');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSaved = widget.currentAddress.trim().isNotEmpty;
    final savedLabel = _labelText(widget.currentAddress);

    return Scaffold(
      appBar: AppBar(title: const Text('My Addresses')),
      body: Column(
        children: [
          Expanded(
            child: ResponsiveCenter(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Saved address card ─────────────────────────────────
                  if (hasSaved) ...[
                    Text(
                      'Saved Address',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _labelIcon(savedLabel),
                              size: 18,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  savedLabel,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _cleanAddress(widget.currentAddress),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Divider(color: colorScheme.outlineVariant),
                    const SizedBox(height: 16),
                  ],

                  // ── New / edit address form ────────────────────────────
                  Row(
                    children: [
                      Icon(
                        Icons.add_location_alt_outlined,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasSaved ? 'Change Address' : 'Add Address',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: AddressFormFields(controllers: _controllers),
                  ),
                ],
              ),
            ),
          ),

          // ── Save button ───────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ResponsiveCenter(
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(hasSaved ? 'Update Address' : 'Save Address'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
