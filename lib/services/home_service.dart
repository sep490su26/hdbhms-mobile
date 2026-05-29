import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/home_summary_model.dart';
import 'authenticated_client.dart';

class HomeException implements Exception {
  const HomeException(this.message);

  final String message;
}

class HomeService {
  const HomeService({http.Client? client}) : _client = client;

  final http.Client? _client;
  http.Client get _effectiveClient => _client ?? AuthenticatedClient();
  static const _timeout = Duration(seconds: 15);

  Future<HomeSummary> fetchHomeSummary() async {
    final client = _effectiveClient;
    try {
      final response = await client
          .get(Uri.parse('${ApiConfig.baseUrl}/home'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        return HomeSummary.fromJson(decoded['data']);
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
