import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../models/identity_image_file.dart';

abstract class FileUploadService {
  Future<IdentityImageFile> pickIdentityImage({
    required String label,
    required IdentityImageSource source,
  });

  bool isFileTooLarge(IdentityImageFile file);
}

class ImagePickerFileUploadService implements FileUploadService {
  ImagePickerFileUploadService({
    ImagePicker? picker,
    this.maxSizeInBytes = 10 * 1024 * 1024,
  }) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final int maxSizeInBytes;

  @override
  Future<IdentityImageFile> pickIdentityImage({
    required String label,
    required IdentityImageSource source,
  }) async {
    final image = await _picker.pickImage(
      source: source == IdentityImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2200,
    );

    if (image == null) {
      throw const FilePickerCanceledException();
    }

    final bytes = await image.readAsBytes();
    return IdentityImageFile(
      id: image.path,
      label: label,
      name: image.name,
      sizeInBytes: bytes.length,
      source: source,
      bytes: bytes,
      mimeType: image.mimeType,
    );
  }

  @override
  bool isFileTooLarge(IdentityImageFile file) {
    return file.sizeInBytes > maxSizeInBytes;
  }
}

class FilePickerCanceledException implements Exception {
  const FilePickerCanceledException();
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
      name: '${label}_${source.name}.jpg',
      sizeInBytes: source == IdentityImageSource.camera
          ? 1450 * 1024
          : 1920 * 1024,
      source: source,
      bytes: _transparentPngBytes(),
      mimeType: 'image/jpeg',
    );
  }

  @override
  bool isFileTooLarge(IdentityImageFile file) {
    return file.sizeInBytes > maxSizeInBytes;
  }

  static Uint8List _transparentPngBytes() {
    return Uint8List.fromList(const [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      8,
      6,
      0,
      0,
      0,
      31,
      21,
      196,
      137,
      0,
      0,
      0,
      10,
      73,
      68,
      65,
      84,
      120,
      156,
      99,
      0,
      1,
      0,
      0,
      5,
      0,
      1,
      13,
      10,
      45,
      180,
      0,
      0,
      0,
      0,
      73,
      69,
      78,
      68,
      174,
      66,
      96,
      130,
    ]);
  }
}
