import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../state/auth_provider.dart';
import '../../state/products_provider.dart';
import '../../widgets/product_image_picker.dart';

/// Full-screen Add/Edit product form for the shop owner mobile flow - the
/// only place products can be added or edited (the head admin's
/// AdminProductsScreen is view/toggle-stock/delete only).
class ShopOwnerProductFormScreen extends StatefulWidget {
  final Product? product;

  const ShopOwnerProductFormScreen({super.key, this.product});

  @override
  State<ShopOwnerProductFormScreen> createState() =>
      _ShopOwnerProductFormScreenState();
}

class _ShopOwnerProductFormScreenState
    extends State<ShopOwnerProductFormScreen> {
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
  bool _isSubmitting = false;

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

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Product' : 'Add Product')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProductImagePicker(
                imageBytes: _imageBytes,
                imagePath: _imagePath,
                onImagePicked: (bytes) => setState(() => _imageBytes = bytes),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price (₹)'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*$'),
                        ),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Weight (e.g. 250g)',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Update Product' : 'Save Product'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
