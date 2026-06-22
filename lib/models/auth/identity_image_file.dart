import 'dart:typed_data';

class IdentityImageFile {
  const IdentityImageFile({
    required this.id,
    required this.label,
    required this.name,
    required this.sizeInBytes,
    required this.source,
    required this.bytes,
    this.path,
    this.mimeType,
  });

  final String id;
  final String label;
  final String name;
  final int sizeInBytes;
  final IdentityImageSource source;
  final Uint8List bytes;
  final String? path;
  final String? mimeType;
}

enum IdentityImageSource { camera, gallery }
