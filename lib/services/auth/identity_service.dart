import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/auth/identity_image_file.dart';
import 'package:hdbhms_mobile/models/onboarding_state.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';

class IdentityException implements Exception {
  const IdentityException(this.message);

  final String message;
}

class CccdOcrIdentity {
  const CccdOcrIdentity({
    this.idNumber,
    this.fullName,
    this.dob,
    this.gender,
    this.address,
    this.issuedDate,
    this.issuedPlace,
    this.oldIdNumber,
  });

  final String? idNumber;
  final String? fullName;
  final String? dob;
  final String? gender;
  final String? address;
  final String? issuedDate;
  final String? issuedPlace;
  final String? oldIdNumber;

  factory CccdOcrIdentity.fromJson(Map<String, dynamic> json) {
    String? value(List<String> keys) {
      for (final key in keys) {
        final raw = json[key]?.toString().trim();
        if (raw != null && raw.isNotEmpty) return raw;
      }
      return null;
    }

    return CccdOcrIdentity(
      idNumber: value(['idNumber', 'id_number']),
      fullName: value(['fullName', 'full_name']),
      dob: value(['dob', 'dateOfBirth', 'date_of_birth']),
      gender: value(['gender']),
      address: value(['address']),
      issuedDate: value(['issuedDate', 'issued_date']),
      issuedPlace: value(['issuedPlace', 'issued_place']),
      oldIdNumber: value(['oldIdNumber', 'old_id_number']),
    );
  }

  bool get hasAnyValue => [
    idNumber,
    fullName,
    dob,
    gender,
    address,
    issuedDate,
    issuedPlace,
    oldIdNumber,
  ].any((value) => value?.isNotEmpty == true);
}

class CccdOcrResult {
  const CccdOcrResult({
    required this.success,
    required this.message,
    this.extractedIdentity,
  });

  final bool success;
  final String message;
  final CccdOcrIdentity? extractedIdentity;
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
  static const _ocrTimeout = Duration(seconds: 30);
  static const _uploadTimeout = Duration(seconds: 120);

  Future<CccdOcrResult> extractCccd({
    required IdentityImageFile frontImage,
    required IdentityImageFile backImage,
  }) async {
    // Avoid redirecting to login when the local session is unavailable.
    if (_client == null) {
      SharedPreferences prefs;
      try {
        prefs = await SharedPreferences.getInstance().timeout(
          const Duration(seconds: 1),
        );
      } on TimeoutException {
        return const CccdOcrResult(success: false, message: '');
      } on Exception {
        return const CccdOcrResult(success: false, message: '');
      }
      final hasToken =
          prefs.getString(AuthService.accessTokenKey)?.isNotEmpty == true;
      final hasSession =
          prefs.getString(AuthService.sessionIdKey)?.isNotEmpty == true;
      if (!hasToken && !hasSession) {
        return const CccdOcrResult(success: false, message: '');
      }
    }

    final client = _client ?? AuthenticatedClient();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/identity-verification/cccd/extract'),
      );
      request.files.add(await _multipartFile('frontImage', frontImage));
      request.files.add(await _multipartFile('backImage', backImage));

      final streamedResponse = await client.send(request).timeout(_ocrTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = _responsePayload(_decodeBody(response.body));
        final rawIdentity = body['extractedIdentity'];
        return CccdOcrResult(
          success: body['success'] == true,
          message: body['message']?.toString() ?? '',
          extractedIdentity: rawIdentity is Map
              ? CccdOcrIdentity.fromJson(Map<String, dynamic>.from(rawIdentity))
              : null,
        );
      }

