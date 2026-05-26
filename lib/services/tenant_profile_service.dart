import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/person_profile_model.dart';
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

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Client-Type': 'mobile',
      };

  Future<TenantProfileResponse> getMyProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);

    if (token == null || token.isEmpty) {
      throw const TenantProfileForbiddenException();
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/person-profiles/me'),
            headers: {
              ..._headers,
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      final apiResponse = ApiResponse<PersonProfileResponse>.fromJson(
        _decodeBody(response.body),
        (data) => PersonProfileResponse.fromJson(data as Map<String, dynamic>),
      );

      if (response.statusCode == 200 && apiResponse.data != null) {
        final person = apiResponse.data!;
        return TenantProfileResponse(
          tenantProfileId: person.id,
          status: 'ACTIVE', // Default for now
          person: PersonProfileDto(
            fullName: person.fullName,
            phone: person.phone,
            email: person.email,
            permanentAddress: person.permanentAddress,
          ),
          identityDocument: null, // To be provided via later APIs
          vehicles: [],           // To be provided via later APIs
          emergencyContacts: [],  // To be provided via later APIs
        );
      }
      
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const TenantProfileForbiddenException();
      }
      
      if (response.statusCode == 404) {
        throw const TenantProfileNotFoundException();
      }

      throw TenantProfileException(
        apiResponse.message ?? 'Không tải được hồ sơ, vui lòng thử lại',
      );
    } on TimeoutException {
      throw const TenantProfileException(
        'Không kết nối được máy chủ',
      );
    } on http.ClientException {
      throw const TenantProfileException(
        'Không kết nối được máy chủ',
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

  Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }
}
