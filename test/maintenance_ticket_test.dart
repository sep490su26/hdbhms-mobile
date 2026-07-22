// ignore_for_file: use_null_aware_elements

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_detail_screen.dart';
import 'package:hdbhms_mobile/services/maintenance/maintenance_ticket_service.dart';
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

  testWidgets('ticket list screen renders API tickets and search filter', (
    tester,
  ) async {
    final service = _ticketService();

    await tester.pumpWidget(
      MaterialApp(home: MaintenanceTicketListScreen(ticketService: service)),
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
      MaterialApp(home: MaintenanceTicketListScreen(ticketService: service)),
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
      MaterialApp(home: MaintenanceTicketListScreen(ticketService: service)),
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
        MaterialApp(home: MaintenanceTicketListScreen(ticketService: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chờ thanh toán'), findsOneWidget);
      expect(
        find.text('Đã hoàn tất xử lý · Cần thanh toán 2.000đ'),
        findsOneWidget,
      );
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

    final inProgress = MaintenanceTicketModel.fromJson(
      _ticketJson(status: 'IN_PROGRESS'),
    );
    final violation = MaintenanceTicketModel.fromJson(
      _ticketJson(
        category: 'RULE_VIOLATION',
        billingStatus: 'PENDING_PAYMENT',
        billingStatusLabel: 'Chờ thanh toán',
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(find.text('Xem hóa đơn / Thanh toán ngay'), findsNothing);
  });
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
