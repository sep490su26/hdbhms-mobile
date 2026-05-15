import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/app.dart';

void main() {
  testWidgets('shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('resident@complex.com'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('opens overview after login', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    await tester.ensureVisible(find.byType(ElevatedButton).last);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(find.text('Tr\u1EA1ng th\u00E1i thanh to\u00E1n'), findsOneWidget);
    expect(find.text('\u0110i\u1EC7n & N\u01B0\u1EDBc'), findsOneWidget);
    expect(find.text('Nguy\u1EC5n V\u0103n A'), findsOneWidget);
    expect(find.text('2.200.000'), findsOneWidget);
  });

  testWidgets('opens bill selection from payment CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    await tester.ensureVisible(find.byType(ElevatedButton).last);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thanh to\u00E1n ngay'));
    await tester.pumpAndSettle();

    expect(find.text('Ch\u1ECDn h\u00F3a \u0111\u01A1n'), findsOneWidget);
    expect(find.text('SELECT ALL PENDING'), findsOneWidget);
    expect(find.text('Thanh to\u00E1n'), findsOneWidget);
  });

  testWidgets('opens QR payment from bill selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    await tester.ensureVisible(find.byType(ElevatedButton).last);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thanh to\u00E1n ngay'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thanh to\u00E1n'));
    await tester.pumpAndSettle();

    expect(find.text('Thanh to\u00E1n h\u00F3a \u0111\u01A1n'), findsOneWidget);
    expect(find.text('2.450.000\u0111'), findsOneWidget);
    expect(find.text('RESIDENT_99283_JULY'), findsOneWidget);
    expect(find.text('T\u00F4i \u0111\u00E3 thanh to\u00E1n'), findsOneWidget);
  });

  testWidgets('opens payment success after confirming paid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    await tester.ensureVisible(find.byType(ElevatedButton).last);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thanh to\u00E1n ngay'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thanh to\u00E1n'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.text('T\u00F4i \u0111\u00E3 thanh to\u00E1n'),
    );
    await tester.tap(find.text('T\u00F4i \u0111\u00E3 thanh to\u00E1n'));
    await tester.pumpAndSettle();

    expect(find.text('Thanh to\u00E1n th\u00E0nh c\u00F4ng!'), findsOneWidget);
    expect(find.text('#TXN-882910'), findsOneWidget);
    expect(find.text('800.000 \u0111'), findsOneWidget);
    expect(find.text('Quay l\u1EA1i trang ch\u1EE7'), findsOneWidget);
  });

  testWidgets('opens payment history from success page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    await tester.ensureVisible(find.byType(ElevatedButton).last);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thanh to\u00E1n ngay'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thanh to\u00E1n'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.text('T\u00F4i \u0111\u00E3 thanh to\u00E1n'),
    );
    await tester.tap(find.text('T\u00F4i \u0111\u00E3 thanh to\u00E1n'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Xem l\u1ECBch s\u1EED'));
    await tester.tap(find.text('Xem l\u1ECBch s\u1EED'));
    await tester.pumpAndSettle();

    expect(find.text('L\u1ECBch s\u1EED thanh to\u00E1n'), findsOneWidget);
    expect(find.text('T\u00ECm ki\u1EBFm..'), findsOneWidget);
    expect(find.text('Th\u00E1ng 2 2023'), findsOneWidget);
    expect(find.text('S\u1EEDa t\u1EE7 l\u1EA1nh'), findsOneWidget);
  });
}
