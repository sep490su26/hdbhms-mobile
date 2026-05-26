import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/home_summary_model.dart';
import 'auth_service.dart';

class HomeException implements Exception {
  const HomeException(this.message);

  final String message;
}

class SessionExpiredException extends HomeException {
  const SessionExpiredException() : super('Phiên đăng nhập đã hết hạn');
}

class HomeService {
  const HomeService({http.Client? client}) : _client = client;

  final http.Client? _client;
  static const _timeout = Duration(seconds: 15);

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Client-Type': 'mobile',
      };

  Future<HomeSummary> fetchHomeSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);

    if (token == null || token.isEmpty) {
      throw const SessionExpiredException();
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/mobile/home'),
            headers: {
              ..._headers,
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        return HomeSummary.fromJson(decoded);
      }
      
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const SessionExpiredException();
      }

      throw HomeException(_messageForError(response));
    } on TimeoutException {
      throw const HomeException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const HomeException('Không kết nối được máy chủ');
    } on FormatException {
      throw const HomeException('Dữ liệu máy chủ không hợp lệ');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  String _messageForError(http.Response response) {
    try {
      final data = _decodeBody(response.body);
      final message = data['message'] ?? data['error'];
      if (message != null && message.toString().isNotEmpty) {
        return message.toString();
      }
    } on FormatException {
      // Fall through
    }
    return 'Lỗi tải dữ liệu (${response.statusCode})';
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
