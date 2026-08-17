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
