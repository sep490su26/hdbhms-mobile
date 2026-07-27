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
    this.submitRenewalError,
    this.onSubmitRenewal,
  });

  final LeaseContract? contract;
  final Object? error;
  final Object? submitRenewalError;
  final void Function(
    int contractId,
    DateTime newStartDate,
    DateTime newEndDate,
    int renewalTermMonths,
    num monthlyRent,
    int paymentCycleMonths,
    num depositAmount,
    String note,
  )?
  onSubmitRenewal;

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
    return contract!;
  }

  @override
  Future<void> submitLiquidationRequest({
    required int contractId,
    DateTime? liquidationDate,
    String reason = '',
  }) async {
    return;
  }

  @override
  Future<void> submitRenewalRequest({
    required int contractId,
    required DateTime newStartDate,
    required DateTime newEndDate,
    required int renewalTermMonths,
    required num monthlyRent,
    required int paymentCycleMonths,
    required num depositAmount,
    String note = '',
  }) async {
    final error = submitRenewalError;
    if (error != null) {
      throw error;
    }
    onSubmitRenewal?.call(
      contractId,
      newStartDate,
      newEndDate,
      renewalTermMonths,
      monthlyRent,
      paymentCycleMonths,
      depositAmount,
      note,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dedupe active rooms ignores transferred source contracts', () {
    final rooms = dedupeActiveRoomsByRoom([
      ActiveRoomItem(
        contractId: 18,
        contractCode: 'HD-101-OLD',
        roomId: 101,
        roomCode: '101',
        roomName: 'Phong 101',
        propertyName: 'CS1',
        contractStatus: 'TRANSFERRED',
        startDate: DateTime(2026, 1),
      ),
      ActiveRoomItem(
        contractId: 24,
        contractCode: 'HD-101-NEW',
        roomId: 101,
        roomCode: '101',
        roomName: 'Phong 101',
        propertyName: 'CS1',
        contractStatus: 'ACTIVE',
        startDate: DateTime(2026, 7),
      ),
      ActiveRoomItem(
        contractId: 12,
        contractCode: 'HD-102-EXPIRED',
        roomId: 102,
        roomCode: '102',
        roomName: 'Phong 102',
        propertyName: 'CS1',
        contractStatus: 'EXPIRED',
        startDate: DateTime(2025, 1),
      ),
    ]);

    expect(rooms, hasLength(1));
    expect(rooms.single.contractId, 24);
  });

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

  test('LeaseContractService submits add co-occupant request', () async {
    SharedPreferences.setMockInitialValues({
      AuthService.accessTokenKey: 'token-123',
      AuthService.tenantIdKey: 23,
    });

    final service = LeaseContractService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/lease-contracts/9/co-occupant-requests',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['fullName'], 'Nguyen Van B');
        expect(body['phone'], '0912345678');
        expect(body['email'], 'b@example.com');
        expect(body['note'], 'O cung tu thang nay');

        return http.Response(
          jsonEncode({
            'data': {
              'id': 99,
              'requestType': 'ADD_CO_OCCUPANT',
              'status': 'PENDING',
            },
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await service.submitAddCoOccupantRequest(
      contractId: 9,
      fullName: 'Nguyen Van B',
      phone: '0912345678',
      email: 'b@example.com',
      note: 'O cung tu thang nay',
    );
  });

  test('LeaseContractService submits liquidation date', () async {
    SharedPreferences.setMockInitialValues({
      AuthService.accessTokenKey: 'token-123',
      AuthService.tenantIdKey: 23,
    });

    final service = LeaseContractService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/lease-contracts/9/liquidation-requests',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['liquidationDate'], '2026-08-15');
        expect(body['reason'], 'Can thanh ly som');

        return http.Response(
          jsonEncode({
            'data': {
              'id': 99,
              'requestType': 'CONTRACT_LIQUIDATION',
              'status': 'PENDING',
            },
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await service.submitLiquidationRequest(
      contractId: 9,
      liquidationDate: DateTime(2026, 8, 15),
      reason: ' Can thanh ly som ',
    );
  });

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

  testWidgets('contract screen opens the full-screen liquidation form', (
    tester,
  ) async {
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

    await tester.ensureVisible(find.text('Thanh lý hợp đồng'));
    await tester.tap(find.text('Thanh lý hợp đồng'));
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu kết thúc hợp đồng'), findsOneWidget);
    expect(find.text('NGÀY THANH LÝ *'), findsOneWidget);
  });

  testWidgets('contract screen shows error when renewal request submit fails', (
    tester,
  ) async {
    final contract = _contract(
      endDate: DateTime.now().add(const Duration(days: 20)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeaseContractScreen(
          contractService: _FakeLeaseContractService(
            contract: contract,
            submitRenewalError: const LeaseContractException(
              'Hợp đồng đã có yêu cầu đang chờ duyệt.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Gia hạn hợp đồng'));
    await tester.tap(find.text('Gia hạn hợp đồng'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gửi yêu cầu gia hạn'));
    await tester.pumpAndSettle();

    expect(find.text('Hợp đồng đã có yêu cầu đang chờ duyệt.'), findsWidgets);
  });

  testWidgets('contract screen sends custom extension term months', (
    tester,
  ) async {
    int? submittedMonths;
    DateTime? submittedStartDate;
    DateTime? submittedEndDate;

    await tester.pumpWidget(
      MaterialApp(
        home: LeaseContractScreen(
          contractService: _FakeLeaseContractService(
            contract: _contract(endDate: DateTime(2026, 7, 31)),
            onSubmitRenewal:
                (
                  contractId,
                  newStartDate,
                  newEndDate,
                  renewalTermMonths,
                  monthlyRent,
                  paymentCycleMonths,
                  depositAmount,
                  note,
                ) {
                  submittedMonths = renewalTermMonths;
                  submittedStartDate = newStartDate;
                  submittedEndDate = newEndDate;
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Gia hạn hợp đồng'));
    await tester.tap(find.text('Gia hạn hợp đồng'));
    await tester.pumpAndSettle();

    final termField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Nhập số tháng khác',
    );
    await tester.enterText(termField, '18');
    await tester.tap(find.text('Gửi yêu cầu gia hạn'));
    await tester.pumpAndSettle();

    expect(submittedMonths, 18);
    expect(submittedStartDate, DateTime(2026, 8, 1));
    expect(submittedEndDate, DateTime(2028, 1, 31));
  });

  testWidgets('contract screen blocks extension term under 6 months', (
    tester,
  ) async {
    int? submittedMonths;

    await tester.pumpWidget(
      MaterialApp(
        home: LeaseContractScreen(
          contractService: _FakeLeaseContractService(
            contract: _contract(endDate: DateTime(2026, 7, 31)),
            onSubmitRenewal:
                (
                  contractId,
                  newStartDate,
                  newEndDate,
                  renewalTermMonths,
                  monthlyRent,
                  paymentCycleMonths,
                  depositAmount,
                  note,
                ) {
                  submittedMonths = renewalTermMonths;
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Gia hạn hợp đồng'));
    await tester.tap(find.text('Gia hạn hợp đồng'));
    await tester.pumpAndSettle();

    final termField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Nhập số tháng khác',
    );
    await tester.enterText(termField, '5');
    await tester.tap(find.text('Gửi yêu cầu gia hạn'));
    await tester.pumpAndSettle();

    expect(submittedMonths, isNull);
    expect(find.text('Thời hạn gia hạn tối thiểu 6 tháng.'), findsWidgets);
  });

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

LeaseContract _contract({DateTime? endDate, bool isPrimary = false}) {
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
    roleInContract: isPrimary ? 'PRIMARY' : '',
    isPrimary: isPrimary,
  );
}
