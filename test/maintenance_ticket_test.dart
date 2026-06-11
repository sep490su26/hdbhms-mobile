import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/file_metadata_model.dart';
import 'package:hdbhms_mobile/models/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/screens/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/services/file_service.dart';
import 'package:hdbhms_mobile/services/maintenance_ticket_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('MaintenanceTicketService calls tenant API with filters', () async {
    final service = MaintenanceTicketService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/maintenance/tickets/my');
        expect(request.url.queryParameters['code'], '#SC-2825');
        expect(request.url.queryParameters['status'], 'COMPLETED');
        expect(request.url.queryParameters['category'], 'WATER');

        return http.Response(
          jsonEncode({
            'currentPage': 1,
            'totalPages': 1,
            'pageSize': 100,
            'totalElements': 1,
            'data': [_ticketJson(id: 2825, code: '#SC-2825')],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final tickets = await service.getTickets(
      keyword: '#SC-2825',
      status: 'COMPLETED',
      category: 'WATER',
    );

    expect(tickets, hasLength(1));
    expect(tickets.single.code, '#SC-2825');
    expect(tickets.single.status, TicketStatus.completed);
  });

  test(
    'MaintenanceTicketService creates ticket with uploaded image ids',
    () async {
      Map<String, dynamic>? requestBody;
      final service = MaintenanceTicketService(
        fileService: const _FakeFileService(),
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/maintenance/tickets');
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;

          return http.Response(
            jsonEncode({
              'code': 0,
              'data': _ticketJson(id: 9, code: '#SC-0009'),
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final created = await service.createTicket(
        const CreateMaintenanceTicketRequest(
          roomId: 1,
          category: TicketCategory.water,
          title: 'Vòi nước rò rỉ',
          description: 'Vòi nước lavabo bị rò liên tục',
          attachments: [
            MaintenanceAttachment(
              name: 'before.jpg',
              path: 'before.jpg',
              mimeType: 'image/jpeg',
              sizeBytes: 3,
              type: MaintenanceAttachmentType.image,
              previewBytes: [1, 2, 3],
            ),
          ],
        ),
      );

      expect(created.code, '#SC-0009');
      expect(requestBody?['roomId'], 1);
      expect(requestBody?['ticketScope'], 'TENANT_ROOM');
      expect(requestBody?['attachmentIds'], [77]);
    },
  );

  testWidgets('ticket list screen renders injected tickets and search filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MaintenanceTicketListScreen(
          ticketService: _FakeMaintenanceTicketService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Danh sách phiếu sự cố'), findsOneWidget);
    expect(_ticketCodeFinder('#SC-2825'), findsOneWidget);
    expect(_ticketCodeFinder('#SC-2810'), findsOneWidget);
    expect(_ticketCodeFinder('#SC-2805'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '#SC-2825');
    await tester.tap(find.text('Lọc'));
    await tester.pumpAndSettle();

    expect(_ticketCodeFinder('#SC-2825'), findsOneWidget);
    expect(_ticketCodeFinder('#SC-2810'), findsNothing);
    expect(_ticketCodeFinder('#SC-2805'), findsNothing);
  });

  testWidgets('ticket list screen can filter by category dropdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MaintenanceTicketListScreen(
          ticketService: _FakeMaintenanceTicketService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nước').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lọc'));
    await tester.pumpAndSettle();

    expect(_ticketCodeFinder('#SC-2805'), findsOneWidget);
    expect(_ticketCodeFinder('#SC-2825'), findsNothing);
    expect(_ticketCodeFinder('#SC-2810'), findsNothing);
  });
}

class _FakeFileService extends FileService {
  const _FakeFileService();

  @override
  Future<FileMetadataResponse> uploadSingle({
    required Uint8List bytes,
    required String fileName,
    FileCategory category = FileCategory.OTHER,
    bool isSensitive = false,
  }) async {
    expect(category, FileCategory.TICKET_ATTACHMENT);
    expect(bytes, isNotEmpty);
    return const FileMetadataResponse(
      fileId: 77,
      originalFileName: 'before.jpg',
      url: '/api/v1/files/download/77',
      uploaded: true,
    );
  }
}

class _FakeMaintenanceTicketService extends MaintenanceTicketService {
  const _FakeMaintenanceTicketService();

  @override
  Future<List<MaintenanceTicketModel>> getTickets({
    String? keyword,
    String? status,
    String? category,
  }) async {
    final query = keyword?.trim().toLowerCase() ?? '';
    final selectedStatus = status == null || status == 'Tất cả'
        ? null
        : TicketStatus.fromBackend(status);
    final selectedCategory = category == null || category == 'Tất cả'
        ? null
        : TicketCategory.fromBackend(category);

    return _tickets
        .where((ticket) {
          final matchesKeyword =
              query.isEmpty || ticket.code.toLowerCase().contains(query);
          final matchesStatus =
              selectedStatus == null || ticket.status == selectedStatus;
          final matchesCategory =
              selectedCategory == null || ticket.category == selectedCategory;
          return matchesKeyword && matchesStatus && matchesCategory;
        })
        .toList(growable: false);
  }
}

final _tickets = [
  MaintenanceTicketModel(
    id: 1,
    code: '#SC-2825',
    category: TicketCategory.electricity,
    title: 'Máy lạnh không lạnh',
    description: 'Máy lạnh phòng ngủ không lạnh',
    createdDate: _createdDate,
    status: TicketStatus.completed,
    roomId: 1,
    roomCode: '201',
  ),
  MaintenanceTicketModel(
    id: 2,
    code: '#SC-2810',
    category: TicketCategory.other,
    title: 'Sơn tường',
    description: 'Sơn lại tường phòng khách',
    createdDate: _createdDate,
    status: TicketStatus.rejected,
    roomId: 1,
    roomCode: '201',
  ),
  MaintenanceTicketModel(
    id: 3,
    code: '#SC-2805',
    category: TicketCategory.water,
    title: 'Nước yếu',
    description: 'Nước chảy yếu tại vòi sen',
    createdDate: _createdDate,
    status: TicketStatus.accepted,
    roomId: 1,
    roomCode: '201',
  ),
];

final _createdDate = DateTime(2026, 6, 1);

Map<String, dynamic> _ticketJson({required int id, required String code}) {
  return {
    'id': id,
    'ticket_code': code,
    'room_id': 1,
    'room_code': '201',
    'category': 'WATER',
    'title': 'Vòi nước rò rỉ',
    'description': 'Vòi nước lavabo bị rò liên tục',
    'priority': 'MEDIUM',
    'status': 'COMPLETED',
    'ticket_scope': 'ROOM',
    'created_at': '2026-06-01T08:00:00',
  };
}

Finder _ticketCodeFinder(String code) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == code,
  );
}
