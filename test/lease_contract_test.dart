import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/screens/contract/lease_contract_screen.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLeaseContractService extends LeaseContractService {
  const _FakeLeaseContractService({
    this.contract,
    this.error,
    this.onRecordIntention,
  });

  final LeaseContract? contract;
  final Object? error;
  final void Function(
    int contractId,
    String intention,
    DateTime? expectedMoveOutDate,
    String note,
  )?
  onRecordIntention;

  @override
  Future<LeaseContract> getMyActiveContract({int? tenantId}) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return contract!;
  }

  @override
  Future<LeaseContract> recordIntention({
    required int contractId,
    required String intention,
    DateTime? expectedMoveOutDate,
    String note = '',
  }) async {
    onRecordIntention?.call(contractId, intention, expectedMoveOutDate, note);
    return contract!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'LeaseContractService loads active contract from current-user endpoint',
    () async {
      SharedPreferences.setMockInitialValues({
        AuthService.accessTokenKey: 'token-123',
        AuthService.tenantIdKey: 23,
      });

      final service = LeaseContractService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/lease-contracts/me');
          expect(request.url.queryParameters['status'], 'ACTIVE');
          expect(request.url.queryParameters['size'], '1');

          return http.Response(
            jsonEncode({
              'data': {
                'data': [
                  {
                    'id': 9,
                    'contract_code': 'HD-201',
                    'status': 'ACTIVE',
                    'room': {
                      'room_code': '201',
                      'room_name': 'Phòng 201',
                      'area': 45,
                    },
                    'monthly_rent': 2200000,
                    'payment_cycle_months': 1,
                    'start_date': '2024-01-01',
                    'end_date': '2026-07-01',
                    'deposit_amount': 2200000,
                    'terms': ['Thanh toán tiền thuê đúng hạn.'],
                    'service_fee': 50000,
                  },
                ],
                'page': 0,
                'size': 1,
                'totalElements': 1,
                'totalPages': 1,
                'last': true,
                'first': true,
                'empty': false,
                'sort': {'empty': true, 'sorted': false, 'unsorted': true},
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final contract = await service.getMyActiveContract();

      expect(contract.room.roomCode, '201');
      expect(contract.monthlyRent, 2200000);
      expect(contract.expectedTotal, 2250000);
      expect(contract.terms.single, 'Thanh toán tiền thuê đúng hạn.');
    },
  );

  testWidgets('contract screen shows expiring warning and room 201 data', (
    tester,
  ) async {
    final contract = _contract(
      endDate: DateTime.now().add(const Duration(days: 30)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeaseContractScreen(
          contractService: _FakeLeaseContractService(contract: contract),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thông tin hợp đồng'), findsOneWidget);
    expect(find.text('HĐ sắp hết hạn, vui lòng phản hồi'), findsOneWidget);
    expect(find.text('Phòng 201'), findsOneWidget);
    expect(find.text('2.200.000đ/tháng'), findsOneWidget);
    expect(find.text('Điều khoản chính'), findsOneWidget);
    expect(find.text('Quản lý tài liệu'), findsOneWidget);
  });

  testWidgets(
    'contract screen warns before terminate flow when contract has less than one month left',
    (tester) async {
      final contract = _contract(
        endDate: DateTime.now().add(const Duration(days: 20)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LeaseContractScreen(
            contractService: _FakeLeaseContractService(contract: contract),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Thanh lý\nhợp đồng'));
      await tester.tap(find.text('Thanh lý\nhợp đồng'));
      await tester.pumpAndSettle();

      expect(find.text('Hợp đồng còn dưới 1 tháng'), findsOneWidget);
      expect(find.text('Tạo yêu cầu hủy'), findsOneWidget);

      await tester.tap(find.text('Tạo yêu cầu hủy'));
      await tester.pumpAndSettle();

      expect(find.text('Thanh lý hợp đồng'), findsOneWidget);
      expect(find.text('HD-201'), findsOneWidget);
      expect(find.text('Hợp đồng còn dưới 1 tháng'), findsOneWidget);
    },
  );

  testWidgets(
    'contract screen shows tenant intention dropdown and submits move out reason',
    (tester) async {
      String? recordedIntention;
      DateTime? recordedExpectedMoveOutDate;
      String? recordedNote;
      final moveOutDate = DateTime.now().add(const Duration(days: 30));
      final contract = _contract(
        endDate: moveOutDate,
        isPrimary: true,
        canRecordIntention: true,
        tenantIntention: 'MOVE_OUT',
        expectedVacantDate: moveOutDate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LeaseContractScreen(
            contractService: _FakeLeaseContractService(
              contract: contract,
              onRecordIntention:
                  (contractId, intention, expectedMoveOutDate, note) {
                    recordedIntention = intention;
                    recordedExpectedMoveOutDate = expectedMoveOutDate;
                    recordedNote = note;
                  },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ý định'), findsOneWidget);
      expect(find.text('Chuyển đi / Không tái ký'), findsOneWidget);
      expect(find.text('Ngày dự kiến chuyển đi'), findsOneWidget);
      expect(find.text('Lý do'), findsOneWidget);

      await tester.ensureVisible(find.text('Lưu ý định'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Gia đình chuyển đi');
      await tester.tap(find.text('Lưu ý định'));
      await tester.pumpAndSettle();

      expect(recordedIntention, 'MOVE_OUT');
      expect(recordedExpectedMoveOutDate, contract.endDate);
      expect(recordedNote, 'Gia đình chuyển đi');
    },
  );

  testWidgets('contract screen shows empty state with retry', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LeaseContractScreen(
          contractService: _FakeLeaseContractService(
            error: LeaseContractNotFoundException(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Bạn chưa có hợp đồng thuê phòng đang hiệu lực'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });
}

LeaseContract _contract({
  DateTime? endDate,
  bool isPrimary = false,
  bool canRecordIntention = false,
  String tenantIntention = '',
  DateTime? expectedVacantDate,
}) {
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
    startDate: DateTime(2024),
    endDate: endDate ?? DateTime(2026, 7),
    rentStartDate: DateTime(2024),
    depositAmount: 2200000,
    terms: const ['Thanh toán tiền thuê đúng hạn.'],
    serviceFees: const [
      LeaseServiceFee(name: 'Phí dịch vụ (cố định)', amount: 50000),
    ],
    contractFileUrl: '',
    tenantIntention: tenantIntention,
    expectedVacantDate: expectedVacantDate,
    roleInContract: isPrimary ? 'PRIMARY' : '',
    isPrimary: isPrimary,
    canRecordIntention: canRecordIntention,
  );
}
