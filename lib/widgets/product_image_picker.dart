import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../utils/image_picker_helper.dart';

/// Tappable circular image preview used on the Add/Edit Product dialog.
/// Shows the current image (picked bytes, falling back to the existing
/// asset path, falling back to a placeholder), with a camera badge
/// overlay. Tapping opens the platform image/file picker and previews the
/// result immediately; the caller decides when to persist it.
class ProductImagePicker extends StatelessWidget {
  final Uint8List? imageBytes;
  final String imagePath;
  final ValueChanged<Uint8List> onImagePicked;

  /// Injectable for testing; defaults to the real platform picker.
  final Future<Uint8List?> Function() pickImage;

  const ProductImagePicker({
    super.key,
    required this.imageBytes,
    required this.imagePath,
    required this.onImagePicked,
    this.pickImage = pickProductImageBytes,
  });

  Future<void> _handleTap(BuildContext context) async {
    try {
      final bytes = await pickImage();
      if (bytes != null) onImagePicked(bytes);
    } catch (error) {
      debugPrint('Could not load image: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load that image. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: colors.surfaceContainerHighest,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _handleTap(context),
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: _buildPreview(context),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _handleTap(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: colors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Click to change', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (imageBytes != null) {
      return Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        width: 110,
        height: 110,
        errorBuilder: (context, error, stackTrace) => _placeholderIcon(context),
      );
    }
    if (imagePath.isNotEmpty) {
      return imagePath.startsWith('http')
          ? Image.network(
              imagePath,
              fit: BoxFit.cover,
              width: 110,
              height: 110,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholderIcon(context),
            )
          : Image.asset(
              imagePath,
              fit: BoxFit.cover,
              width: 110,
              height: 110,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholderIcon(context),
            );
    }
    return _placeholderIcon(context);
  }

  Widget _placeholderIcon(BuildContext context) {
    return Icon(
      Icons.add_photo_alternate_outlined,
      size: 36,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
