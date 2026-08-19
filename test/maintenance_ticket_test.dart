// ignore_for_file: use_null_aware_elements

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/screens/maintenance/create_maintenance_ticket_screen.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_detail_screen.dart';
import 'package:hdbhms_mobile/services/file_service.dart';
import 'package:hdbhms_mobile/services/maintenance/maintenance_ticket_service.dart';
import 'package:hdbhms_mobile/widgets/ticket_attachment_grid.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'MaintenanceTicketService loads tenant tickets from backend API',
    () async {
      final service = MaintenanceTicketService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, endsWith('/api/v1/maintenance/tickets/my'));
          expect(request.url.queryParameters['code'], 'SC-0001');
          expect(request.url.queryParameters['status'], 'COMPLETED');
          expect(request.url.queryParameters['category'], 'WATER');
          return _jsonResponse(_ticketPage([_ticketJson()]));
        }),
      );

      final tickets = await service.getTickets(
        keyword: '#SC-0001',
        status: 'Hoàn tất',
        category: 'Nước',
      );

      expect(tickets, hasLength(1));
      expect(tickets.single.code, 'SC-0001');
      expect(tickets.single.status, TicketStatus.completed);
      expect(tickets.single.category, TicketCategory.water);
    },
  );

  test('MaintenanceTicketService unwraps detail API response', () async {
    final service = MaintenanceTicketService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, endsWith('/api/v1/maintenance/tickets/12'));
        return _jsonResponse({'data': _ticketJson(id: 12)});
      }),
    );

    final detail = await service.getTicketDetail(12);

    expect(detail.id, 12);
    expect(detail.ticketCode, 'SC-0001');
    expect(detail.roomCode, '106');
  });

  test('TicketAttachment parses backend file aliases', () {
    final attachment = TicketAttachment.fromJson({
      'id': 7,
      'file_id': 91,
      'download_url': '/api/v1/files/download/91',
      'mime_type': 'image/png',
      'attachment_phase': 'AFTER',
      'sort_order': 2,
      'file_name': 'done.png',
    });

    expect(attachment.id, 7);
    expect(attachment.fileId, 91);
    expect(attachment.url, endsWith('/api/v1/files/download/91'));
    expect(attachment.mimeType, 'image/png');
    expect(attachment.phase, TicketAttachmentPhase.after);
    expect(attachment.sortOrder, 2);
    expect(attachment.name, 'done.png');
  });

  test('TicketAttachment gets file id from download URL fallback', () {
    final attachment = TicketAttachment.fromJson({
      'id': 7,
      'url': '/api/v1/files/download/91',
      'mimeType': 'image/png',
    });

    expect(attachment.fileId, 91);
    expect(attachment.url, endsWith('/api/v1/files/download/91'));
  });

  testWidgets('attachment grid renders downloaded image bytes', (tester) async {
    final fileService = _FakeFileService(_pngBytes);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketAttachmentGrid(
            attachments: const [
              TicketAttachment(
                id: 7,
                fileId: 91,
                url: '',
                mimeType: 'image/png',
                phase: TicketAttachmentPhase.before,
                sortOrder: 0,
              ),
            ],
            emptyText: 'empty',
            fileService: fileService,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(fileService.downloadedFileId, 91);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('ticket list screen renders API tickets and search filter', (
    tester,
  ) async {
    final service = _ticketService();

    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceTicketListScreen(
          ticketService: service,
          roomId: 106,
          notificationInitialUnreadCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Danh sách sự cố'), findsOneWidget);
    expect(_ticketCodeFinder('SC-0001'), findsOneWidget);
    expect(_ticketCodeFinder('SC-0002'), findsOneWidget);
    expect(_ticketCodeFinder('SC-0003'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '#SC-0001');
    await tester.tap(find.text('Lọc'));
    await tester.pumpAndSettle();

    expect(_ticketCodeFinder('SC-0001'), findsOneWidget);
    expect(_ticketCodeFinder('SC-0002'), findsNothing);
    expect(_ticketCodeFinder('SC-0003'), findsNothing);
  });

  testWidgets('ticket list screen can filter by status picker', (tester) async {
    final service = _ticketService();

    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceTicketListScreen(
          ticketService: service,
          roomId: 106,
          notificationInitialUnreadCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ticket-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn tất').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lọc'));
    await tester.pumpAndSettle();

    expect(_ticketCodeFinder('SC-0001'), findsOneWidget);
    expect(_ticketCodeFinder('SC-0002'), findsNothing);
    expect(_ticketCodeFinder('SC-0003'), findsNothing);
  });

  testWidgets('ticket list screen can filter by category picker', (
    tester,
  ) async {
    final service = _ticketService();

    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceTicketListScreen(
          ticketService: service,
          roomId: 106,
          notificationInitialUnreadCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ticket-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nước').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lọc'));
    await tester.pumpAndSettle();

    expect(_ticketCodeFinder('SC-0001'), findsOneWidget);
    expect(_ticketCodeFinder('SC-0002'), findsNothing);
    expect(_ticketCodeFinder('SC-0003'), findsNothing);
  });

  testWidgets('ticket list passes selected room into create screen', (
    tester,
  ) async {
    final service = MaintenanceTicketService(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return _jsonResponse(_ticketPage([]));
        }
        fail('Unexpected ${request.method} ${request.url}');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceTicketListScreen(
          ticketService: service,
          roomId: 888,
          roomCode: 'A-888',
          notificationInitialUnreadCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    final createScreen = tester.widget<CreateMaintenanceTicketScreen>(
      find.byType(CreateMaintenanceTicketScreen),
    );
    expect(createScreen.roomId, 888);
    expect(createScreen.roomCode, 'A-888');
    expect(find.textContaining('A-888'), findsOneWidget);
  });

  testWidgets(
    'completed tenant charge prioritizes pending payment on ticket list',
    (tester) async {
      final service = MaintenanceTicketService(
        client: MockClient(
          (request) async => _jsonResponse(
            _ticketPage([
              _ticketJson(
                billingStatus: 'PENDING_PAYMENT',
                billingStatusLabel: 'Chờ thanh toán',
                chargeAmount: 2000,
                chargeToTenant: true,
              ),
            ]),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceTicketListScreen(
            ticketService: service,
            roomId: 106,
            notificationInitialUnreadCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chờ thanh toán'), findsOneWidget);
      expect(find.text('Cần thanh toán 2.000đ'), findsOneWidget);
    },
  );

  test('completed paid and landlord-paid tickets keep billing semantics', () {
    final paid = MaintenanceTicketModel.fromJson(
      _ticketJson(
        billingStatus: 'PAID',
        billingStatusLabel: 'Đã thanh toán',
        chargeToTenant: true,
      ),
    );
    final noCharge = MaintenanceTicketModel.fromJson(
      _ticketJson(
        billingStatus: 'NO_CHARGE',
        billingStatusLabel: 'Không thu khách',
        payer: 'LANDLORD',
      ),
    );

    expect(paid.requiresTenantPayment, isFalse);
    expect(paid.billingStatusLabel, 'Đã thanh toán');
    expect(noCharge.chargeToTenant, isFalse);
    expect(noCharge.billingStatusLabel, 'Không thu khách');

    final rejected = MaintenanceTicketModel.fromJson(
      _ticketJson(
        status: 'REJECTED',
        billingStatus: 'NOT_INVOICED',
        billingStatusLabel: 'Chưa tạo hóa đơn',
        chargeAmount: 333333,
        chargeToTenant: true,
      ),
    );
    expect(rejected.requiresTenantPayment, isFalse);
    expect(rejected.primaryStatusLabel, rejected.status.label);

    final inProgress = MaintenanceTicketModel.fromJson(
      _ticketJson(status: 'IN_PROGRESS'),
    );
    final violation = MaintenanceTicketModel.fromJson(
      _ticketJson(
        category: 'RULE_VIOLATION',
        billingStatus: 'PENDING_PAYMENT',
        billingStatusLabel: 'Chờ thanh toán',
        chargeToTenant: true,
        lineType: 'VIOLATION_FINE',
      ),
    );
    final compensation = MaintenanceTicketModel.fromJson(
      _ticketJson(lineType: 'MAINTENANCE_COMPENSATION'),
    );

    expect(inProgress.primaryStatusLabel, isNot('Hoàn tất xử lý'));
    expect(violation.lineType, 'VIOLATION_FINE');
    expect(violation.primaryStatusLabel, 'Chờ thanh toán');
    expect(compensation.lineType, 'MAINTENANCE_COMPENSATION');
  });

  testWidgets('ticket detail shows incidental payment section and CTA', (
    tester,
  ) async {
    final service = MaintenanceTicketService(
      client: MockClient(
        (request) async => _jsonResponse({
          'data': _ticketJson(
            billingStatus: 'PENDING_PAYMENT',
            billingStatusLabel: 'Chờ thanh toán',
            chargeAmount: 2000,
            chargeToTenant: true,
            invoiceId: 41,
            invoiceCode: 'INV-MNT-4-0618094846',
            lineType: 'MAINTENANCE_COMPENSATION',
          ),
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceTicketDetailScreen(
          ticketId: 1,
          ticketService: service,
          notificationInitialUnreadCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thanh toán phát sinh'), findsOneWidget);
    expect(find.text('INV-MNT-4-0618094846'), findsOneWidget);
    expect(find.text('Chờ thanh toán'), findsOneWidget);
    expect(find.text('Xem hóa đơn / Thanh toán ngay'), findsOneWidget);
  });

  testWidgets('paid ticket detail hides payment CTA', (tester) async {
    final service = MaintenanceTicketService(
      client: MockClient(
        (request) async => _jsonResponse({
          'data': _ticketJson(
            billingStatus: 'PAID',
            billingStatusLabel: 'Đã thanh toán',
            chargeAmount: 2000,
            chargeToTenant: true,
            invoiceId: 41,
            invoiceCode: 'INV-MNT-4-0618094846',
          ),
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceTicketDetailScreen(
          ticketId: 1,
          ticketService: service,
          notificationInitialUnreadCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(find.text('Xem hóa đơn / Thanh toán ngay'), findsNothing);
  });

  test('ticket detail preserves manager repair proposal fields', () {
    final detail = MaintenanceTicketDetail.fromJson(
      _ticketJson(
        status: 'WAITING_TENANT_DECISION',
        rootCause: 'Ống cấp bị nứt',
        repairItems: 'Thay ống cấp mới',
        repairmanName: 'Nguyễn Văn Sửa',
        repairmanPhone: '0901 234 567',
        actualCost: 250000,
        costResponsibility: 'OWNER',
      ),
    );

    expect(detail.repairInfo?.rootCause, 'Ống cấp bị nứt');
    expect(detail.repairInfo?.repairItems, 'Thay ống cấp mới');
    expect(detail.repairInfo?.workerName, 'Nguyễn Văn Sửa');
    expect(detail.repairInfo?.repairmanPhone, '0901 234 567');
  });

  testWidgets('waiting tenant decision shows the manager repair proposal', (
    tester,
  ) async {
    await _pumpTicketDetail(
      tester,
      _ticketJson(
        status: 'WAITING_TENANT_DECISION',
        rootCause: 'Ống cấp bị nứt',
        repairItems: 'Thay ống cấp mới',
        repairmanName: 'Nguyễn Văn Sửa',
        repairmanPhone: '0901 234 567',
        actualCost: 250000,
        costResponsibility: 'OWNER',
      ),
    );

    expect(find.text('Phương án sửa chữa'), findsOneWidget);
    expect(find.text('Nguyên nhân'), findsOneWidget);
    expect(find.text('Ống cấp bị nứt'), findsOneWidget);
    expect(find.text('Hạng mục dự kiến sửa'), findsOneWidget);
    expect(find.text('Thay ống cấp mới'), findsOneWidget);
    expect(find.text('Người sửa/thợ'), findsOneWidget);
    expect(find.text('Nguyễn Văn Sửa'), findsOneWidget);
    expect(find.text('Số điện thoại người sửa'), findsOneWidget);
    expect(find.text('0901 234 567'), findsOneWidget);
    expect(find.text('Chi phí dự kiến'), findsOneWidget);
    expect(find.text('Ghi chú gửi khách'), findsNothing);
  });

  testWidgets('repair proposal omits empty optional root cause and phone', (
    tester,
  ) async {
    await _pumpTicketDetail(
      tester,
      _ticketJson(
        status: 'WAITING_TENANT_DECISION',
        rootCause: '',
        repairItems: 'Thay van nước',
        repairmanName: 'Thợ sửa',
        repairmanPhone: '',
        actualCost: 250000,
      ),
    );

    expect(find.text('Nguyên nhân'), findsNothing);
    expect(find.text('Số điện thoại người sửa'), findsNothing);
    expect(find.text('Hạng mục dự kiến sửa'), findsOneWidget);
    expect(find.text('Thay van nước'), findsOneWidget);
  });

  testWidgets('legacy repair item fallback is not duplicated as a note', (
    tester,
  ) async {
    await _pumpTicketDetail(
      tester,
      _ticketJson(
        status: 'WAITING_TENANT_DECISION',
        repairItems: '',
        costDescription: 'Thay van nước',
        actualCost: 250000,
      ),
    );

    expect(find.text('Hạng mục dự kiến sửa'), findsOneWidget);
    expect(find.text('Thay van nước'), findsOneWidget);
    expect(find.text('Ghi chú hoàn tất'), findsNothing);
  });

  testWidgets('accepted ticket without repair data has no empty repair card', (
    tester,
  ) async {
    await _pumpTicketDetail(tester, _ticketJson(status: 'ACCEPTED'));

    expect(find.text('Phương án sửa chữa'), findsNothing);
    expect(find.text('Thông tin sửa chữa'), findsNothing);
    expect(find.text('Kết quả xử lý'), findsNothing);
  });

  testWidgets('in-progress ticket retains cause and repair items', (
    tester,
  ) async {
    await _pumpTicketDetail(
      tester,
      _ticketJson(
        status: 'IN_PROGRESS',
        rootCause: 'Ống cấp bị nứt',
        repairItems: 'Thay ống cấp mới',
        actualCost: 250000,
      ),
    );

    expect(find.text('Thông tin sửa chữa'), findsOneWidget);
    expect(find.text('Nguyên nhân'), findsOneWidget);
    expect(find.text('Hạng mục sửa chữa'), findsOneWidget);
    expect(find.text('Hạng mục dự kiến sửa'), findsNothing);
  });

  testWidgets('confirmation and completed tickets show repair results', (
    tester,
  ) async {
    for (final status in ['WAITING_CONFIRMATION', 'COMPLETED']) {
      await _pumpTicketDetail(
        tester,
        _ticketJson(
          status: status,
          rootCause: 'Ống cấp bị nứt',
          repairItems: 'Thay ống cấp mới',
          completionNote: 'Đã kiểm tra và hoàn tất.',
          actualCost: 250000,
        ),
      );

      expect(find.text('Kết quả xử lý'), findsOneWidget);
      expect(find.text('Nguyên nhân'), findsOneWidget);
      expect(find.text('Hạng mục đã sửa'), findsOneWidget);
      expect(find.text('Ghi chú hoàn tất'), findsOneWidget);
    }
  });

  testWidgets('long repair proposal text wraps at supported widths', (
    tester,
  ) async {
    const rootCause =
        'Đường ống cấp nước đã cũ và nên nó bị nứt tại vị trí nằm ẩn sau tủ bếp.';
    const repairItems =
        'Thay mới toàn bộ đoạn ống cấp nước, gia cố các điểm nối và kiểm tra áp suất sau khi hoàn tất.';
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [
      Size(320, 640),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await _pumpTicketDetail(
        tester,
        _ticketJson(
          status: 'WAITING_TENANT_DECISION',
          rootCause: rootCause,
          repairItems: repairItems,
          actualCost: 250000,
        ),
      );
      await tester.ensureVisible(find.text(rootCause));
      expect(find.text(rootCause), findsOneWidget);
      expect(find.text(repairItems), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpTicketDetail(
  WidgetTester tester,
  Map<String, dynamic> ticket,
) async {
  final service = MaintenanceTicketService(
    client: MockClient((request) async => _jsonResponse({'data': ticket})),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: MaintenanceTicketDetailScreen(
        ticketId: 1,
        ticketService: service,
        notificationInitialUnreadCount: 0,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MaintenanceTicketService _ticketService() {
  return MaintenanceTicketService(
    client: MockClient((request) async {
      final query = request.url.queryParameters;
      final code = query['code'];
      final status = query['status'];
      final category = query['category'];
      final items =
          [
                _ticketJson(id: 1, code: 'SC-0001', status: 'COMPLETED'),
                _ticketJson(
                  id: 2,
                  code: 'SC-0002',
                  status: 'IN_PROGRESS',
                  category: 'ELECTRICITY',
                  title: 'Ổ điện gần bàn học lúc có lúc mất nguồn.',
                ),
                _ticketJson(
                  id: 3,
                  code: 'SC-0003',
                  status: 'PENDING_ACCEPTANCE',
                  category: 'AIR_CONDITIONER',
                  title: 'Điều hòa phòng ngủ vẫn kêu to.',
                ),
              ]
              .where((ticket) {
                final matchesCode =
                    code == null ||
                    code.isEmpty ||
                    ticket['ticket_code'].toString().contains(code);
                final matchesStatus =
                    status == null || ticket['status'].toString() == status;
                final matchesCategory =
                    category == null ||
                    ticket['category'].toString() == category;
                return matchesCode && matchesStatus && matchesCategory;
              })
              .toList(growable: false);
      return _jsonResponse(_ticketPage(items));
    }),
  );
}

Map<String, dynamic> _ticketPage(List<Map<String, dynamic>> items) {
  return {
    'currentPage': 1,
    'totalPages': 1,
    'pageSize': 100,
    'totalElements': items.length,
    'data': items,
  };
}

Map<String, dynamic> _ticketJson({
  int id = 1,
  String code = 'SC-0001',
  String status = 'COMPLETED',
  String category = 'WATER',
  String title = 'Nước chảy yếu tại vòi sen.',
  String? billingStatus,
  String? billingStatusLabel,
  int? chargeAmount,
  bool chargeToTenant = false,
  String? payer,
  int? invoiceId,
  String? invoiceCode,
  String? lineType,
  String? rootCause,
  String? repairItems,
  String? repairmanName,
  String? repairmanPhone,
  String? completionNote,
  String? costDescription,
  int? actualCost,
  String? costResponsibility,
}) {
  return {
    'id': id,
    'ticket_code': code,
    'room_id': 106,
    'room_code': '106',
    'property_name': 'Nhà trọ Hải Đăng 1',
    'category': category,
    'title': title,
    'description': title,
    'status': status,
    'severity': 'MEDIUM',
    'scope': 'ROOM',
    'created_at': '2026-06-12T21:00:00',
    if (billingStatus != null) 'billing_status': billingStatus,
    if (billingStatusLabel != null) 'billing_status_label': billingStatusLabel,
    if (chargeAmount != null) 'charge_amount': chargeAmount,
    'charge_to_tenant': chargeToTenant,
    if (payer != null) 'payer': payer,
    if (invoiceId != null) 'invoice_id': invoiceId,
    if (invoiceCode != null) 'invoice_code': invoiceCode,
    if (lineType != null) 'line_type': lineType,
    if (rootCause != null) 'rootCause': rootCause,
    if (repairItems != null) 'repairItems': repairItems,
    if (repairmanName != null) 'repairmanName': repairmanName,
    if (repairmanPhone != null) 'repairmanPhone': repairmanPhone,
    if (completionNote != null) 'completionNote': completionNote,
    if (costDescription != null) 'costDescription': costDescription,
    if (actualCost != null) 'actualCost': actualCost,
    if (costResponsibility != null) 'costResponsibility': costResponsibility,
  };
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Finder _ticketCodeFinder(String code) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == code,
  );
}

final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
);

class _FakeFileService extends FileService {
  _FakeFileService(this.bytes) : super();

  final Uint8List bytes;
  int? downloadedFileId;

  @override
  Future<Uint8List> download(int fileId) async {
    downloadedFileId = fileId;
    return bytes;
  }
}
