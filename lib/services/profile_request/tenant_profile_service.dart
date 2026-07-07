import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:typed_data';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/api_response.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_profile_model.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';

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
  http.Client get _effectiveClient => _client ?? AuthenticatedClient();
  static const _timeout = Duration(seconds: 20);

  Future<TenantProfileResponse> getMyProfile() async {
    final client = _effectiveClient;
    try {
      final response = await client
          .get(Uri.parse('${ApiConfig.baseUrl}/tenants/profiles/me'))
          .timeout(_timeout);

      final apiResponse = ApiResponse<TenantProfileResponse>.fromJson(
        _decodeBody(response.body),
        (data) => TenantProfileResponse.fromJson(data as Map<String, dynamic>),
      );

      if (response.statusCode == 200 && apiResponse.data != null) {
        return apiResponse.data!;
      }

      if (response.statusCode == 404) {
        throw const TenantProfileNotFoundException();
      }

      throw TenantProfileException(
        apiResponse.message ?? 'Không tải được hồ sơ, vui lòng thử lại',
      );
    } on TimeoutException {
      throw const TenantProfileException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const TenantProfileException('Không kết nối được máy chủ');
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

  Future<TenantProfileResponse> updateMyProfile({
    required String phone,
    required String email,
    required List<Map<String, dynamic>> emergencyContacts,
    required List<Map<String, dynamic>> vehicles,
  }) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .put(
            Uri.parse('${ApiConfig.baseUrl}/tenants/profiles/me'),
            body: jsonEncode({
              'phone': phone,
              'email': email,
              'emergencyContacts': emergencyContacts,
              'vehicles': vehicles,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = _decodeBody(response.body);
        return TenantProfileResponse.fromJson(data['data'] ?? data);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const TenantProfileForbiddenException();
      }

      throw const TenantProfileException(
        'Không thể cập nhật hồ sơ, vui lòng thử lại',
      );
    } on TimeoutException {
      throw const TenantProfileException(
        'Không thể cập nhật hồ sơ, vui lòng thử lại',
      );
    } on http.ClientException {
      throw const TenantProfileException(
        'Không thể cập nhật hồ sơ, vui lòng thử lại',
      );
    } on FormatException {
      throw const TenantProfileException(
        'Không thể cập nhật hồ sơ, vui lòng thử lại',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<int> uploadVehicleImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final client = _effectiveClient;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/files/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['category'] = 'VEHICLE_PHOTO';
      request.fields['isSensitive'] = 'false';

      final extension = fileName.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
        'png' => MediaType('image', 'png'),
        'heic' => MediaType('image', 'heic'),
        _ => MediaType('application', 'octet-stream'),
      };

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: mimeType,
        ),
      );

      final streamedResponse = await client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = _decodeBody(response.body);
        final data = body['data'] as Map<String, dynamic>?;
        final fileId = data?['fileId'] ?? data?['file_id'];
        if (fileId is int) return fileId;
        if (fileId != null) return int.parse(fileId.toString());
      }
      throw const TenantProfileException('Tải ảnh xe thất bại');
    } on TimeoutException {
      throw const TenantProfileException('Tải ảnh xe thất bại');
    } on http.ClientException {
      throw const TenantProfileException('Tải ảnh xe thất bại');
    } on FormatException {
      throw const TenantProfileException('Tải ảnh xe thất bại');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }
}
