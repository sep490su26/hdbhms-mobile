import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/contract/handover_record_model.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';

class HandoverException implements Exception {
  const HandoverException(this.message);

  final String message;
}

class HandoverNotFoundException extends HandoverException {
  const HandoverNotFoundException()
    : super('Chưa có thông tin thiết bị bàn giao');
}

class HandoverForbiddenException extends HandoverException {
  const HandoverForbiddenException()
    : super('Bạn không có quyền xem bảng bàn giao này');
}

class HandoverService {
  const HandoverService({http.Client? client}) : _client = client;

  final http.Client? _client;
  http.Client get _effectiveClient => _client ?? AuthenticatedClient();
  static const _timeout = Duration(seconds: 20);

  Future<HandoverRecord> getHandoverItems(
    int contractId, {
    String type = 'MOVE_IN',
  }) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/tenant/contracts/$contractId/handover-items',
            ).replace(queryParameters: {'type': type}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final record = _recordFromBody(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey(contractId), response.body);
        return record;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const HandoverForbiddenException();
      }
      if (response.statusCode == 404) {
        throw const HandoverNotFoundException();
      }
      throw HandoverException(_messageForError(response));
    } on HandoverException {
      rethrow;
    } on TimeoutException {
      return _loadFromCacheOrThrow(contractId);
    } on http.ClientException {
      return _loadFromCacheOrThrow(contractId);
    } on FormatException {
      throw const HandoverException('Không tải được dữ liệu bàn giao');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  HandoverRecord _recordFromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid response body');
    }
    final payload = decoded['data'];
    if (payload is Map<String, dynamic>) {
      return HandoverRecord.fromJson(payload);
    }
    return HandoverRecord.fromJson(decoded);
  }

  Future<HandoverRecord> _loadFromCacheOrThrow(int contractId) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey(contractId));
    if (cached != null && cached.isNotEmpty) {
      return _recordFromBody(cached).copyWith(isFromCache: true);
    }
    throw const HandoverException('Không kết nối được máy chủ');
  }

  String _messageForError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message =
            decoded['message'] ?? decoded['details'] ?? decoded['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } on FormatException {
      // Fall through to generic message.
    }
    return 'Không tải được dữ liệu bàn giao';
  }

  String _cacheKey(int contractId) => 'handover_cache_$contractId';
}
