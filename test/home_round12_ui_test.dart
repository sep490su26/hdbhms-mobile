import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_profile_model.dart';
import 'package:hdbhms_mobile/screens/home/home_screen.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';

class _HomeService extends HomeService {
  const _HomeService();

  @override
  Future<HomeSummary> fetchHomeSummary({int? contractId}) async => HomeSummary(
    user: const HomeUser(
      id: 1,
      fullName: 'Nguyễn Văn A',
      phone: '0900000000',
      email: 'a@example.com',
      role: 'TENANT',
    ),
    tenant: const HomeTenant(id: 1, name: 'Nhà trọ'),
    room: const HomeRoom(
      id: 103,
      roomCode: '103',
      name: 'Phòng 103',
      currentStatus: 'OCCUPIED',
    ),
    rooms: const [],
    contract: HomeContract(
      id: 23,
      contractCode: 'HD-23',
      status: 'ACTIVE',
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2027, 5, 1),
    ),
    invoiceSummary: const InvoiceSummary(
      unpaidCount: 0,
      totalUnpaidAmount: 0,
      nearestDueDate: null,
    ),
    notificationSummary: const NotificationSummary(unreadCount: 0),
    utilitySummary: const UtilitySummary(
      electricity: UtilityUsage(
        name: 'Điện năng',
        value: 195,
        unit: 'kWh',
        status: 'CONFIRMED',
        percentChange: null,
      ),
    ),
  );
}

class _NotificationService extends NotificationService {
  const _NotificationService();

  @override
  Future<int> getUnreadCount({int? roomId, String? roomCode}) async => 2;
}

class _LeaseService extends LeaseContractService {
  const _LeaseService();

  @override
  Future<List<ActiveRoomItem>> fetchMyActiveRooms() async => const [
    ActiveRoomItem(
      contractId: 23,
      contractCode: 'HD-23',
      roomId: 103,
      roomCode: '103',
      roomName: 'Phòng 103',
      propertyName: 'Nhà trọ',
    ),
  ];

  @override
  Future<LeaseContract> getContractById(
    int contractId, {
    int? tenantId,
  }) async => LeaseContract.fromJson({
    'id': contractId,
    'startDate': '2026-05-01',
    'occupants': [
      {
        'tenantProfileId': 1,
        'fullName': 'Nguyễn Văn A',
        'occupantRole': 'PRIMARY',
        'status': 'ACTIVE',
        'moveInDate': '2026-05-01',
      },
    ],
  });
}

class _ProfileService extends TenantProfileService {
  const _ProfileService();

  @override
  Future<TenantProfileResponse> getMyProfile() async =>
      TenantProfileResponse.fromJson({
        'tenantProfileId': 1,
        'person': <String, dynamic>{},
      });
}

class _InvoiceService extends TenantInvoiceService {
  const _InvoiceService({this.usages = const [30, 20]});

  final List<double> usages;

  @override
  Future<List<TenantInvoice>> fetchMyInvoices({
    int? roomId,
    String? roomCode,
  }) async => [
    for (var index = 0; index < usages.length; index++)
      _invoice(
        '2026-${(6 - index).toString().padLeft(2, '0')}',
        usages[index],
        index == 0 ? 500000 : 1000000,
      ),
  ];

  @override
  Future<List<TenantInvoice>> fetchElectricityHistory({int? contractId}) =>
      fetchMyInvoices();

  TenantInvoice _invoice(String period, double usage, int remainingAmount) {
    final line = TenantInvoiceLine(
      id: 1,
      lineType: 'ELECTRICITY',
      description: 'Tiền điện',
      quantity: usage.round(),
      unitPrice: 3000,
      amount: usage.round() * 3000,
      readingPeriod: period,
      readingDate: DateTime(2026, int.parse(period.substring(5)), 28),
      previousValue: 100,
      currentValue: 100 + usage,
      usageAmount: usage,
    );
    return TenantInvoice(
      id: int.parse(period.substring(5)),
      invoiceCode: 'INV-$period',
      invoiceType: 'UTILITY',
      billingPeriod: period,
      status: 'ISSUED',
      roomId: 103,
      roomCode: '103',
      contractId: 23,
      contractCode: 'HD-23',
      dueDate: DateTime(2026, 6, 18),
      issuedAt: DateTime(2026, int.parse(period.substring(5)), 28),
      paidAt: null,
      totalAmount: remainingAmount,
      paidAmount: 0,
      remainingAmount: remainingAmount,
      paymentIntentId: null,
      checkoutUrl: '',
      qrCode: '',
      providerOrderCode: '',
      paymentLinkId: '',
      bankBin: '',
      bankShortName: '',
      accountNumber: '',
      accountName: '',
      transferDescription: '',
      lines: [line],
      priceDifferenceSettlementType: null,
    );
  }
}

Widget _home({TenantInvoiceService invoiceService = const _InvoiceService()}) =>
    MaterialApp(
      home: HomeScreen(
        key: ValueKey(invoiceService),
        homeService: const _HomeService(),
        leaseContractService: const _LeaseService(),
        tenantInvoiceService: invoiceService,
        profileService: const _ProfileService(),
        notificationService: const _NotificationService(),
      ),
    );

void main() {
  testWidgets(
    'quick payment and electricity footer use the required hierarchy',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_home());
      await tester.pumpAndSettle();

      expect(find.byType(AppNotificationBell), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppNotificationBell),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.text('Thanh toán nhanh'), findsOneWidget);
      expect(find.text('Tổng tiền cần thanh toán'), findsOneWidget);
      expect(find.text('1.500.000đ'), findsOneWidget);
      expect(find.text('Lịch sử tiêu thụ điện'), findsNothing);
      expect(
        find.text('Tiêu thụ tăng 10 kWh so với tháng trước'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('electricity-period-value-usage')),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byIcon(Icons.chevron_right_rounded));
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử tiêu thụ điện'), findsOneWidget);
    },
  );

  testWidgets(
    'one eligible period has no comparison badge and keeps history copy',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _home(invoiceService: const _InvoiceService(usages: [30])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đang so sánh'), findsNothing);
      expect(find.text('Xem mức tiêu thụ theo tháng'), findsOneWidget);
    },
  );

  testWidgets('two eligible periods derive stable and decrease trends', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _home(invoiceService: const _InvoiceService(usages: [20, 20])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tiêu thụ không đổi so với tháng trước'), findsOneWidget);

    await tester.pumpWidget(
      _home(invoiceService: const _InvoiceService(usages: [10, 20])),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Tiêu thụ giảm 10 kWh so với tháng trước'),
      findsOneWidget,
    );
  });

  testWidgets('zero-payable state does not present a required-payment amount', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _home(invoiceService: const _InvoiceService(usages: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không có khoản cần thanh toán'), findsOneWidget);
    expect(find.text('Tổng tiền cần thanh toán'), findsNothing);
  });

  testWidgets('home layout stays overflow-free on supported mobile sizes', (
    tester,
  ) async {
    for (final size in const [
      Size(320, 640),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_home());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Thanh toán nhanh'), findsOneWidget);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
