import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/app_list_state.dart';

void main() {
  testWidgets('error retry stays primary and uses a refresh icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppListState(
            kind: AppListStateKind.error,
            title: 'Không tải được dữ liệu',
            description: 'Thử lại sau.',
            actionLabel: 'Thử lại',
            actionIcon: Icons.refresh_rounded,
            onAction: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.primary,
    );
  });

  testWidgets('clear-filter empty state uses the filter-off semantic icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppListState(
            kind: AppListStateKind.empty,
            title: 'Không có kết quả',
            description: 'Hãy thay đổi bộ lọc.',
            actionLabel: 'Xóa bộ lọc',
            actionIcon: Icons.filter_alt_off_rounded,
            actionStyle: AppListStateActionStyle.secondary,
            onAction: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.filter_alt_off_rounded), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
