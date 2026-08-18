import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_profile_model.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';

class _ProfileService extends TenantProfileService {
  const _ProfileService();

  @override
  Future<TenantProfileResponse> getMyProfile() async => _profile;
}

class _RentalContextService extends LeaseContractService {
  const _RentalContextService({this.rooms = const [], this.error});

  final List<ActiveRoomItem> rooms;
  final Object? error;

  @override
  Future<List<ActiveRoomItem>> fetchMyActiveRooms() async {
    if (error != null) throw error!;
    return rooms;
  }
}

class _AuthService extends AuthService {
  _AuthService();

  var logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

class _QuietNotificationService extends NotificationService {
  const _QuietNotificationService();

  @override
  Future<int> getUnreadCount() async => 0;
}

const _profile = TenantProfileResponse(
  tenantProfileId: 1,
  status: 'ACTIVE',
  person: PersonProfileDto(
    fullName: 'Nguyễn Văn A',
    phone: '0912345678',
    email: 'a@example.com',
    permanentAddress: 'Hà Nội',
    portraitFileUrl: '',
  ),
  identityDocument: null,
  vehicles: [],
  emergencyContacts: [],
);

final _activeRoom = ActiveRoomItem(
  contractId: 10,
  contractCode: 'HD-10',
  roomId: 101,
  roomCode: 'A.101',
  roomName: 'Phòng A.101',
  propertyName: 'Nhà trọ Hải Đăng',
  roomStatus: 'OCCUPIED',
  contractStatus: 'ACTIVE',
);

Future<void> _pumpProfile(
  WidgetTester tester, {
  required LeaseContractService leaseContractService,
  required _AuthService authService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TenantProfileScreen(
        profileService: const _ProfileService(),
        leaseContractService: leaseContractService,
        notificationService: const _QuietNotificationService(),
        authService: authService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Round 22 profile rental context', () {
    testWidgets('no active rental hides the contract entry but keeps logout', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        leaseContractService: const _RentalContextService(),
        authService: _AuthService(),
      );

      expect(find.text('Hợp đồng thuê phòng'), findsNothing);
      expect(find.text('Xem danh sách hợp đồng'), findsNothing);
      expect(find.text('Đăng xuất'), findsOneWidget);
      expect(find.text('Thông tin cá nhân'), findsOneWidget);
    });

    testWidgets('an active rental keeps the contract entry visible', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        leaseContractService: _RentalContextService(rooms: [_activeRoom]),
        authService: _AuthService(),
      );

      expect(find.text('Hợp đồng thuê phòng'), findsOneWidget);
      expect(find.text('Xem danh sách hợp đồng'), findsOneWidget);
    });

    testWidgets(
      'active-rental lookup failure does not block profile or logout',
      (tester) async {
        final authService = _AuthService();
        await _pumpProfile(
          tester,
          leaseContractService: _RentalContextService(
            error: StateError('offline'),
          ),
          authService: authService,
        );

        expect(find.text('Nguyễn Văn A'), findsWidgets);
        expect(find.text('Đăng xuất'), findsOneWidget);
        expect(find.text('Hợp đồng thuê phòng'), findsNothing);

        await tester.tap(find.text('Đăng xuất'));
        await tester.pump();
        expect(authService.logoutCalls, 1);
      },
    );
  });
}
