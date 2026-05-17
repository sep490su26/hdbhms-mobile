import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/identity_image_file.dart';
import '../models/onboarding_state.dart';
import 'auth_service.dart';

class IdentityException implements Exception {
  const IdentityException(this.message);

  final String message;
}

class IdentityUploadResult {
  const IdentityUploadResult({
    required this.identityCompleted,
    required this.onboarding,
  });

  final bool identityCompleted;
  final OnboardingState onboarding;
}

class IdentityService {
  const IdentityService({http.Client? client}) : _client = client;

  final http.Client? _client;
  static const _timeout = Duration(seconds: 30);

  Future<IdentityUploadResult> uploadIdentity({
    required IdentityImageFile portrait,
    required IdentityImageFile frontId,
    required IdentityImageFile backId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);
    final tenantId = prefs.getInt(AuthService.tenantIdKey);

    if (token == null || token.isEmpty || tenantId == null) {
      throw const IdentityException('Phiên đăng nhập không hợp lệ');
    }

    final client = _client ?? http.Client();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiConfig.baseUrl}/tenants/$tenantId/me/identity-verification',
        ),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      request.files.add(_multipartFile('portrait_file', portrait));
      request.files.add(_multipartFile('id_card_front_file', frontId));
      request.files.add(_multipartFile('id_card_back_file', backId));

      final streamedResponse = await client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = _decodeBody(response.body);
        final onboarding = OnboardingState.fromJson(
          body['onboarding'] as Map<String, dynamic>? ?? {},
        );
        await AuthService.saveOnboarding(onboarding);

        return IdentityUploadResult(
          identityCompleted: body['identity_completed'] == true,
          onboarding: onboarding,
        );
      }

      throw IdentityException(_messageForError(response));
    } on TimeoutException {
      throw const IdentityException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const IdentityException('Không kết nối được máy chủ');
    } on FormatException {
      throw const IdentityException('Cập nhật định danh thất bại');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  http.MultipartFile _multipartFile(String fieldName, IdentityImageFile file) {
    return http.MultipartFile.fromBytes(
      fieldName,
      file.bytes,
      filename: file.name,
    );
  }

  String _messageForError(http.Response response) {
    if (response.statusCode == 401) {
      return 'Phiên đăng nhập không hợp lệ';
    }
    if (response.statusCode == 403) {
      return _readBackendMessage(response.body).isNotEmpty
          ? _readBackendMessage(response.body)
          : 'Bạn không có quyền cập nhật hồ sơ này';
    }
    if (response.statusCode == 422) {
      return _readBackendMessage(response.body).isNotEmpty
          ? _readBackendMessage(response.body)
          : 'Vui lòng upload đủ ảnh định danh';
    }
    return 'Cập nhật định danh thất bại';
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
