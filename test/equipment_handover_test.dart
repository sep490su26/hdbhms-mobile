import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/contract/handover_item_model.dart';
import 'package:hdbhms_mobile/models/contract/handover_record_model.dart';
import 'package:hdbhms_mobile/screens/contract/equipment_handover_screen.dart';
import 'package:hdbhms_mobile/services/contract/handover_service.dart';
import 'package:hdbhms_mobile/widgets/image_zoom_viewer.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHandoverService extends HandoverService {
  const _FakeHandoverService({this.record, this.error});

  final HandoverRecord? record;
  final Object? error;

  @override
  Future<HandoverRecord> getHandoverItems(
    int contractId, {
    String type = 'MOVE_IN',
  }) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return record!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HandoverItem.fromJson parses camelCase JSON correctly', () {
    final item = HandoverItem.fromJson({
      'id': 7,
      'assetName': 'Air conditioner',
      'quantity': 1,
      'conditionStatus': 'GOOD',
      'note': 'Remote included',
      'evidenceFileId': 44,
      'evidenceFileUrl': '/api/v1/files/download/44',
    });

    expect(item.assetName, 'Air conditioner');
    expect(item.quantity, 1);
    expect(item.conditionStatus, 'GOOD');
    expect(item.evidenceFileId, 44);
  });

  test('HandoverItem.fromJson parses snake_case JSON correctly', () {
    final item = HandoverItem.fromJson({
      'handover_item_id': 8,
      'asset_name': 'Desk',
      'quantity': 2,
      'condition_status': 'ATTENTION',
      'note': 'Small scratch',
      'evidence_file_id': 55,
      'evidence_file_url': '/api/v1/files/download/55',
    });

    expect(item.id, 8);
    expect(item.assetName, 'Desk');
    expect(item.conditionStatus, 'ATTENTION');
    expect(item.evidenceFileUrl, '/api/v1/files/download/55');
  });

  test('HandoverRecord.fromJson handles empty items list', () {
    final record = HandoverRecord.fromJson({
      'handoverRecordId': 5,
      'handoverType': 'MOVE_IN',
      'status': 'CONFIRMED',
      'handoverDate': '2026-01-02T09:00:00',
      'items': [],
    });

    expect(record.handoverRecordId, 5);
    expect(record.items, isEmpty);
    expect(record.handoverDate, DateTime(2026, 1, 2, 9));
  });

  test('HandoverService returns data on 200 OK', () async {
    SharedPreferences.setMockInitialValues({});
    final service = HandoverService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/tenant/contracts/9/handover-items');
        expect(request.url.queryParameters['type'], 'MOVE_IN');
        return http.Response(jsonEncode({'data': _recordJson()}), 200);
      }),
    );

    final record = await service.getHandoverItems(9);

    expect(record.items.single.assetName, 'Air conditioner');
    expect(record.isFromCache, isFalse);
  });

  test('HandoverService throws HandoverNotFoundException on 404', () async {
    SharedPreferences.setMockInitialValues({});
    final service = HandoverService(
      client: MockClient((request) async => http.Response('{}', 404)),
    );

    expect(
      () => service.getHandoverItems(9),
      throwsA(isA<HandoverNotFoundException>()),
    );
  });

  test('HandoverService throws on timeout when cache is empty', () async {
    SharedPreferences.setMockInitialValues({});
    final service = HandoverService(
      client: MockClient((request) async {
        throw TimeoutException('slow');
      }),
    );

    expect(
      () => service.getHandoverItems(9),
      throwsA(isA<HandoverException>()),
    );
  });

  test('HandoverService loads from cache on network error', () async {
    SharedPreferences.setMockInitialValues({
      'handover_cache_9': jsonEncode({'data': _recordJson()}),
    });
    final service = HandoverService(
      client: MockClient((request) async {
        throw http.ClientException('offline');
      }),
    );

    final record = await service.getHandoverItems(9);

    expect(record.isFromCache, isTrue);
    expect(record.items.single.assetName, 'Air conditioner');
  });

  test('HandoverService caches data on successful fetch', () async {
    SharedPreferences.setMockInitialValues({});
    final service = HandoverService(
      client: MockClient(
        (request) async =>
            http.Response(jsonEncode({'data': _recordJson()}), 200),
      ),
    );

    await service.getHandoverItems(9);
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString('handover_cache_9'), isNotNull);
  });

  testWidgets('EquipmentHandoverScreen shows empty state when no items', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentHandoverScreen(
          contractId: 9,
          handoverService: _FakeHandoverService(
            record: _record(items: const []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có thông tin thiết bị bàn giao'), findsOneWidget);
  });

  testWidgets('EquipmentHandoverScreen shows equipment list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentHandoverScreen(
          contractId: 9,
          handoverService: _FakeHandoverService(record: _record()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Air conditioner'), findsOneWidget);
    expect(find.text('Số lượng: 1'), findsOneWidget);
    expect(find.text('Tốt'), findsOneWidget);
  });

  testWidgets('EquipmentHandoverScreen shows error state on failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EquipmentHandoverScreen(
          contractId: 9,
          handoverService: _FakeHandoverService(
            error: HandoverException('Máy chủ bận'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Máy chủ bận'), findsOneWidget);
  });

  testWidgets('tapping image opens ImageZoomViewer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EquipmentHandoverScreen(
          contractId: 9,
          handoverService: _FakeHandoverService(record: _record()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AuthenticatedImage));
    await tester.pumpAndSettle();

    expect(find.byType(ImageZoomViewer), findsOneWidget);
  });
}

Map<String, dynamic> _recordJson({List<Map<String, dynamic>>? items}) {
  return {
    'handoverRecordId': 5,
    'handoverType': 'MOVE_IN',
    'status': 'CONFIRMED',
    'handoverDate': '2026-01-02T09:00:00',
    'items':
        items ??
        [
          {
            'id': 7,
            'assetName': 'Air conditioner',
            'quantity': 1,
            'conditionStatus': 'GOOD',
            'note': 'Remote included',
            'evidenceFileId': 44,
            'evidenceFileUrl': '/api/v1/files/download/44',
          },
        ],
  };
}

HandoverRecord _record({List<HandoverItem>? items}) {
  return HandoverRecord(
    handoverRecordId: 5,
    handoverType: 'MOVE_IN',
    status: 'CONFIRMED',
    handoverDate: DateTime(2026, 1, 2, 9),
    note: '',
    signedDocumentId: null,
    items:
        items ??
        const [
          HandoverItem(
            id: 7,
            assetName: 'Air conditioner',
            quantity: 1,
            conditionStatus: 'GOOD',
            note: 'Remote included',
            evidenceFileId: 44,
            evidenceFileUrl: '/api/v1/files/download/44',
          ),
        ],
  );
}
