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
  static final StreamController<void> _readEvents =
      StreamController<void>.broadcast();

  static Stream<void> get readEvents => _readEvents.stream;

  http.Client get _effectiveClient =>
      _client ?? AuthenticatedClient(inner: http.Client());

  static const _timeout = Duration(seconds: 15);

  Future<int> getUnreadCount({int? roomId, String? roomCode}) async {
    final client = _effectiveClient;
    try {
      final queryParameters = <String, String>{
        if (roomId != null && roomId > 0) 'roomId': roomId.toString(),
        if (roomCode != null && roomCode.trim().isNotEmpty)
          'roomCode': roomCode.trim(),
      };
      var uri = Uri.parse('${ApiConfig.baseUrl}/notifications/unread-count');
      if (queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }
      final response = await client
          .get(uri, headers: {'X-Client-Type': 'mobile'})
          .timeout(_timeout);

      if (_isSuccess(response)) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final data = body is Map<String, dynamic> ? body['data'] : null;
        return int.tryParse(data?.toString() ?? '') ?? 0;
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

  Future<NotificationScrollResponse> getNotifications({
    int limit = 20,
    int after = 0,
    int? roomId,
    String? roomCode,
  }) async {
    final client = _effectiveClient;
    try {
      final queryParameters = <String, String>{
        'limit': limit.toString(),
        'after': after.toString(),
        if (roomId != null && roomId > 0) 'roomId': roomId.toString(),
        if (roomCode != null && roomCode.trim().isNotEmpty)
          'roomCode': roomCode.trim(),
      };
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/notifications/scroll',
      ).replace(queryParameters: queryParameters);
      final response = await client
          .get(uri, headers: {'X-Client-Type': 'mobile'})
          .timeout(_timeout);

      if (_isSuccess(response)) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic> && body.containsKey('data')) {
          final data = body['data'] as Map<String, dynamic>;
          final hasMore =
              data['hasMore'] as bool? ?? data['has_more'] as bool? ?? false;
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

      if (_isSuccess(response)) {
        _notifyReadChanged();
        return;
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
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<void> markAllAsRead({int? roomId, String? roomCode}) async {
    final client = _effectiveClient;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/notifications/read-all')
          .replace(
            queryParameters: {
              if (roomId != null && roomId > 0) 'roomId': roomId.toString(),
              if (roomCode != null && roomCode.trim().isNotEmpty)
                'roomCode': roomCode.trim(),
            },
          );
      final response = await client
          .post(uri, headers: {'X-Client-Type': 'mobile'})
          .timeout(_timeout);

      if (_isSuccess(response)) {
        _notifyReadChanged();
        return;
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
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<void> markTargetAsRead({
    required String targetType,
    required int targetId,
  }) async {
    final client = _effectiveClient;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/notifications/target/read')
          .replace(
            queryParameters: {
              'targetType': targetType,
              'targetId': targetId.toString(),
            },
          );
      final response = await client
          .post(uri, headers: {'X-Client-Type': 'mobile'})
          .timeout(_timeout);

      if (_isSuccess(response)) {
        _notifyReadChanged();
        return;
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

  bool _isSuccess(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  static void _notifyReadChanged() {
    if (!_readEvents.isClosed) {
      _readEvents.add(null);
    }
  }
}
