import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/notification/notification_model.dart';

void main() {
  test('NotificationItem parses backend read aliases', () {
    expect(
      NotificationItem.fromJson(_notificationJson({'isRead': true})).isRead,
      isTrue,
    );
    expect(
      NotificationItem.fromJson(_notificationJson({'read': true})).isRead,
      isTrue,
    );
    expect(
      NotificationItem.fromJson(_notificationJson({'is_read': 1})).isRead,
      isTrue,
    );
  });

  test('NotificationItem treats readAt as read', () {
    final item = NotificationItem.fromJson(
      _notificationJson({'readAt': '2026-07-17T18:35:00'}),
    );

    expect(item.isRead, isTrue);
    expect(item.readAt, isNotNull);
  });
}

Map<String, dynamic> _notificationJson(Map<String, dynamic> overrides) {
  return {
    'id': 11,
    'title': 'Thong bao',
    'body': 'Noi dung',
    'createdAt': '2026-07-17T18:30:00',
    ...overrides,
  };
}
