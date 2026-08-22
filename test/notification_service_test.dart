import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getUnreadCount calls mobile unread-count endpoint', () async {
    final service = NotificationService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/notifications/unread-count');
        expect(request.headers['X-Client-Type'], 'mobile');

        return http.Response(
          jsonEncode({'data': 7}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    expect(await service.getUnreadCount(), 7);
  });

  test('getUnreadCount sends an optional room scope', () async {
    final service = NotificationService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/notifications/unread-count');
        expect(request.url.queryParameters['roomId'], '58');
        expect(request.url.queryParameters['roomCode'], 'P.203');
        expect(request.headers['X-Client-Type'], 'mobile');

        return http.Response(
          jsonEncode({'data': 3}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    expect(await service.getUnreadCount(roomId: 58, roomCode: 'P.203'), 3);
  });

  test('getNotifications sends an optional room scope', () async {
    final service = NotificationService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/notifications/scroll');
        expect(request.url.queryParameters['limit'], '20');
        expect(request.url.queryParameters['after'], '12');
        expect(request.url.queryParameters['roomId'], '58');
        expect(request.url.queryParameters['roomCode'], 'P.203');
        expect(request.headers['X-Client-Type'], 'mobile');

        return http.Response(
          jsonEncode({
            'data': {
              'hasMore': false,
              'items': [
                {
                  'id': 13,
                  'title': 'Invoice',
                  'body': 'Body',
                  'createdAt': '2026-08-22T10:00:00',
                  'data': {'roomId': 58, 'roomCode': 'P.203'},
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final response = await service.getNotifications(
      after: 12,
      roomId: 58,
      roomCode: 'P.203',
    );
    expect(response.items.single.roomLabel, 'Phòng P.203');
  });

  test('markAsRead posts to notification read endpoint', () async {
    final service = NotificationService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/notifications/42/read');
        expect(request.headers['X-Client-Type'], 'mobile');

        return http.Response(jsonEncode({'data': null}), 200);
      }),
    );

    await service.markAsRead('42');
  });

  test('markAllAsRead posts to read-all endpoint', () async {
    final service = NotificationService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/notifications/read-all');
        expect(request.headers['X-Client-Type'], 'mobile');

        return http.Response(jsonEncode({'data': null}), 200);
      }),
    );

    await service.markAllAsRead();
  });

  test('markAllAsRead keeps the optional room scope', () async {
    final service = NotificationService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/notifications/read-all');
        expect(request.url.queryParameters['roomId'], '58');
        expect(request.url.queryParameters['roomCode'], 'P.203');
        expect(request.headers['X-Client-Type'], 'mobile');

        return http.Response(jsonEncode({'data': null}), 200);
      }),
    );

    await service.markAllAsRead(roomId: 58, roomCode: 'P.203');
  });

  test('markTargetAsRead posts target query params', () async {
    final service = NotificationService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/notifications/target/read');
        expect(request.url.queryParameters['targetType'], 'INVOICE');
        expect(request.url.queryParameters['targetId'], '99');
        expect(request.headers['X-Client-Type'], 'mobile');

        return http.Response('', 204);
      }),
    );

    await service.markTargetAsRead(targetType: 'INVOICE', targetId: 99);
  });
}
