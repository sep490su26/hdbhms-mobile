import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';

void main() {
  testWidgets('bottom navigation presents the overview dashboard item', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: TenantBottomNavigation(
            activeTab: TenantBottomNavTab.home,
          ),
        ),
      ),
    );

    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
    expect(find.text('Trang chủ'), findsNothing);
  });
}
