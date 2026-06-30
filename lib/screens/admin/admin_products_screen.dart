import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../state/auth_provider.dart';
import '../../state/products_provider.dart';
import '../../state/shop_owners_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_image.dart';
import '../../widgets/product_image_picker.dart';
import '../../widgets/responsive_center.dart';

class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  void _openProductForm(BuildContext context, {Product? product}) {
    showDialog(
      context: context,
      builder: (_) => _ProductFormDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsProvider = context.watch<ProductsProvider>();
    final shopOwnersProvider = context.watch<ShopOwnersProvider>();
    final auth = context.watch<AuthProvider>();
    if (!productsProvider.isLoaded || !shopOwnersProvider.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isHeadAdmin = auth.role == AppRole.headAdmin;
    final products = isHeadAdmin
        ? productsProvider.products
        : productsProvider.products
              .where((p) => p.shopOwnerId == auth.shopOwnerId)
              .toList();

    return Scaffold(
      floatingActionButton: isHeadAdmin
          ? null
          : FloatingActionButton(
              onPressed: () => _openProductForm(context),
              child: const Icon(Icons.add),
            ),
      body: products.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products yet',
              subtitle: 'Products added by shop owners will appear here.',
            )
          : ResponsiveCenter(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: ProductImage(product: product),
                        ),
                      ),
                      title: Text(product.name),
                      subtitle: Text(
                        isHeadAdmin
                            ? '${shopOwnersProvider.shopNameFor(product.shopOwnerId)} · '
                                  '${formatPrice(product.price)} · ${product.unit}\n'
                                  '${product.inStock ? "In Stock" : "Out of Stock"}'
                            : '${product.category.label} · ${formatPrice(product.price)} · ${product.unit}\n'
                                  '${product.inStock ? "In Stock" : "Out of Stock"}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isHeadAdmin)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit',
                              onPressed: () =>
                                  _openProductForm(context, product: product),
                            ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              final provider = context.read<ProductsProvider>();
                              switch (value) {
                                case 'stock':
                                  provider.toggleStock(product.id);
                                  break;
                                case 'delete':
                                  provider.deleteProduct(product.id);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'stock',
                                child: Text(
                                  product.inStock
                                      ? 'Mark Out of Stock'
                                      : 'Mark In Stock',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  final Product? product;

  const _ProductFormDialog({this.product});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.product?.name,
  );
  late final _priceController = TextEditingController(
    text: widget.product?.price.toStringAsFixed(0),
  );
  late final _unitController = TextEditingController(
    text: widget.product?.unit,
  );
  late final _descriptionController = TextEditingController(
    text: widget.product?.description,
  );
  late ProductCategory _category =
      widget.product?.category ?? ProductCategory.snacks;
  late final String _imagePath = widget.product?.imagePath ?? '';
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.product?.imageBytes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProductsProvider>();
    final name = _nameController.text.trim();
    final price = double.parse(_priceController.text.trim());
    final unit = _unitController.text.trim();
    final description = _descriptionController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      if (widget.product == null) {
        await provider.addProduct(
          name: name,
          category: _category,
          price: price,
          unit: unit,
          imagePath: _imagePath,
          description: description,
          shopOwnerId: context.read<AuthProvider>().shopOwnerId,
          imageBytes: _imageBytes,
        );
      } else {
        await provider.updateProduct(
          widget.product!.id,
          name: name,
          category: _category,
          price: price,
          unit: unit,
          imagePath: _imagePath,
          description: description,
          imageBytes: _imageBytes,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save product: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Product' : 'Add Product'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ProductImagePicker(
                imageBytes: _imageBytes,
                imagePath: _imagePath,
                onImagePicked: (bytes) => setState(() => _imageBytes = bytes),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ProductCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ProductCategory.values
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price (₹)'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit (e.g. 250g pack)',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                ),
                maxLines: 3,
              ),
            ],
          ),
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
              : Text(isEditing ? 'Update Product' : 'Add Product'),
        ),
      ],
    );
  }
}
