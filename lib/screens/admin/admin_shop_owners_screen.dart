import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/shop_owners_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/responsive_center.dart';

class AdminShopOwnersScreen extends StatelessWidget {
  const AdminShopOwnersScreen({super.key});

  void _openAddDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _AddShopOwnerDialog());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShopOwnersProvider>();
    if (!provider.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final shopOwners = provider.shopOwners;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddDialog(context),
        child: const Icon(Icons.add),
      ),
      body: shopOwners.isEmpty
          ? const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No shop owners yet',
              subtitle: 'Tap the + button to add your first shop owner.',
            )
          : ResponsiveCenter(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: shopOwners.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final shopOwner = shopOwners[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.goldLight,
                        foregroundColor: AppColors.brand,
                        child: Icon(Icons.storefront_outlined),
                      ),
                      title: Text(shopOwner.shopName),
                      subtitle: Text('Username: ${shopOwner.username}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove',
                        onPressed: () => context
                            .read<ShopOwnersProvider>()
                            .deleteShopOwner(shopOwner.id),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _AddShopOwnerDialog extends StatefulWidget {
  const _AddShopOwnerDialog();

  @override
  State<_AddShopOwnerDialog> createState() => _AddShopOwnerDialogState();
}

class _AddShopOwnerDialogState extends State<_AddShopOwnerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await context.read<ShopOwnersProvider>().addShopOwner(
        shopName: _shopNameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Could not add shop owner: $error');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not add this shop owner. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Shop Owner'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _shopNameController,
              decoration: const InputDecoration(labelText: 'Shop Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
