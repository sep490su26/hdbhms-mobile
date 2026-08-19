import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/screens/payment/payment_preview_page.dart';
import 'package:hdbhms_mobile/screens/payment/post_liquidation_home_access_preview_screen.dart';

void main() {
  testWidgets('preview reuses the actual Home access-error state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PostLiquidationHomeAccessPreviewScreen()),
    );

    expect(find.byKey(const ValueKey('home-error-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-error-message')), findsOneWidget);
    expect(
      find.textContaining('không còn quyền truy cập P.203'),
      findsOneWidget,
    );
    expect(find.text('Quyền truy cập phòng đã kết thúc'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-error-open-rooms')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-error-retry')), findsOneWidget);
  });

  testWidgets('payment preview opens the Home access-error state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PaymentPreviewPage()));
    await tester.pumpAndSettle();

    final tile = find.text('Home: không còn quyền truy cập phòng');
    await tester.scrollUntilVisible(
      tile,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byType(PostLiquidationHomeAccessPreviewScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('home-error-card')), findsOneWidget);
  });
}
