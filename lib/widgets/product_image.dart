import 'package:flutter/material.dart';

import '../models/product.dart';

/// Renders a [Product]'s photo: an admin-picked [Product.imageBytes]
/// override takes priority over the bundled [Product.imagePath] asset.
/// Falls back to a placeholder icon if neither resolves.
class ProductImage extends StatelessWidget {
  final Product product;
  final BoxFit fit;

  const ProductImage({
    super.key,
    required this.product,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = product.imageBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
      );
    }
    if (product.imagePath.isNotEmpty) {
      final path = product.imagePath;
      return path.startsWith('http')
          ? Image.network(
              path,
              fit: fit,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(context),
            )
          : Image.asset(
              path,
              fit: fit,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(context),
            );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
