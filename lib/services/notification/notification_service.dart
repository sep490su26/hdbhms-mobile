import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../models/notification/notification_model.dart';
import '../authenticated_client.dart';

class NotificationException implements Exception {
  const NotificationException(this.message);
  final String message;
}

class NotificationForbiddenException extends NotificationException {
  const NotificationForbiddenException() : super('Phiên đăng nhập đã hết hạn');
}

class NotificationScrollResponse {
  const NotificationScrollResponse({
    required this.hasMore,
    required this.items,
  });

  final bool hasMore;
  final List<NotificationItem> items;
}

class NotificationService {
  const NotificationService({http.Client? client}) : _client = client;

  final http.Client? _client;

  http.Client get _effectiveClient => _client ?? AuthenticatedClient(inner: http.Client());

  static const _timeout = Duration(seconds: 15);

  Future<NotificationScrollResponse> getNotifications({int limit = 20, int after = 0}) async {
    final client = _effectiveClient;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/notifications/scroll').replace(
        queryParameters: {
          'limit': limit.toString(),
          'after': after.toString(),
        },
      );
      final response = await client
          .get(
            uri,
            headers: {'X-Client-Type': 'mobile'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic> && body.containsKey('data')) {
          final data = body['data'] as Map<String, dynamic>;
          final hasMore = data['hasMore'] as bool? ?? false;
          final itemsList = (data['items'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(NotificationItem.fromJson)
              .toList();
          return NotificationScrollResponse(hasMore: hasMore, items: itemsList);
        }
        return const NotificationScrollResponse(hasMore: false, items: []);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const NotificationForbiddenException();
      }
      throw NotificationException(_messageForError(response));
    } on NotificationException {
      rethrow;
    } on TimeoutException {
      throw const NotificationException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const NotificationException('Không kết nối được máy chủ');
    } on FormatException {
      throw const NotificationException('Dữ liệu không hợp lệ');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<void> markAsRead(String id) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/notifications/$id/read'),
            headers: {'X-Client-Type': 'mobile'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) return;
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const NotificationForbiddenException();
      }
      throw NotificationException(_messageForError(response));
    } on NotificationException {
      rethrow;
    } on TimeoutException {
      throw const NotificationException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const NotificationException('Không kết nối được máy chủ');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<void> markAllAsRead() async {
    final client = _effectiveClient;
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/notifications/read-all'),
            headers: {'X-Client-Type': 'mobile'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) return;
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const NotificationForbiddenException();
      }
      throw NotificationException(_messageForError(response));
    } on NotificationException {
      rethrow;
    } on TimeoutException {
      throw const NotificationException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const NotificationException('Không kết nối được máy chủ');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  String _messageForError(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body['message']?.toString() ?? 'Lỗi không xác định';
    } catch (_) {
      return 'Lỗi không xác định';
    }
  }
}
