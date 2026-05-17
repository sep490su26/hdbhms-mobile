import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/tenant_profile_model.dart';
import 'auth_service.dart';

class TenantProfileException implements Exception {
  const TenantProfileException(this.message);

  final String message;
}

class TenantProfileNotFoundException extends TenantProfileException {
  const TenantProfileNotFoundException() : super('Chưa có hồ sơ cá nhân');
}

class TenantProfileForbiddenException extends TenantProfileException {
  const TenantProfileForbiddenException()
    : super('Bạn không có quyền xem hồ sơ này');
}

class TenantProfileService {
  const TenantProfileService({http.Client? client}) : _client = client;

  final http.Client? _client;
  static const _timeout = Duration(seconds: 10);

  Future<TenantProfileResponse> getMyProfile({int? tenantId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);
    final currentTenantId = tenantId ?? prefs.getInt(AuthService.tenantIdKey);

    if (token == null || token.isEmpty || currentTenantId == null) {
      throw const TenantProfileForbiddenException();
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/tenants/$currentTenantId/me/profile',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return TenantProfileResponse.fromJson(_decodeBody(response.body));
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const TenantProfileForbiddenException();
      }
      if (response.statusCode == 404 &&
          _readCode(response.body) == 'PROFILE_NOT_FOUND') {
        throw const TenantProfileNotFoundException();
      }

      throw const TenantProfileException(
        'Không tải được hồ sơ, vui lòng thử lại',
      );
    } on TimeoutException {
      throw const TenantProfileException(
        'Không tải được hồ sơ, vui lòng thử lại',
      );
    } on http.ClientException {
      throw const TenantProfileException(
        'Không tải được hồ sơ, vui lòng thử lại',
      );
    } on FormatException {
      throw const TenantProfileException(
        'Không tải được hồ sơ, vui lòng thử lại',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  String _readCode(String body) {
    try {
      final data = _decodeBody(body);
      return data['code']?.toString() ?? '';
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
