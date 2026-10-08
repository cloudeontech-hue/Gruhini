import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../state/business_settings_provider.dart';
import '../state/cart_provider.dart';
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
  bool _isDeletingAccount = false;

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

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This permanently deletes your saved profile (name, phone, '
          'address) from our records. Your past order history is kept for '
          'accounting purposes, as described in our Privacy Policy, but is '
          'no longer linked to an active account.\n\n'
          'This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    setState(() => _isDeletingAccount = true);
    try {
      await context.read<AuthProvider>().deleteAccount();
    } finally {
      // AuthGate normally tears this screen down the moment deleteAccount()
      // sets role back to none - this only resets the spinner if that
      // hasn't happened by the time we get here.
      if (mounted) setState(() => _isDeletingAccount = false);
    }
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
    final supportPhone = context.watch<BusinessSettingsProvider>().supportPhone;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Swiggy-style header: name and phone left-aligned and large,
              // avatar pushed to the right - no centered avatar/chip stack.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.customerName.isNotEmpty
                                ? auth.customerName
                                : 'Guest',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            auth.customerPhone.isNotEmpty
                                ? '+91 ${auth.customerPhone}'
                                : 'Phone not set',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.goldLight,
                      foregroundColor: AppColors.brand,
                      child: Text(
                        auth.customerName.isNotEmpty
                            ? auth.customerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              _SectionHeader(label: 'My account'),
              _ProfileRow(
                icon: Icons.location_on_outlined,
                label: 'Delivery address',
                // Swiggy shows the current value inline under the label
                // rather than hiding it behind the row.
                value: auth.customerAddress.isNotEmpty
                    ? _cleanAddress(auth.customerAddress)
                    : 'Not set',
                onTap: () => _openAddressEditor(context),
              ),
              _ProfileRow(
                icon: Icons.payment_outlined,
                label: 'Payment methods',
                onTap: () => _showInfoDialog(
                  context,
                  'Payment Methods',
                  'Orders are paid online via UPI, card, or net banking through Razorpay, or by scanning a QR code where online payment isn\'t available. All orders are prepaid - we do not offer Cash on Delivery.',
                ),
              ),

              _SectionHeader(label: 'Preferences'),
              SwitchListTile(
                secondary: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode
                      : Icons.dark_mode_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: const Text('Dark mode'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                value: themeProvider.isDarkMode,
                onChanged: (value) => themeProvider.setDarkMode(value),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),

              _SectionHeader(label: 'Other information'),
              _ProfileRow(
                icon: Icons.help_outline,
                label: 'Help & support',
                onTap: () => _showInfoDialog(
                  context,
                  'Help & Support',
                  supportPhone.isNotEmpty
                      ? 'Need help with an order? Call us at $supportPhone.'
                      : 'Support contact details are not configured yet.',
                ),
              ),
              _ProfileRow(
                icon: Icons.info_outline,
                label: 'About Gruhini Foods',
                onTap: () => _showInfoDialog(
                  context,
                  'About Gruhini Foods',
                  'Gruhini Foods connects you with homemade snacks, sweets and pickles from local home kitchens. App version 1.0.0.',
                ),
              ),

              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.brand,
                    side: const BorderSide(color: AppColors.brand),
                  ),
                  onPressed: () {
                    // Clear the cart on logout - it's now persisted (see
                    // CartProvider), so without this a different customer
                    // logging into the same device would inherit whatever
                    // was left in it.
                    context.read<CartProvider>().clear();
                    auth.logout();
                  },
                  child: const Text('Log out'),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: _isDeletingAccount
                      ? null
                      : () => _confirmDeleteAccount(context),
                  child: _isDeletingAccount
                      ? const Text('Deleting...')
                      : Text(
                          'Delete account',
                          style: TextStyle(color: colorScheme.error),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Gruhini Foods  •  v1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _cleanAddress(String address) =>
      address.replaceFirst(RegExp(r'^\[\w+\]\s*'), '');
}

/// Small muted group label above each block of rows - the device Swiggy
/// uses to break a long settings list into scannable sections instead of
/// boxing each group in its own card.
class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// One tappable settings row: icon, label, optional current value beneath
/// it, and a chevron. Flat with a hairline divider rather than a card, so
/// consecutive rows read as a single grouped list.
class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _ProfileRow({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(icon, color: colorScheme.onSurfaceVariant),
          title: Text(label),
          subtitle: value == null
              ? null
              : Text(
                  value!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Icon(
            Icons.chevron_right,
            color: colorScheme.onSurfaceVariant,
          ),
          onTap: onTap,
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
      ],
    );
  }
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
