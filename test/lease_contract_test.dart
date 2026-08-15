import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/change_request/change_request_model.dart';
import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/screens/contract/lease_contract_screen.dart';
import 'package:hdbhms_mobile/screens/contract/renew_contract_request_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/change_request/change_request_service.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/home/current_room_service.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLeaseContractService extends LeaseContractService {
  const _FakeLeaseContractService({
    this.contract,
    this.error,
    this.submitRenewalError,
    this.onSubmitRenewal,
    this.onRecordOccupantIntention,
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
  final void Function(int contractId, String intention, String note)?
  onRecordOccupantIntention;

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
  Future<LeaseContract> recordOccupantIntention({
    required int contractId,
    required String intention,
    String note = '',
  }) async {
    onRecordOccupantIntention?.call(contractId, intention, note);
    return contract!;
  }

  @override
  Future<void> submitLiquidationRequest({
    required int contractId,
    DateTime? liquidationDate,
    String reason = '',
    String? liquidationMode,
    List<int> leavingProfileIds = const [],
    List<int> stayingProfileIds = const [],
    int? replacementPrimaryTenantProfileId,
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

class _FakeChangeRequestService extends ChangeRequestService {
  const _FakeChangeRequestService(this.requests);

  final List<ChangeRequest> requests;

  @override
  Future<List<ChangeRequest>> getMyRequests({
    ChangeRequestType? type,
    ChangeRequestStatus? status,
    String? search,
    int? roomId,
    String? roomCode,
    int page = 0,
    int size = 50,
  }) async {
    return requests
        .where((request) => type == null || request.requestType == type)
        .where((request) => status == null || request.status == status)
        .toList(growable: false);
  }
}

class _NoCurrentRoomService extends CurrentRoomService {
  const _NoCurrentRoomService();

  @override
  Future<CurrentRentedRoom> getCurrentRentedRoom() async {
    throw const LeaseContractNotFoundException();
  }
}

class _EmptyRoomTransferService extends RoomTransferService {
  const _EmptyRoomTransferService();

  @override
  Future<List<RoomTransferRequest>> fetchPendingHolderNominations() async {
    return const [];
  }
}

class _FakeRoomTransferService extends RoomTransferService {
  const _FakeRoomTransferService(this.transfers);

  final Map<int, RoomTransferRequest> transfers;

  @override
  Future<RoomTransferRequest> getTransferRequest(int requestId) async {
    final transfer = transfers[requestId];
    if (transfer == null) {
      throw const RoomTransferException('Not found');
    }
    return transfer;
  }

  @override
  Future<List<RoomTransferRequest>> fetchPendingHolderNominations() async {
    return const [];
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

  test(
    'LeaseContractService submits liquidation request with occupant payload',
    () async {
      final service = LeaseContractService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/v1/lease-contracts/9/liquidation-requests',
          );

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['liquidationDate'], '2026-07-30');
          expect(body['reason'], 'Chuyen phong va nguoi o cung o lai');
          expect(body['liquidationMode'], 'PRIMARY_LEAVES_CO_OCCUPANT_STAYS');
          expect(body['leavingProfileIds'], [101]);
          expect(body['stayingProfileIds'], [202]);
          expect(body['replacementPrimaryTenantProfileId'], 202);

          return http.Response('{}', 200);
        }),
      );

      await service.submitLiquidationRequest(
        contractId: 9,
        liquidationDate: DateTime(2026, 7, 30),
        reason: 'Chuyen phong va nguoi o cung o lai',
        liquidationMode: 'PRIMARY_LEAVES_CO_OCCUPANT_STAYS',
        leavingProfileIds: [101],
        stayingProfileIds: [202],
        replacementPrimaryTenantProfileId: 202,
      );
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

  test('LeaseContractService records occupant intention', () async {
    SharedPreferences.setMockInitialValues({
      AuthService.accessTokenKey: 'token-123',
      AuthService.tenantIdKey: 23,
    });

    var callCount = 0;
    final service = LeaseContractService(
      client: MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/v1/lease-contracts/9/occupant-intention',
          );
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['intention'], 'JOIN_RENEWAL');
          expect(body['note'], 'O tiep neu hop dong moi duoc ky');

          return http.Response(
            jsonEncode({
              'data': {'id': 9},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/lease-contracts/9');
        return http.Response(
          jsonEncode({
            'data': {
              'id': 9,
              'contractCode': 'HD-201',
              'status': 'ACTIVE',
              'room': {'roomCode': '201', 'name': 'Phòng 201'},
              'occupantIntention': 'JOIN_RENEWAL',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final contract = await service.recordOccupantIntention(
      contractId: 9,
      intention: 'JOIN_RENEWAL',
      note: ' O tiep neu hop dong moi duoc ky ',
    );

    expect(contract.occupantIntention, 'JOIN_RENEWAL');
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

    expect(find.text('Cảnh báo mất cọc'), findsOneWidget);
    expect(
      find.textContaining(
        'Nếu thực hiện thanh lý khi hợp đồng còn dưới 1 tháng',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Tôi hiểu, tiếp tục'));
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu kết thúc hợp đồng'), findsOneWidget);
    expect(find.text('Ngày thanh lý'), findsOneWidget);
  });

  testWidgets('liquidation progress waits at approval for pending request', (
    tester,
  ) async {
    final request = ChangeRequest(
      id: 44,
      requestCode: 'CR-44',
      requestType: ChangeRequestType.contractLiquidation,
      title: 'Yeu cau thanh ly hop dong HD-TEST',
      description: 'Can thanh ly som',
      status: ChangeRequestStatus.pending,
      requesterId: 1,
      createdAt: DateTime(2026, 8, 1, 9),
      requestPayload: jsonEncode({
        'contractId': 9,
        'roomId': 201,
        'roomCode': '201',
        'liquidationDate': '2026-08-15',
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TenantRequestScreen(
          changeRequestService: _FakeChangeRequestService([request]),
          roomTransferService: const _EmptyRoomTransferService(),
          roomId: 201,
          roomCode: '201',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xem chi tiết').first);
    await tester.pumpAndSettle();

    expect(find.text('Ti\u1EBFn tr\u00ECnh thanh l\u00FD'), findsOneWidget);
    final approvalSubtitle = tester.widget<Text>(
      find.text('\u0110ang ch\u1EDD quy\u1EBFt \u0111\u1ECBnh'),
    );
    expect(approvalSubtitle.style?.fontWeight, FontWeight.w800);
    final laterSubtitles = tester.widgetList<Text>(
      find.text('Ch\u01B0a t\u1EDBi b\u01B0\u1EDBc n\u00E0y'),
    );
    expect(
      laterSubtitles.any((text) => text.style?.fontWeight == FontWeight.w800),
      isFalse,
    );
    await tester.pump(const Duration(seconds: 16));
  });

  testWidgets('liquidation refund confirmation shows tenant action', (
    tester,
  ) async {
    final request = ChangeRequest(
      id: 45,
      requestCode: 'CR-45',
      requestType: ChangeRequestType.contractLiquidation,
      title: 'Yeu cau thanh ly hop dong HD-TEST',
      description: 'Can thanh ly som',
      status: ChangeRequestStatus.processing,
      requesterId: 1,
      createdAt: DateTime(2026, 8, 1, 9),
      requestPayload: jsonEncode({
        'contractId': 9,
        'roomId': 201,
        'roomCode': '201',
        'liquidationDate': '2026-08-15',
        'liquidationStage': 'WAITING_PAYMENT',
        'depositRefundStatus': 'RECORDED_BY_MANAGER',
        'depositRefundAmount': 2000,
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TenantRequestScreen(
          changeRequestService: _FakeChangeRequestService([request]),
          roomTransferService: const _EmptyRoomTransferService(),
          roomId: 201,
          roomCode: '201',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu hoàn cọc'), findsOneWidget);
    await tester.tap(find.text('Xem chi tiết').first);
    await tester.pumpAndSettle();

    final refundSubtitle = tester.widget<Text>(
      find.text(
        'Ch\u1EDD b\u1EA1n x\u00E1c nh\u1EADn \u0111\u00E3 nh\u1EADn ti\u1EC1n \u00B7 2.000\u0111',
      ),
    );
    expect(refundSubtitle.style?.fontWeight, FontWeight.w800);
    expect(
      find.text('\u0110\u00E3 nh\u1EADn ti\u1EC1n c\u1ECDc'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 16));
  });

  testWidgets('liquidation request remains visible without an active room', (
    tester,
  ) async {
    final request = ChangeRequest(
      id: 49,
      requestCode: 'CR-49',
      requestType: ChangeRequestType.contractLiquidation,
      title: 'Yeu cau hoan coc thanh ly hop dong HD-TEST',
      description: 'Cho tenant xac nhan da nhan tien',
      status: ChangeRequestStatus.processing,
      requesterId: 1,
      createdAt: DateTime(2026, 8, 1, 9),
      requestPayload: jsonEncode({
        'contractId': 9,
        'roomCode': '201',
        'depositRefundStatus': 'APPROVED_WAITING_TENANT_CONFIRMATION',
        'depositRefundAmount': 2000,
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TenantRequestScreen(
          changeRequestService: _FakeChangeRequestService([request]),
          currentRoomService: const _NoCurrentRoomService(),
          roomTransferService: const _EmptyRoomTransferService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu hoàn cọc'), findsOneWidget);
    expect(find.text('Xem chi tiết'), findsNWidgets(2));
  });

  testWidgets(
    'holder replacement waits for replacement contract without refund action',
    (tester) async {
      final request = ChangeRequest(
        id: 46,
        requestCode: 'CR-46',
        requestType: ChangeRequestType.contractLiquidation,
        title: 'Yeu cau thanh ly hop dong HD-TEST',
        description: 'Doi nguoi dung ten',
        status: ChangeRequestStatus.processing,
        requesterId: 1,
        createdAt: DateTime(2026, 8, 1, 9),
        requestPayload: jsonEncode({
          'roomId': 201,
          'roomCode': '201',
          'liquidationMode': 'PRIMARY_LEAVES_CO_OCCUPANT_STAYS',
          'liquidationStage': 'WAITING_REPLACEMENT_CONTRACT',
          'depositRefundStatus': 'NOT_REQUIRED',
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TenantRequestScreen(
            changeRequestService: _FakeChangeRequestService([request]),
            roomTransferService: const _EmptyRoomTransferService(),
            roomId: 201,
            roomCode: '201',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem chi tiết').first);
      await tester.pumpAndSettle();

      expect(find.text('Hợp đồng thay thế'), findsOneWidget);
      expect(find.text('Đang chờ lập hợp đồng thay thế'), findsOneWidget);
      expect(find.text('Đã nhận tiền cọc'), findsNothing);
    },
  );

  testWidgets('request detail reads the BE co-occupant phone key', (
    tester,
  ) async {
    final requests = [
      ChangeRequest(
        id: 47,
        requestCode: 'CR-47',
        requestType: ChangeRequestType.addCoOccupant,
        title: 'Them nguoi o cung',
        description: '',
        status: ChangeRequestStatus.pending,
        requesterId: 1,
        createdAt: DateTime(2026, 8, 1),
        requestPayload: jsonEncode({
          'roomId': 201,
          'roomCode': '201',
          'fullName': 'Nguyen Van B',
          'phone': '0901234567',
          'email': 'b@example.com',
          'moveInDate': '2026-08-10',
          'note': 'Nguoi o cung moi',
        }),
      ),
      ChangeRequest(
        id: 48,
        requestCode: 'CR-48',
        requestType: ChangeRequestType.meterReadingCorrection,
        title: 'Khieu nai chi so dien',
        description: '',
        status: ChangeRequestStatus.pending,
        requesterId: 1,
        createdAt: DateTime(2026, 8, 1),
        requestPayload: jsonEncode({
          'roomId': 201,
          'roomCode': '201',
          'meterType': 'ELECTRICITY',
          'previousValue': 100,
          'currentValue': 150,
          'reportedCurrentValue': 130,
          'usageAmount': 50,
          'unitPrice': 3000,
          'lineAmount': 150000,
          'invoiceCode': 'INV-48',
          'billingPeriod': '2026-08',
          'description': 'Chi so dong ho thuc te',
        }),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: TenantRequestScreen(
          changeRequestService: _FakeChangeRequestService(requests),
          roomTransferService: const _EmptyRoomTransferService(),
          roomId: 201,
          roomCode: '201',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xem chi tiết').first);
    await tester.pumpAndSettle();
    expect(find.text('0901234567'), findsOneWidget);
    expect(find.text('b@example.com'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 16));
  });

  testWidgets('request detail derives simple progress from every API status', (
    tester,
  ) async {
    const resultLabels = {
      ChangeRequestStatus.pending: 'Chưa có kết quả',
      ChangeRequestStatus.underReview: 'Chưa có kết quả',
      ChangeRequestStatus.processing: 'Chưa có kết quả',
      ChangeRequestStatus.approved: 'Đã duyệt',
      ChangeRequestStatus.completed: 'Hoàn tất',
      ChangeRequestStatus.rejected: 'Bị từ chối',
      ChangeRequestStatus.cancelled: 'Đã hủy',
    };

    for (final entry in resultLabels.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: RequestDetailScreen(
            changeRequest: ChangeRequest(
              id: 60,
              requestCode: 'CR-60',
              requestType: ChangeRequestType.contractRenewal,
              title: 'Renewal request',
              description: '',
              status: entry.key,
              requesterId: 1,
              createdAt: DateTime(2026, 8, 1, 9),
              resolvedAt: entry.key.isTerminal
                  ? DateTime(2026, 8, 2, 10)
                  : null,
              requestPayload: jsonEncode({'roomCode': '201'}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsWidgets);
      if (entry.key.isTerminal) {
        expect(find.textContaining('02/08/2026 10:00'), findsWidgets);
      }
    }
  });

  testWidgets(
    'meter correction detail reads the supported payload keys and units',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RequestDetailScreen(
            changeRequest: ChangeRequest(
              id: 61,
              requestCode: 'CR-61',
              requestType: ChangeRequestType.meterReadingCorrection,
              title: 'Meter correction',
              description: '',
              status: ChangeRequestStatus.pending,
              requesterId: 1,
              createdAt: DateTime(2026, 8, 1),
              requestPayload: jsonEncode({
                'meterType': 'ELECTRICITY',
                'previousValue': 100,
                'currentValue': 150,
                'reportedCurrentValue': 130,
                'usageAmount': 50,
                'unitPrice': 3000,
                'lineAmount': 150000,
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100 kWh'), findsOneWidget);
      expect(find.text('150 kWh'), findsOneWidget);
      expect(find.text('130 kWh'), findsOneWidget);
      expect(find.text('50 kWh'), findsOneWidget);
      expect(find.text('3000 đ/kWh'), findsOneWidget);
      expect(find.text('150000 đ'), findsOneWidget);
    },
  );

  testWidgets(
    'liquidation only exposes refund actions after manager recording',
    (tester) async {
      for (final refundStatus in const [
        'WAITING_OWNER_APPROVAL',
        'APPROVED_WAITING_REFUND',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: RequestDetailScreen(
              changeRequest: ChangeRequest(
                id: 62,
                requestCode: 'CR-62',
                requestType: ChangeRequestType.contractLiquidation,
                title: 'Liquidation request',
                description: '',
                status: ChangeRequestStatus.processing,
                requesterId: 1,
                createdAt: DateTime(2026, 8, 1),
                requestPayload: jsonEncode({
                  'liquidationStage': 'WAITING_HANDOVER',
                  'depositRefundStatus': refundStatus,
                }),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Đã nhận tiền cọc'), findsNothing);
        expect(find.text('Chưa nhận / Sai số tiền'), findsNothing);
      }
    },
  );

  testWidgets(
    'request detail remains overflow-safe on target mobile viewports',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in const [
        Size(320, 640),
        Size(360, 800),
        Size(390, 844),
        Size(430, 932),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: RequestDetailScreen(
              changeRequest: ChangeRequest(
                id: 63,
                requestCode: 'METER-REQUEST-WITH-A-LONG-CODE-202608',
                requestType: ChangeRequestType.meterReadingCorrection,
                title: 'Meter correction',
                description: 'Nội dung kiểm tra chỉ số điện có thể dài.',
                status: ChangeRequestStatus.underReview,
                requesterId: 1,
                createdAt: DateTime(2026, 8, 1),
                requestPayload: jsonEncode({
                  'invoiceCode': 'INV-202608',
                  'roomCode': 'P.201',
                  'billingPeriod': '2026-08',
                  'previousValue': 100,
                  'currentValue': 150,
                  'reportedCurrentValue': 130,
                  'usageAmount': 50,
                  'unitPrice': 3000,
                  'lineAmount': 150000,
                }),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('request types use their required detail destinations', (
    tester,
  ) async {
    final cases = <(ChangeRequest, String)>[
      (
        ChangeRequest(
          id: 70,
          requestCode: 'CR-RENEWAL',
          requestType: ChangeRequestType.contractRenewal,
          title: 'Renewal',
          description: '',
          status: ChangeRequestStatus.pending,
          requesterId: 1,
          requestPayload: jsonEncode({'roomId': 201, 'roomCode': '201'}),
        ),
        'Chi tiết yêu cầu',
      ),
      (
        ChangeRequest(
          id: 71,
          requestCode: 'CR-LIQUIDATION',
          requestType: ChangeRequestType.contractLiquidation,
          title: 'Liquidation',
          description: '',
          status: ChangeRequestStatus.pending,
          requesterId: 1,
        ),
        'Chi tiết yêu cầu',
      ),
      (
        ChangeRequest(
          id: 72,
          requestCode: 'CR-COOCCUPANT',
          requestType: ChangeRequestType.addCoOccupant,
          title: 'Co-occupant',
          description: '',
          status: ChangeRequestStatus.pending,
          requesterId: 1,
        ),
        'Chi tiết yêu cầu',
      ),
      (
        ChangeRequest(
          id: 73,
          requestCode: 'CR-METER',
          requestType: ChangeRequestType.meterReadingCorrection,
          title: 'Meter correction',
          description: '',
          status: ChangeRequestStatus.pending,
          requesterId: 1,
        ),
        'Chi tiết yêu cầu',
      ),
    ];

    for (final item in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: TenantRequestScreen(
            changeRequestService: _FakeChangeRequestService([item.$1]),
            roomTransferService: const _EmptyRoomTransferService(),
            roomId: 201,
            roomCode: '201',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem chi tiết').first);
      await tester.pumpAndSettle();

      expect(find.text(item.$2), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(seconds: 16));
  });

  testWidgets('request screen filters room transfers by selected source room', (
    tester,
  ) async {
    final requests = [
      _transferChangeRequest(501),
      _transferChangeRequest(502),
      _transferChangeRequest(503),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: TenantRequestScreen(
          changeRequestService: _FakeChangeRequestService(requests),
          roomTransferService: _FakeRoomTransferService({
            501: _transferRequest(id: 501, oldRoomId: 403, targetRoomId: 503),
            502: _transferRequest(id: 502, oldRoomId: 503, targetRoomId: 505),
            503: _transferRequest(id: 503, oldRoomId: 503, targetRoomId: 403),
          }),
          roomId: 403,
          roomCode: '403',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xem chi tiết'), findsOneWidget);
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
          widget is TextField && widget.decoration?.hintText == 'Ví dụ: 9',
    );
    await tester.enterText(termField, '18');
    await tester.tap(find.text('Gửi yêu cầu gia hạn'));
    await tester.pumpAndSettle();

    expect(submittedMonths, 18);
    expect(submittedStartDate, DateTime(2026, 8, 1));
    expect(submittedEndDate, DateTime(2028, 1, 31));
  });

  testWidgets('renewal custom months field remains editable after a preset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RenewContractRequestScreen(
          contract: _contract(endDate: DateTime(2026, 7, 31)),
          contractService: const _FakeLeaseContractService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final termField = find.byKey(const Key('renewal-custom-months'));
    expect(termField, findsOneWidget);

    await tester.ensureVisible(termField);
    await tester.tap(termField);
    await tester.enterText(termField, '9');
    await tester.pump();
    expect(tester.widget<TextFormField>(termField).controller!.text, '9');

    final preset = find.text('12 tháng');
    await tester.ensureVisible(preset);
    await tester.tap(preset);
    await tester.pump();
    expect(tester.widget<TextFormField>(termField).controller!.text, '12');

    await tester.ensureVisible(termField);
    await tester.tap(termField);
    await tester.enterText(termField, '9');
    await tester.pump();
    expect(tester.widget<TextFormField>(termField).controller!.text, '9');
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
          widget is TextField && widget.decoration?.hintText == 'Ví dụ: 9',
    );
    await tester.enterText(termField, '5');
    await tester.tap(find.text('Gửi yêu cầu gia hạn'));
    await tester.pumpAndSettle();

    expect(submittedMonths, isNull);
    expect(find.text('Thời hạn gia hạn tối thiểu 6 tháng.'), findsWidgets);
  });

  testWidgets('co-occupant records intention from contract screen', (
    tester,
  ) async {
    int? submittedContractId;
    String? submittedIntention;

    await tester.pumpWidget(
      MaterialApp(
        home: LeaseContractScreen(
          contractService: _FakeLeaseContractService(
            contract: _contract(coOccupantCanRecord: true),
            onRecordOccupantIntention: (contractId, intention, note) {
              submittedContractId = contractId;
              submittedIntention = intention;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ý định của bạn'), findsOneWidget);
    expect(find.text('Gia hạn\nhợp đồng'), findsNothing);

    await tester.ensureVisible(find.text('Tiếp tục ở\nnếu tái ký'));
    await tester.tap(find.text('Tiếp tục ở\nnếu tái ký'));
    await tester.pumpAndSettle();

    expect(submittedContractId, 9);
    expect(submittedIntention, 'JOIN_RENEWAL');
    expect(find.text('Đã lưu ý định của bạn.'), findsOneWidget);
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

ChangeRequest _transferChangeRequest(int transferId) {
  return ChangeRequest(
    id: transferId,
    requestCode: 'TR-$transferId',
    requestType: ChangeRequestType.roomTransfer,
    title: 'Transfer $transferId',
    description: 'Transfer $transferId',
    status: ChangeRequestStatus.pending,
    requesterId: 1,
    targetId: transferId,
    createdAt: DateTime(2026, 8, 1, 9),
    requestPayload: jsonEncode({'transferRequestId': transferId}),
  );
}

RoomTransferRequest _transferRequest({
  required int id,
  required int oldRoomId,
  required int targetRoomId,
}) {
  return RoomTransferRequest(
    id: id,
    requestCode: 'TR-$id',
    requesterId: 1,
    oldContractId: oldRoomId,
    oldRoomId: oldRoomId,
    targetRoomId: targetRoomId,
    transferringTenantProfileIds: const [],
    transferringTenantNames: const {},
    sourceHolderCandidateProfileIds: const [],
    sourceHolderCandidateNames: const {},
    targetTransferType: TargetTransferType.newContract,
    requestedTransferDate: DateTime(2026, 8, 15),
    status: TransferRequestStatus.requested,
    oldRoomCode: oldRoomId.toString(),
    targetRoomCode: targetRoomId.toString(),
  );
}

LeaseContract _contract({
  DateTime? endDate,
  bool isPrimary = false,
  bool coOccupantCanRecord = false,
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
    roleInContract: isPrimary
        ? 'PRIMARY'
        : coOccupantCanRecord
        ? 'CO_OCCUPANT'
        : '',
    isPrimary: isPrimary,
    canRecordOccupantIntention: coOccupantCanRecord,
  );
}
