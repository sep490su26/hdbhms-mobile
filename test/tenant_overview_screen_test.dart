import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_profile_model.dart';
import 'package:hdbhms_mobile/screens/tenant_overview/tenant_overview_screen.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';

class _FakeHomeService extends HomeService {
  const _FakeHomeService({this.propertyPhone = '0912345678'});

  final String propertyPhone;

  @override
  Future<HomeSummary> fetchHomeSummary({int? contractId}) async {
    return HomeSummary(
      user: const HomeUser(
        id: 1,
        fullName: 'Tenant',
        phone: '0900000000',
        email: 'tenant@example.com',
        role: 'TENANT',
      ),
      tenant: HomeTenant(
        id: 17,
        name: 'Nha tro Hai Dang 1',
        address: '123 Le Loi',
        propertyPhone: propertyPhone,
        imageUrls: ['https://example.com/property.jpg'],
      ),
      room: const HomeRoom(
        id: 403,
        roomCode: '403',
        name: 'Phòng 403',
        currentStatus: 'OCCUPIED',
      ),
      rooms: const [],
      contract: HomeContract(
        id: 403,
        contractCode: 'HD-SEED-403-2026',
        status: 'TERMINATION_PENDING',
        startDate: DateTime(2025, 10, 1),
        endDate: DateTime(2026, 9, 30),
      ),
      invoiceSummary: const InvoiceSummary(
        unpaidCount: 0,
        totalUnpaidAmount: 0,
        nearestDueDate: null,
      ),
      notificationSummary: const NotificationSummary(unreadCount: 0),
      utilitySummary: const UtilitySummary(),
    );
  }
}

class _FakeNotificationService extends NotificationService {
  const _FakeNotificationService();

  @override
  Future<int> getUnreadCount() async => 2;
}

class _FakeProfileService extends TenantProfileService {
  const _FakeProfileService();

  @override
  Future<TenantProfileResponse> getMyProfile() async =>
      TenantProfileResponse.fromJson({
        'tenantProfileId': 1,
        'person': {'fullName': 'Tenant'},
      });
}

class _FakeLeaseContractService extends LeaseContractService {
  const _FakeLeaseContractService();

  @override
  Future<List<ActiveRoomItem>> fetchMyActiveRooms() async {
    return [
      ActiveRoomItem(
        contractId: 403,
        contractCode: 'HD-SEED-403-2026',
        roomId: 403,
        roomCode: '403',
        roomName: 'Phòng 403',
        propertyName: 'Nha tro Hai Dang 1',
        roomStatus: 'OCCUPIED',
        contractStatus: 'TERMINATION_PENDING',
        tenantIntention: 'MOVE_OUT',
        roleInContract: 'PRIMARY',
        startDate: DateTime(2025, 10, 1),
        endDate: DateTime(2026, 9, 30),
        expectedVacantDate: DateTime(2026, 7, 31),
        occupantCount: 1,
      ),
    ];
  }
}

Future<void> _pumpOverview(
  WidgetTester tester, {
  required String propertyPhone,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TenantOverviewScreen(
        authService: const AuthService(),
        homeService: _FakeHomeService(propertyPhone: propertyPhone),
        leaseContractService: const _FakeLeaseContractService(),
        profileService: const _FakeProfileService(),
        tenantInvoiceService: const TenantInvoiceService(),
        notificationService: const _FakeNotificationService(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('tenant overview shows liquidation date for pending move out', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TenantOverviewScreen(
          authService: AuthService(),
          homeService: _FakeHomeService(),
          leaseContractService: _FakeLeaseContractService(),
          profileService: _FakeProfileService(),
          tenantInvoiceService: TenantInvoiceService(),
          notificationService: _FakeNotificationService(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Phòng 403'), findsOneWidget);
    expect(find.text('Đang thanh lý'), findsOneWidget);
    expect(find.text('Dự kiến trả: 31/07/2026'), findsOneWidget);
    expect(find.text('Hết hạn: 30/09/2026'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('tenant overview falls back to the official property phone', (
    tester,
  ) async {
    await _pumpOverview(tester, propertyPhone: '');

    expect(find.text('0846 557 999'), findsOneWidget);
    expect(find.text('Chưa cập nhật số điện thoại'), findsNothing);
  });

  testWidgets('tenant overview prioritizes a property phone from backend', (
    tester,
  ) async {
    await _pumpOverview(tester, propertyPhone: '0912 345 678');

    expect(find.text('0912 345 678'), findsOneWidget);
    expect(find.text('0846 557 999'), findsNothing);
  });
}
