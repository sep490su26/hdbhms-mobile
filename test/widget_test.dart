import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/app.dart';
import 'package:hdbhms_mobile/screens/identity_verification_page.dart';

Future<void> loginAndCompleteIdentity(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(ElevatedButton).last);
  await tester.tap(find.byType(ElevatedButton).last);
  await tester.pumpAndSettle();

  expect(find.text('X\u00E1c th\u1EF1c danh t\u00EDnh'), findsOneWidget);

  for (var i = 0; i < 3; i++) {
    await tester.ensureVisible(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.tap(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.pumpAndSettle();
  }

  await tester.tap(find.widgetWithText(ElevatedButton, 'Ti\u1EBFp t\u1EE5c'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('resident@complex.com'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('opens overview after login', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    await loginAndCompleteIdentity(tester);

    expect(find.text('Tr\u1EA1ng th\u00E1i thanh to\u00E1n'), findsOneWidget);
    expect(find.text('\u0110i\u1EC7n & N\u01B0\u1EDBc'), findsOneWidget);
    expect(find.text('Nguy\u1EC5n V\u0103n A'), findsOneWidget);
    expect(find.text('2.200.000'), findsOneWidget);
  });

  testWidgets('opens bill selection from payment CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    await loginAndCompleteIdentity(tester);

    await tester.tap(find.text('Thanh to\u00E1n ngay'));
    await tester.pumpAndSettle();

    expect(find.text('H\u00F3a \u0111\u01A1n'), findsOneWidget);
    expect(
      find.text('H\u00D3A \u0110\u01A0N \u0110\u00C3 THANH TO\u00C1N'),
      findsOneWidget,
    );
    expect(find.text('View All Historical Data'), findsOneWidget);
  });

  testWidgets('opens bill selection from bottom Bills tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    await loginAndCompleteIdentity(tester);

    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();

    expect(find.text('H\u00F3a \u0111\u01A1n'), findsOneWidget);
    expect(find.text('Ti\u1EC1n ph\u00F2ng'), findsNWidgets(2));
    expect(find.text('View All Historical Data'), findsOneWidget);
  });

  testWidgets('opens QR payment from bill selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    await loginAndCompleteIdentity(tester);

    await tester.tap(find.text('Thanh to\u00E1n ngay'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ti\u1EC1n ph\u00F2ng').first);
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

    await loginAndCompleteIdentity(tester);

    await tester.tap(find.text('Thanh to\u00E1n ngay'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ti\u1EC1n ph\u00F2ng').first);
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

    await loginAndCompleteIdentity(tester);

    await tester.tap(find.text('Thanh to\u00E1n ngay'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ti\u1EC1n ph\u00F2ng').first);
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

  testWidgets('opens payment history from bill selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    await loginAndCompleteIdentity(tester);

    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('View All Historical Data'));
    await tester.tap(find.text('View All Historical Data'));
    await tester.pumpAndSettle();

    expect(find.text('L\u1ECBch s\u1EED thanh to\u00E1n'), findsOneWidget);
    expect(find.text('T\u00ECm ki\u1EBFm..'), findsOneWidget);
    expect(find.text('S\u1EEDa t\u1EE7 l\u1EA1nh'), findsOneWidget);
  });

  testWidgets('bottom Home tab returns from bill selection to home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    await loginAndCompleteIdentity(tester);

    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Tr\u1EA1ng th\u00E1i thanh to\u00E1n'), findsOneWidget);
    expect(find.text('Nguy\u1EC5n V\u0103n A'), findsOneWidget);
  });

  testWidgets('bottom Home tab returns from payment history to home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    await loginAndCompleteIdentity(tester);

    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('View All Historical Data'));
    await tester.tap(find.text('View All Historical Data'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Tr\u1EA1ng th\u00E1i thanh to\u00E1n'), findsOneWidget);
    expect(find.text('Nguy\u1EC5n V\u0103n A'), findsOneWidget);
  });

  testWidgets('identity verification requires three images before continuing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: IdentityVerificationPage()),
    );

    final continueButton = find.widgetWithText(
      ElevatedButton,
      'Ti\u1EBFp t\u1EE5c',
    );
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);

    await tester.ensureVisible(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.tap(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.pumpAndSettle();
    expect(find.text('CCCD m\u1EB7t tr\u01B0\u1EDBc'), findsWidgets);
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);

    await tester.ensureVisible(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.tap(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.pumpAndSettle();
    expect(find.text('CCCD m\u1EB7t sau'), findsWidgets);
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);

    await tester.ensureVisible(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.tap(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.pumpAndSettle();
    expect(find.text('X\u00E1c nh\u1EADn h\u1ED3 s\u01A1'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNotNull);

    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        '\u0110\u00E3 \u0111\u1EE7 \u1EA3nh, chuy\u1EC3n sang b\u01B0\u1EDBc x\u00E1c nh\u1EADn',
      ),
      findsOneWidget,
    );
  });

  testWidgets('identity verification back button returns to previous step', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: IdentityVerificationPage()),
    );

    await tester.ensureVisible(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.tap(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.pumpAndSettle();

    expect(find.text('CCCD m\u1EB7t tr\u01B0\u1EDBc'), findsWidgets);

    await tester.tap(find.text('Tr\u1EDF v\u1EC1'));
    await tester.pumpAndSettle();

    expect(find.text('\u1EA2nh ch\u00E2n dung'), findsWidgets);
  });
}
