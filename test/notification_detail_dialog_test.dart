import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/models/notification/notification_model.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';

class _FakeNotificationService extends NotificationService {
  const _FakeNotificationService(this.item);

  final NotificationItem item;

  @override
  Future<NotificationScrollResponse> getNotifications({
    int limit = 20,
    int after = 0,
    int? roomId,
    String? roomCode,
  }) async => NotificationScrollResponse(hasMore: false, items: [item]);

  @override
  Future<void> markAsRead(String id) async {}
}

void main() {
  testWidgets(
    'notification detail has the required dialog hierarchy and X close',
    (tester) async {
      final item = NotificationItem(
        id: '12',
        title: 'Hóa đơn tháng 6 đã sẵn sàng',
        content: List.filled(20, 'Nội dung thông báo đầy đủ.').join(' '),
        createdAt: DateTime(2026, 6, 1, 8),
        type: NotificationType.invoice,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationListScreen(
            notificationService: _FakeNotificationService(item),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(item.title));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết thông báo'), findsOneWidget);
      expect(find.text(item.title), findsNWidgets(2));
      expect(find.text('Hóa đơn'), findsNWidgets(2));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Đóng'), findsNothing);

      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết thông báo'), findsNothing);
    },
  );

  testWidgets('future notifications do not show negative relative time', (
    tester,
  ) async {
    final item = NotificationItem(
      id: '13',
      title: 'Thông báo sắp gửi',
      content: 'Nội dung',
      createdAt: DateTime.now().add(const Duration(minutes: 101)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationListScreen(
          notificationService: _FakeNotificationService(item),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa đến lịch gửi'), findsOneWidget);
    expect(find.text('-101 phút trước'), findsNothing);
  });
}
