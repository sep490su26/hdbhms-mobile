import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/screens/contract/terminate_contract_screen.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeLeaseContractService extends LeaseContractService {
  _FakeLeaseContractService({this.error, this.pending});

  final Object? error;
  final Completer<LeaseContract>? pending;
  int calls = 0;
  int? contractId;
  String? intention;
  DateTime? expectedMoveOutDate;
  String? note;

  @override
  Future<LeaseContract> recordIntention({
    required int contractId,
    required String intention,
    DateTime? expectedMoveOutDate,
    String note = '',
  }) async {
    calls++;
    this.contractId = contractId;
    this.intention = intention;
    this.expectedMoveOutDate = expectedMoveOutDate;
    this.note = note;
    if (error case final Object error) throw error;
    if (pending case final Completer<LeaseContract> completer) {
      return completer.future;
    }
    return _contract(expectedVacantDate: expectedMoveOutDate);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'termination submit calls the real intention service before success',
    (tester) async {
      final service = _FakeLeaseContractService();
      var refreshed = false;

      await _pumpForm(
        tester,
        service,
        onSubmitted: (_) async => refreshed = true,
      );
      await tester.enterText(
        find.byKey(const Key('terminate-reason-field')),
        'Chuyển nơi làm việc',
      );
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(service.calls, 1);
      expect(service.contractId, 9);
      expect(service.intention, 'MOVE_OUT');
      expect(service.note, 'Chuyển nơi làm việc');
      expect(service.expectedMoveOutDate, isNotNull);
      expect(refreshed, isTrue);
      expect(find.text('Yêu cầu đã được gửi!'), findsOneWidget);
    },
  );

  testWidgets('duplicate response is shown and never displays fake success', (
    tester,
  ) async {
    final service = _FakeLeaseContractService(
      error: const LeaseContractException(
        'Hợp đồng đã có yêu cầu chuyển đi đang hiệu lực.',
      ),
    );

    await _pumpForm(tester, service);
    await tester.enterText(
      find.byKey(const Key('terminate-reason-field')),
      'Chuyển nơi ở',
    );
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Hợp đồng đã có yêu cầu chuyển đi đang hiệu lực.'),
      findsOneWidget,
    );
    expect(find.text('Yêu cầu đã được gửi!'), findsNothing);
  });

  testWidgets('network failure keeps the form open for retry', (tester) async {
    final service = _FakeLeaseContractService(
      error: const LeaseContractException('Không kết nối được máy chủ'),
    );

    await _pumpForm(tester, service);
    await tester.enterText(
      find.byKey(const Key('terminate-reason-field')),
      'Chuyển nơi ở',
    );
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Không kết nối được máy chủ'), findsOneWidget);
    expect(find.byKey(const Key('terminate-submit-button')), findsOneWidget);
    expect(find.text('Yêu cầu đã được gửi!'), findsNothing);
  });

  testWidgets('double tap sends only one termination request', (tester) async {
    final pending = Completer<LeaseContract>();
    final service = _FakeLeaseContractService(pending: pending);

    await _pumpForm(tester, service);
    await tester.enterText(
      find.byKey(const Key('terminate-reason-field')),
      'Chuyển nơi ở',
    );
    final submit = find.byKey(const Key('terminate-submit-button'));
    await tester.scrollUntilVisible(
      submit,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(service.calls, 1);

    pending.complete(_contract());
    await tester.pumpAndSettle();
    expect(find.text('Yêu cầu đã được gửi!'), findsOneWidget);
  });

  test('service maps backend 409 and network failures', () async {
    final conflictService = LeaseContractService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message':
                'MOVE_OUT_INTENTION_ALREADY_RECORDED: request already exists',
          }),
          409,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      conflictService.recordIntention(
        contractId: 9,
        intention: 'MOVE_OUT',
        expectedMoveOutDate: DateTime.now().add(const Duration(days: 2)),
        note: 'Relocating',
      ),
      throwsA(
        isA<LeaseContractException>().having(
          (error) => error.message,
          'message',
          contains('đã có yêu cầu chuyển đi'),
        ),
      ),
    );

    final networkService = LeaseContractService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      networkService.recordIntention(
        contractId: 9,
        intention: 'MOVE_OUT',
        expectedMoveOutDate: DateTime.now().add(const Duration(days: 2)),
        note: 'Relocating',
      ),
      throwsA(
        isA<LeaseContractException>().having(
          (error) => error.message,
          'message',
          contains('Không kết nối'),
        ),
      ),
    );
  });
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final submit = find.byKey(const Key('terminate-submit-button'));
  await tester.scrollUntilVisible(
    submit,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(submit);
}

Future<void> _pumpForm(
  WidgetTester tester,
  LeaseContractService service, {
  Future<void> Function(LeaseContract contract)? onSubmitted,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TerminateContractScreen(
        contractId: 9,
        contractCode: 'HD-201',
        contractEndDate: DateTime.now().add(const Duration(days: 30)),
        initialExpectedDate: DateTime.now().add(const Duration(days: 2)),
        contractService: service,
        onSubmitted: onSubmitted,
        notificationUnreadCount: 0,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

LeaseContract _contract({DateTime? expectedVacantDate}) {
  return LeaseContract(
    id: 9,
    contractCode: 'HD-201',
    status: 'ACTIVE',
    room: const LeaseRoom(
      roomCode: '201',
      roomName: 'Phòng 201',
      area: 45,
      imageUrl: '',
    ),
    monthlyRent: 2200000,
    paymentCycleMonths: 1,
    startDate: DateTime(2025),
    endDate: DateTime.now().add(const Duration(days: 30)),
    rentStartDate: DateTime(2025),
    depositAmount: 2200000,
    terms: const [],
    serviceFees: const [],
    contractFileUrl: '',
    tenantIntention: expectedVacantDate == null ? '' : 'MOVE_OUT',
    expectedVacantDate: expectedVacantDate,
  );
}
