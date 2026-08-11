import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/models/contract/contract_list_item_model.dart';
import 'package:hdbhms_mobile/screens/contract/lease_contract_list_screen.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';

class _FakeLeaseContractListService extends LeaseContractService {
  _FakeLeaseContractListService(this.items);

  final List<ContractListItem> items;
  final List<String?> requestedStatuses = [];

  @override
  Future<List<ContractListItem>> getMyContracts({
    String? status,
    DateTime? signedFrom,
    DateTime? signedTo,
  }) async {
    requestedStatuses.add(status);
    return items;
  }
}

void main() {
  testWidgets('lease filter keeps hierarchy and reset inside its filter card', (
    tester,
  ) async {
    final service = _FakeLeaseContractListService([
      ContractListItem(
        id: 1,
        contractCode: 'HD-001',
        roomCode: 'P.101',
        signedAt: DateTime(2026, 8, 1),
        status: 'ACTIVE',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LeaseContractListScreen(
            embeddedMode: true,
            contractService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tất cả hợp đồng'), findsOneWidget);
    expect(find.text('Bộ lọc'), findsOneWidget);
    expect(find.bySemanticsLabel('Xóa bộ lọc'), findsNothing);

    await tester.tap(find.text('Trạng thái').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Đang hiệu lực'));
    await tester.pumpAndSettle();

    expect(service.requestedStatuses.last, 'ACTIVE');
    expect(find.bySemanticsLabel('Xóa bộ lọc'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Xóa bộ lọc'));
    await tester.pumpAndSettle();

    expect(service.requestedStatuses.last, isNull);
    expect(find.bySemanticsLabel('Xóa bộ lọc'), findsNothing);
  });

  testWidgets('lease filter is overflow-free at supported mobile widths', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;

    for (final size in const [
      Size(320, 640),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaseContractListScreen(
              embeddedMode: true,
              contractService: _FakeLeaseContractListService(const []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'viewport $size');
    }
  });
}