      throw IdentityException(_messageForOcrError(response));
    } on TimeoutException {
      throw const IdentityException('Quét OCR quá lâu, vui lòng thử lại');
    } on http.ClientException {
      throw const IdentityException('Không kết nối được dịch vụ OCR');
    } on FormatException {
      throw const IdentityException('Phản hồi OCR không hợp lệ');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<IdentityUploadResult> uploadIdentityVerification({
    required int tenantId,
    required File portraitFile,
    required File idCardFrontFile,
    required File idCardBackFile,
    required String docNumber,
    required DateTime issuedDate,
    required String issuedPlace,
    required String permanentAddress,
    String? email,
  }) async {
    return _sendMultipart(
      tenantId: tenantId,
      portraitPart: await _multipartFileFromPath(
        'portraitFile',
        portraitFile.path,
      ),
      frontIdPart: await _multipartFileFromPath(
        'idCardFrontFile',
        idCardFrontFile.path,
      ),
      backIdPart: await _multipartFileFromPath(
        'idCardBackFile',
        idCardBackFile.path,
      ),
      docNumber: docNumber,
      issuedDate: issuedDate,
      issuedPlace: issuedPlace,
      permanentAddress: permanentAddress,
      email: email,
    );
  }

  Future<IdentityUploadResult> uploadIdentity({
    required IdentityImageFile portrait,
    required IdentityImageFile frontId,
    required IdentityImageFile backId,
    required String docNumber,
    required DateTime issuedDate,
    required String issuedPlace,
    required String permanentAddress,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final tenantId = prefs.getInt(AuthService.tenantIdKey);

    if (tenantId == null) {
      throw const IdentityException('Không tìm thấy thông tin hợp đồng');
    }

    return _sendMultipart(
      tenantId: tenantId,
      portraitPart: await _multipartFile('portraitFile', portrait),
      frontIdPart: await _multipartFile('idCardFrontFile', frontId),
      backIdPart: await _multipartFile('idCardBackFile', backId),
      docNumber: docNumber,
      issuedDate: issuedDate,
      issuedPlace: issuedPlace,
      permanentAddress: permanentAddress,
      email: email,
    );
  }

  Future<IdentityUploadResult> _sendMultipart({
    required int tenantId,
    required http.MultipartFile portraitPart,
    required http.MultipartFile frontIdPart,
    required http.MultipartFile backIdPart,
    required String docNumber,
    required DateTime issuedDate,
    required String issuedPlace,
    required String permanentAddress,
    String? email,
  }) async {
    final client = _client ?? AuthenticatedClient();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiConfig.baseUrl}/tenants/$tenantId/me/identity-verification',
        ),
      );

      request.fields.addAll({
        'docNumber': docNumber.trim(),
        'issuedDate': _formatDate(issuedDate),
        'issuedPlace': issuedPlace.trim(),
        'permanentAddress': permanentAddress.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      });
      request.files.add(portraitPart);
      request.files.add(frontIdPart);
      request.files.add(backIdPart);

      final streamedResponse = await client
          .send(request)
          .timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = _responsePayload(_decodeBody(response.body));
        final onboarding = OnboardingState.fromJson(
          body['onboarding'] as Map<String, dynamic>? ?? {},
        );
        await AuthService.saveOnboarding(onboarding);

        return IdentityUploadResult(
          success: body['success'] == true,
          message: body['message']?.toString() ?? '',
          identityCompleted:
              body['identityCompleted'] == true ||
              body['identity_completed'] == true,
          profileCompleted:
              body['profileCompleted'] == true ||
              body['profile_completed'] == true,
          onboarding: onboarding,
          portraitFileId:
              _asInt(body['portraitFileId']) ??
              _asInt(body['portrait_file_id']),
          idCardFrontFileId:
              _asInt(body['idCardFrontFileId']) ??
              _asInt(body['id_card_front_file_id']),
          idCardBackFileId:
              _asInt(body['idCardBackFileId']) ??
              _asInt(body['id_card_back_file_id']),
        );
      }

      throw IdentityException(_messageForError(response));
    } on TimeoutException {
      throw const IdentityException(
        'Tải lên quá lâu, vui lòng kiểm tra kết nối và thử lại',
      );
    } on http.ClientException {
      throw const IdentityException('Tải lên thất bại, vui lòng thử lại');
    } on FormatException {
      throw const IdentityException('Tải lên thất bại, vui lòng thử lại');
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
    // The picker bytes remain valid even when a native cache path is stale.
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

  String _fileNameFromPath(String path) {
    return path.split(RegExp(r'[\\/]')).last;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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
    final backendMessage = _readBackendMessage(response.body);
    if (response.statusCode == 403) {
      return backendMessage.isNotEmpty
          ? backendMessage
          : 'Bạn không có quyền cập nhật hồ sơ này';
    }
    if (response.statusCode == 422) {
      return backendMessage.isNotEmpty
          ? backendMessage
          : 'Vui lòng tải lên đủ ảnh chân dung và 2 mặt CCCD';
    }
    return backendMessage.isNotEmpty
        ? backendMessage
        : 'Tải lên thất bại, vui lòng thử lại';
  }

  String _messageForOcrError(http.Response response) {
    if (response.statusCode == 401) {
      return 'Phiên đăng nhập không hợp lệ';
    }
    if (response.statusCode == 422) {
      return 'Ảnh CCCD không hợp lệ hoặc không đủ rõ để quét OCR';
    }
    return 'Không thể kết nối dịch vụ OCR';
  }

  String _readBackendMessage(String body) {
    try {
      final root = _decodeBody(body);
      final payload = _responsePayload(root);
      for (final data in [root, payload]) {
        final message = data['message'] ?? data['error'] ?? data['details'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString().trim();
        }
      }
      return '';
    } on FormatException {
      return '';
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Dữ liệu phản hồi không hợp lệ');
  }

  Map<String, dynamic> _responsePayload(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return body;
  }
}
