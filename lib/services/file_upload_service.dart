import '../models/identity_image_file.dart';

abstract class FileUploadService {
  Future<IdentityImageFile> pickIdentityImage({
    required String label,
    required IdentityImageSource source,
  });

  bool isFileTooLarge(IdentityImageFile file);
}

class MockFileUploadService implements FileUploadService {
  const MockFileUploadService({this.maxSizeInBytes = 5 * 1024 * 1024});

  final int maxSizeInBytes;

  @override
  Future<IdentityImageFile> pickIdentityImage({
    required String label,
    required IdentityImageSource source,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    return IdentityImageFile(
      id: '${label}_${source.name}_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      sizeInBytes: source == IdentityImageSource.camera
          ? 1450 * 1024
          : 1920 * 1024,
      source: source,
    );
  }

  @override
  bool isFileTooLarge(IdentityImageFile file) {
    return file.sizeInBytes > maxSizeInBytes;
  }
}
