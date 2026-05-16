class IdentityImageFile {
  const IdentityImageFile({
    required this.id,
    required this.label,
    required this.sizeInBytes,
    required this.source,
  });

  final String id;
  final String label;
  final int sizeInBytes;
  final IdentityImageSource source;
}

enum IdentityImageSource { camera, gallery }
