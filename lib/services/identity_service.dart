import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/identity_image_file.dart';
import '../models/onboarding_state.dart';
import 'authenticated_client.dart';
import 'auth_service.dart';

class IdentityException implements Exception {
  const IdentityException(this.message);

  final String message;
}

class IdentityUploadResult {
  const IdentityUploadResult({
    required this.identityCompleted,
    required this.onboarding,
    this.profileCompleted = false,
    this.success = false,
    this.message = '',
    this.portraitFileId,
    this.idCardFrontFileId,
    this.idCardBackFileId,
  });

  final bool success;
  final String message;
  final bool identityCompleted;
  final bool profileCompleted;
  final OnboardingState onboarding;
  final int? portraitFileId;
  final int? idCardFrontFileId;
  final int? idCardBackFileId;
}

class IdentityService {
  const IdentityService({http.Client? client}) : _client = client;

  final http.Client? _client;
  static const _timeout = Duration(seconds: 30);

  Future<IdentityUploadResult> uploadIdentityVerification({
    required int tenantId,
    required File portraitFile,
    required File idCardFrontFile,
    required File idCardBackFile,
  }) async {
    return _sendMultipart(
      tenantId: tenantId,
      portraitPart: await _multipartFileFromPath(
        'portrait_file',
        portraitFile.path,
      ),
      frontIdPart: await _multipartFileFromPath(
        'id_card_front_file',
        idCardFrontFile.path,
      ),
      backIdPart: await _multipartFileFromPath(
        'id_card_back_file',
        idCardBackFile.path,
      ),
    );
  }

  Future<IdentityUploadResult> uploadIdentity({
    required IdentityImageFile portrait,
    required IdentityImageFile frontId,
    required IdentityImageFile backId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = prefs.getInt(AuthService.tenantIdKey);

    if (tenantId == null) {
      throw const IdentityException('Không tìm thấy thông tin hợp đồng');
    }

    return _sendMultipart(
      tenantId: tenantId,
      portraitPart: await _multipartFile('portrait_file', portrait),
      frontIdPart: await _multipartFile('id_card_front_file', frontId),
      backIdPart: await _multipartFile('id_card_back_file', backId),
    );
  }

  Future<IdentityUploadResult> _sendMultipart({
    required int tenantId,
    required http.MultipartFile portraitPart,
    required http.MultipartFile frontIdPart,
    required http.MultipartFile backIdPart,
  }) async {
    final client = _client ?? AuthenticatedClient();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiConfig.baseUrl}/tenants/$tenantId/me/identity-verification',
        ),
      );

      request.files.add(portraitPart);
      request.files.add(frontIdPart);
      request.files.add(backIdPart);

      final streamedResponse = await client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = _decodeBody(response.body);
        final onboarding = OnboardingState.fromJson(
          body['onboarding'] as Map<String, dynamic>? ?? {},
        );
        await AuthService.saveOnboarding(onboarding);

        return IdentityUploadResult(
          success: body['success'] == true,
          message: body['message']?.toString() ?? '',
          identityCompleted:
              body['identity_completed'] == true ||
              body['profile_completed'] == true,
          profileCompleted:
              body['profile_completed'] == true ||
              body['identity_completed'] == true,
          onboarding: onboarding,
          portraitFileId: _asInt(body['portrait_file_id']),
          idCardFrontFileId: _asInt(body['id_card_front_file_id']),
          idCardBackFileId: _asInt(body['id_card_back_file_id']),
        );
      }

      throw IdentityException(_messageForError(response));
    } on TimeoutException {
      throw const IdentityException('Upload thất bại, vui lòng thử lại');
    } on http.ClientException {
      throw const IdentityException('Upload thất bại, vui lòng thử lại');
    } on FormatException {
      throw const IdentityException('Upload thất bại, vui lòng thử lại');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<http.MultipartFile> _multipartFile(
    String fieldName,
    IdentityImageFile file,
  ) async {
    final path = file.path;
    if (_canUploadFromPath(path)) {
      return _multipartFileFromPath(fieldName, path!, fallbackName: file.name);
    }

    return http.MultipartFile.fromBytes(
      fieldName,
      file.bytes,
      filename: file.name,
      contentType: _mediaTypeFor(file.name, file.mimeType),
    );
  }

  Future<http.MultipartFile> _multipartFileFromPath(
    String fieldName,
    String path, {
    String? fallbackName,
  }) {
    final fileName = fallbackName ?? _fileNameFromPath(path);
    return http.MultipartFile.fromPath(
      fieldName,
      path,
      filename: fileName,
      contentType: _mediaTypeFor(fileName, null),
    );
  }

  bool _canUploadFromPath(String? path) {
    if (kIsWeb || path == null || path.isEmpty) {
      return false;
    }
    final normalized = path.toLowerCase();
    return !normalized.startsWith('blob:') &&
        !normalized.startsWith('http://') &&
        !normalized.startsWith('https://');
  }

  String _fileNameFromPath(String path) {
    return path.split(RegExp(r'[\\/]')).last;
  }

  MediaType _mediaTypeFor(String fileName, String? explicitMimeType) {
    final mimeType = _resolveMimeType(fileName, explicitMimeType);
    final parts = mimeType.split('/');
    return MediaType(parts[0], parts[1]);
  }

  String _resolveMimeType(String fileName, String? explicitMimeType) {
    final normalized = explicitMimeType?.toLowerCase().trim();
    if (normalized == 'image/jpeg' ||
        normalized == 'image/png' ||
        normalized == 'image/heic' ||
        normalized == 'image/heif') {
      return normalized!;
    }

    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'heic' => 'image/heic',
      _ => 'application/octet-stream',
    };
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String _messageForError(http.Response response) {
    if (response.statusCode == 401) {
      return 'Phiên đăng nhập không hợp lệ';
    }
    if (response.statusCode == 403) {
      final backendMessage = _readBackendMessage(response.body);
      return backendMessage.isNotEmpty
          ? backendMessage
          : 'Bạn không có quyền cập nhật hồ sơ này';
    }
    if (response.statusCode == 422) {
      final backendMessage = _readBackendMessage(response.body);
      return backendMessage.isNotEmpty
          ? backendMessage
          : 'Vui lòng upload đủ ảnh chân dung và 2 mặt CCCD';
    }
    return 'Upload thất bại, vui lòng thử lại';
  }

  String _readBackendMessage(String body) {
    try {
      final data = _decodeBody(body);
      final message = data['message'] ?? data['error'];
      return message?.toString() ?? '';
    } on FormatException {
      return '';
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Invalid response body');
  }
}
