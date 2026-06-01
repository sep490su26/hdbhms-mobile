import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/file_metadata_model.dart';
import '../models/identity_image_file.dart';
import 'file_service.dart';

abstract class FileUploadService {
  Future<IdentityImageFile> pickIdentityImage({
    required String label,
    required IdentityImageSource source,
  });

  bool isFileTooLarge(IdentityImageFile file);

  String? validateIdentityImage(IdentityImageFile file);

  Future<FileMetadataResponse> upload(
    IdentityImageFile file, {
    required FileCategory category,
  });
}

class ImagePickerFileUploadService implements FileUploadService {
  ImagePickerFileUploadService({
    ImagePicker? picker,
    FileService? fileService,
    this.maxSizeInBytes = 10 * 1024 * 1024,
  })  : _picker = picker ?? ImagePicker(),
        _fileService = fileService ?? const FileService();

  final ImagePicker _picker;
  final FileService _fileService;
  final int maxSizeInBytes;
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'heic'};
  static const _allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
  };

  @override
  Future<IdentityImageFile> pickIdentityImage({
    required String label,
    required IdentityImageSource source,
  }) async {
    final XFile? image;
    try {
      image = await _picker.pickImage(
        source: source == IdentityImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
    } on PlatformException catch (error) {
      if (_isPermissionError(error)) {
        throw FilePickerPermissionDeniedException(source);
      }
      rethrow;
    }

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
      path: image.path,
      mimeType: image.mimeType,
    );
  }

  @override
  bool isFileTooLarge(IdentityImageFile file) {
    return file.sizeInBytes > maxSizeInBytes;
  }

  @override
  String? validateIdentityImage(IdentityImageFile file) {
    if (!_hasValidType(file)) {
      return 'Định dạng ảnh không hợp lệ, vui lòng chụp lại';
    }
    if (isFileTooLarge(file)) {
      return 'Ảnh quá lớn, vui lòng chụp lại';
    }
    return null;
  }

  @override
  Future<FileMetadataResponse> upload(
    IdentityImageFile file, {
    required FileCategory category,
  }) async {
    return _fileService.uploadSingle(
      bytes: file.bytes,
      fileName: file.name,
      category: category,
    );
  }

  bool _hasValidType(IdentityImageFile file) {
    final extension = _extensionOf(file.name) ?? _extensionOf(file.path ?? '');
    final mimeType = file.mimeType?.toLowerCase().trim();
    final allowedExtension =
        extension != null && _allowedExtensions.contains(extension);
    final allowedMime =
        mimeType == null ||
        mimeType.isEmpty ||
        _allowedMimeTypes.contains(mimeType);
    return allowedExtension && allowedMime;
  }

  bool _isPermissionError(PlatformException error) {
    final code = error.code.toLowerCase();
    return code.contains('denied') || code.contains('restricted');
  }

  String? _extensionOf(String value) {
    final dotIndex = value.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == value.length - 1) {
      return null;
    }
    return value.substring(dotIndex + 1).toLowerCase();
  }
}

class FilePickerCanceledException implements Exception {
  const FilePickerCanceledException();
}

class FilePickerPermissionDeniedException implements Exception {
  const FilePickerPermissionDeniedException(this.source);

  final IdentityImageSource source;
}

class MockFileUploadService implements FileUploadService {
  const MockFileUploadService({
    this.maxSizeInBytes = 5 * 1024 * 1024,
    this.fileService = const FileService(),
  });

  final int maxSizeInBytes;
  final FileService fileService;

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

  @override
  String? validateIdentityImage(IdentityImageFile file) {
    if (isFileTooLarge(file)) {
      return 'Ảnh quá lớn, vui lòng chụp lại';
    }
    return null;
  }

  @override
  Future<FileMetadataResponse> upload(
    IdentityImageFile file, {
    required FileCategory category,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return FileMetadataResponse(
      fileId: DateTime.now().millisecondsSinceEpoch,
      originalFileName: file.name,
      url: 'https://example.com/mock-file.jpg',
      uploaded: true,
      message: 'Upload successful (Mock)',
    );
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
