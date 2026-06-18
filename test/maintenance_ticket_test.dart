import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/services/maintenance/maintenance_ticket_service.dart';

void main() {
  test('MaintenanceTicketService filters mock tickets locally', () async {
    const service = MaintenanceTicketService();

    final byKeyword = await service.getTickets(keyword: '#SC-2825');
    expect(byKeyword, hasLength(1));
    expect(byKeyword.single.code, '#SC-2825');

    final byStatus = await service.getTickets(status: 'Hoàn tất');
    expect(byStatus, hasLength(1));
    expect(byStatus.single.code, '#SC-2825');

    final byCategory = await service.getTickets(category: 'Nước');
    expect(byCategory, hasLength(1));
    expect(byCategory.single.code, '#SC-2805');
  });

  testWidgets('ticket list screen renders mock tickets and search filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MaintenanceTicketListScreen()),
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

  testWidgets('ticket list screen can filter by status dropdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MaintenanceTicketListScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn tất').last);
    await tester.pumpAndSettle();
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
      const MaterialApp(home: MaintenanceTicketListScreen()),
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

Finder _ticketCodeFinder(String code) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == code,
  );
}
