import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

const List<String> supportedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

bool get _isDesktop =>
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

/// Picks an image and returns its raw bytes, or null if the admin cancelled.
///
/// Uses `file_picker` on web and desktop (where a native gallery/camera
/// picker isn't applicable) and `image_picker` on mobile.
Future<Uint8List?> pickProductImageBytes() async {
  if (kIsWeb || _isDesktop) {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedImageExtensions,
      withData: true,
    );
    return result?.files.single.bytes;
  }

  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  return picked?.readAsBytes();
}
