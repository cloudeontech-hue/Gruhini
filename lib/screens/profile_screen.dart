import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../state/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editField({
    required BuildContext context,
    required String title,
    required String label,
    required String initialValue,
    required ValueChanged<String> onSave,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: label == 'Address' ? 3 : 1,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              child: Text(
                auth.customerName.isNotEmpty ? auth.customerName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(auth.customerName, style: Theme.of(context).textTheme.titleLarge),
          ),
          const Center(child: Chip(label: Text('Customer'))),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Phone'),
                  subtitle: Text(
                    auth.customerPhone.isNotEmpty ? auth.customerPhone : 'Not set',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit phone',
                    onPressed: () => _editField(
                      context: context,
                      title: 'Edit Phone Number',
                      label: 'Phone Number',
                      initialValue: auth.customerPhone,
                      keyboardType: TextInputType.phone,
                      onSave: (value) => auth.updateCustomerPhone(value),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Address'),
                  subtitle: Text(
                    auth.customerAddress.isNotEmpty ? auth.customerAddress : 'Not set',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit address',
                    onPressed: () => _editField(
                      context: context,
                      title: 'Edit Address',
                      label: 'Address',
                      initialValue: auth.customerAddress,
                      onSave: (value) => auth.updateCustomerAddress(value),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(
                    themeProvider.isDarkMode ? Icons.dark_mode : Icons.dark_mode_outlined,
                  ),
                  title: const Text('Dark Mode'),
                  value: themeProvider.isDarkMode,
                  onChanged: (value) => themeProvider.setDarkMode(value),
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
    );
  }
}
