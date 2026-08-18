import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/screens/maintenance/create_maintenance_ticket_screen.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_detail_screen.dart';
import 'package:hdbhms_mobile/services/maintenance/maintenance_ticket_service.dart';

class _CreateTicketService extends MaintenanceTicketService {
  _CreateTicketService({this.error});

  final Object? error;
  int createCalls = 0;

  @override
  Future<MaintenanceTicketModel> createTicket(
    CreateMaintenanceTicketRequest request,
  ) async {
    createCalls++;
    if (error != null) throw error!;
    return MaintenanceTicketModel(
      id: 1,
      code: 'SC-1',
      category: request.category,
      title: request.title,
      description: request.description,
      createdDate: DateTime(2026, 8, 19),
      status: TicketStatus.pending,
    );
  }
}

class _DetailActionService extends MaintenanceTicketService {
  _DetailActionService(this.actionError);

  final Object actionError;

  @override
  Future<MaintenanceTicketDetail> getTicketDetail(int ticketId) async {
    return MaintenanceTicketDetail.fromJson({
      'id': ticketId,
      'ticket_code': 'SC-$ticketId',
      'room_id': 101,
      'room_code': 'A.101',
      'category': 'ELECTRICITY',
      'title': 'Đèn phòng không sáng',
      'description': 'Đèn phòng không sáng từ buổi tối.',
      'status': 'WAITING_TENANT_DECISION',
      'severity': 'MEDIUM',
      'scope': 'ROOM',
      'created_at': '2026-08-19T08:00:00',
    });
  }

  @override
  Future<void> decideRepair(
    int ticketId, {
    required bool approved,
    String? reason,
  }) async {
    throw actionError;
  }
}

Future<void> _pumpCreate(
  WidgetTester tester,
  _CreateTicketService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CreateMaintenanceTicketScreen(
        ticketService: service,
        roomId: 101,
        roomCode: 'A.101',
        notificationInitialUnreadCount: 0,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _submitCreate(WidgetTester tester) async {
  final submit = find.text('GỬI YÊU CẦU');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 260));
}

void main() {
  group('Round 22 maintenance validation', () {
    testWidgets('empty description is shown inline and never calls the API', (
      tester,
    ) async {
      final service = _CreateTicketService();
      await _pumpCreate(tester, service);

      await _submitCreate(tester);

      expect(find.text('Vui lòng mô tả vấn đề'), findsWidgets);
      expect(service.createCalls, 0);
    });

    testWidgets(
      'trimmed descriptions shorter than ten characters are rejected',
      (tester) async {
        final service = _CreateTicketService();
        await _pumpCreate(tester, service);
        final description = find.byType(TextFormField);
        await tester.enterText(description, '   123456789   ');

        await _submitCreate(tester);

        expect(
          find.text('Mô tả sự cố phải có tối thiểu 10 ký tự'),
          findsWidgets,
        );
        expect(service.createCalls, 0);
        final editableText = find.descendant(
          of: description,
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(editableText).focusNode.hasFocus,
          isTrue,
        );
      },
    );

    testWidgets('exactly ten description characters pass client validation', (
      tester,
    ) async {
      final service = _CreateTicketService();
      await _pumpCreate(tester, service);
      await tester.tap(find.text('Điện'));
      await tester.enterText(find.byType(TextFormField), '1234567890');

      await _submitCreate(tester);

      expect(service.createCalls, 1);
      expect(find.text('Mô tả sự cố phải có tối thiểu 10 ký tự'), findsNothing);
    });

    testWidgets('create keeps typed maintenance errors from the server', (
      tester,
    ) async {
      final service = _CreateTicketService(
        error: const MaintenanceTicketException('Mô tả bị máy chủ từ chối'),
      );
      await _pumpCreate(tester, service);
      await tester.tap(find.text('Điện'));
      await tester.enterText(
        find.byType(TextFormField),
        'Mô tả có đủ mười ký tự',
      );

      await _submitCreate(tester);

      expect(find.text('Mô tả bị máy chủ từ chối'), findsOneWidget);
    });

    testWidgets('create keeps a generic fallback for unknown errors', (
      tester,
    ) async {
      final service = _CreateTicketService(error: StateError('network'));
      await _pumpCreate(tester, service);
      await tester.tap(find.text('Điện'));
      await tester.enterText(
        find.byType(TextFormField),
        'Mô tả có đủ mười ký tự',
      );

      await _submitCreate(tester);

      expect(
        find.text('Gửi yêu cầu thất bại, vui lòng thử lại'),
        findsOneWidget,
      );
    });

    testWidgets(
      'detail action keeps typed maintenance errors from the server',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceTicketDetailScreen(
              ticketId: 10,
              ticketService: _DetailActionService(
                const MaintenanceTicketException(
                  'Không thể xác nhận phiếu này',
                ),
              ),
              notificationInitialUnreadCount: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Đồng ý sửa chữa'));
        await tester.tap(find.text('Đồng ý sửa chữa'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đồng ý sửa'));
        await tester.pump(const Duration(milliseconds: 260));
        await tester.pump();

        expect(find.text('Không thể xác nhận phiếu này'), findsOneWidget);
      },
    );
  });
}
