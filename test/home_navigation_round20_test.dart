import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_profile_model.dart';
import 'package:hdbhms_mobile/screens/home/home_screen.dart';
import 'package:hdbhms_mobile/screens/payment/payment_preview_page.dart';
import 'package:hdbhms_mobile/screens/payment/payment_success_page.dart';
import 'package:hdbhms_mobile/screens/tenant_overview/tenant_overview_screen.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';

class _HomeFixtureService extends HomeService {
  _HomeFixtureService({this.failuresBeforeSuccess = 0, this.emptyRoom = false});

  final int failuresBeforeSuccess;
  final bool emptyRoom;
  int calls = 0;

  @override
  Future<HomeSummary> fetchHomeSummary({int? contractId}) async {
    calls += 1;
    if (calls <= failuresBeforeSuccess) {
      throw const HomeException('Bạn không có quyền thực hiện thao tác này');
    }
    return _homeSummary(emptyRoom: emptyRoom);
  }
}

class _LeaseFixtureService extends LeaseContractService {
  const _LeaseFixtureService({this.rooms = true});

  final bool rooms;

  @override
  Future<List<ActiveRoomItem>> fetchMyActiveRooms() async => rooms
      ? const [
          ActiveRoomItem(
            contractId: 23,
            contractCode: 'HD-23',
            roomId: 103,
            roomCode: '103',
            roomName: 'Phòng 103',
            propertyName: 'Nhà trọ',
          ),
        ]
      : const [];

  @override
  Future<LeaseContract> getContractById(
    int contractId, {
    int? tenantId,
  }) async => LeaseContract.fromJson({
    'id': contractId,
    'startDate': '2025-12-01',
    'occupants': [
      {
        'tenantProfileId': 1,
        'fullName': 'Nguyễn Văn A',
        'occupantRole': 'PRIMARY',
        'status': 'ACTIVE',
        'moveInDate': '2025-12-01',
      },
    ],
  });
}

class _ProfileFixtureService extends TenantProfileService {
  const _ProfileFixtureService();

  @override
  Future<TenantProfileResponse> getMyProfile() async =>
      TenantProfileResponse.fromJson({
        'tenantProfileId': 1,
        'person': <String, dynamic>{},
      });
}

class _NotificationFixtureService extends NotificationService {
  const _NotificationFixtureService();

  @override
  Future<int> getUnreadCount() async => 0;
}

class _MeterInvoiceService extends TenantInvoiceService {
  const _MeterInvoiceService({
    required this.latestReadingPeriod,
    required this.latestBillingPeriod,
    required this.latestDate,
    required this.previousReadingPeriod,
    required this.previousDate,
  });

  final String latestReadingPeriod;
  final String latestBillingPeriod;
  final DateTime latestDate;
  final String previousReadingPeriod;
  final DateTime previousDate;

  @override
  Future<List<TenantInvoice>> fetchMyInvoices({
    int? roomId,
    String? roomCode,
  }) async => _invoices;

  @override
  Future<List<TenantInvoice>> fetchElectricityHistory({
    int? contractId,
  }) async => _invoices;

  List<TenantInvoice> get _invoices => [
    _meterInvoice(
      id: 2,
      billingPeriod: latestBillingPeriod,
      readingPeriod: latestReadingPeriod,
      readingDate: latestDate,
      previousValue: 165,
      currentValue: 195,
      usageAmount: 30,
    ),
    _meterInvoice(
      id: 1,
      billingPeriod: previousReadingPeriod,
      readingPeriod: previousReadingPeriod,
      readingDate: previousDate,
      previousValue: 140,
      currentValue: 165,
      usageAmount: 25,
    ),
  ];
}

HomeSummary _homeSummary({bool emptyRoom = false}) => HomeSummary(
  user: const HomeUser(
    id: 1,
    fullName: 'Nguyễn Văn A',
    phone: '0900000000',
    email: 'a@example.com',
    role: 'TENANT',
  ),
  tenant: const HomeTenant(id: 1, name: 'Nhà trọ'),
  room: emptyRoom
      ? null
      : const HomeRoom(
          id: 103,
          roomCode: '103',
          name: 'Phòng 103',
          currentStatus: 'OCCUPIED',
        ),
  rooms: const [],
  contract: emptyRoom
      ? null
      : HomeContract(
          id: 23,
          contractCode: 'HD-23',
          status: 'ACTIVE',
          startDate: DateTime(2025, 12, 1),
          endDate: DateTime(2026, 12, 1),
        ),
  invoiceSummary: const InvoiceSummary(
    unpaidCount: 0,
    totalUnpaidAmount: 0,
    nearestDueDate: null,
  ),
  notificationSummary: const NotificationSummary(unreadCount: 0),
  utilitySummary: const UtilitySummary(
    electricity: UtilityUsage(
      name: 'Tiêu thụ điện',
      value: 195,
      unit: 'kWh',
      status: 'CONFIRMED',
      percentChange: null,
    ),
  ),
);

TenantInvoice _meterInvoice({
  required int id,
  required String billingPeriod,
  required String readingPeriod,
  required DateTime readingDate,
  required double previousValue,
  required double currentValue,
  required double usageAmount,
}) => TenantInvoice(
  id: id,
  invoiceCode: 'INV-$id',
  invoiceType: 'UTILITY',
  billingPeriod: billingPeriod,
  status: 'ISSUED',
  roomId: 103,
  roomCode: '103',
  contractId: 23,
  contractCode: 'HD-23',
  dueDate: readingDate,
  issuedAt: readingDate,
  paidAt: null,
  totalAmount: 90000,
  paidAmount: 0,
  remainingAmount: 90000,
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
  lines: [
    TenantInvoiceLine(
      id: id,
      lineType: 'ELECTRICITY',
      description: 'Tiền điện',
      quantity: usageAmount.round(),
      unitPrice: 3000,
      amount: 90000,
      readingPeriod: readingPeriod,
      readingDate: readingDate,
      previousValue: previousValue,
      currentValue: currentValue,
      usageAmount: usageAmount,
    ),
  ],
  priceDifferenceSettlementType: null,
);

Widget _home({
  required HomeService homeService,
  TenantInvoiceService? invoiceService,
}) => MaterialApp(
  home: HomeScreen(
    homeService: homeService,
    leaseContractService: const _LeaseFixtureService(),
    tenantInvoiceService:
        invoiceService ??
        _MeterInvoiceService(
          latestReadingPeriod: '2026-07',
          latestBillingPeriod: '2026-07',
          latestDate: DateTime(2026, 7, 31),
          previousReadingPeriod: '2026-06',
          previousDate: DateTime(2026, 6, 30),
        ),
    profileService: const _ProfileFixtureService(),
    notificationService: const _NotificationFixtureService(),
  ),
);

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  testWidgets('home error keeps retry and opens the room overview explicitly', (
    tester,
  ) async {
    final homeService = _HomeFixtureService(failuresBeforeSuccess: 10);
    await tester.pumpWidget(_home(homeService: homeService));
    await tester.pumpAndSettle();

    expect(find.byType(AppTopBar), findsOneWidget);
    expect(find.text('Phòng 103'), findsOneWidget);
    expect(
      find.text('Bạn không có quyền thực hiện thao tác này'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.byTooltip('Danh sách phòng đang thuê'), findsOneWidget);

    await tester.tap(find.byTooltip('Danh sách phòng đang thuê'));
    await tester.pumpAndSettle();
    expect(find.byType(TenantOverviewScreen), findsOneWidget);
  });

  testWidgets('home retry uses the existing provider load again', (
    tester,
  ) async {
    final homeService = _HomeFixtureService(failuresBeforeSuccess: 1);
    await tester.pumpWidget(_home(homeService: homeService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(homeService.calls, 2);
    expect(find.text('Thanh toán nhanh'), findsOneWidget);
  });

  testWidgets('empty room card fills the overview content width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: TenantOverviewScreen(
          homeService: _HomeFixtureService(emptyRoom: true),
          leaseContractService: const _LeaseFixtureService(rooms: false),
          profileService: const _ProfileFixtureService(),
          tenantInvoiceService: const TenantInvoiceService(),
          notificationService: const _NotificationFixtureService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có phòng đang thuê'), findsOneWidget);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('tenant-overview-empty-rooms-card')),
          )
          .width,
      closeTo(328, 0.1),
    );
  });

  testWidgets(
    'electricity labels prioritize reading period over billing period',
    (tester) async {
      await tester.pumpWidget(
        _home(
          homeService: _HomeFixtureService(),
          invoiceService: _MeterInvoiceService(
            latestReadingPeriod: '2026-07',
            latestBillingPeriod: '2026-08',
            latestDate: DateTime(2026, 7, 31),
            previousReadingPeriod: '2026-06',
            previousDate: DateTime(2026, 6, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kỳ tháng 07/2026'), findsOneWidget);
      expect(find.text('Chỉ số T7/2026'), findsOneWidget);
      expect(find.text('Chỉ số T6/2026'), findsOneWidget);
      expect(find.text('Lượng điện tiêu thụ T7/2026'), findsOneWidget);
      expect(find.text('Tiền điện T7/2026'), findsOneWidget);
      expect(find.text('Chỉ số hiện tại'), findsNothing);
      expect(find.text('Chỉ số tháng trước'), findsNothing);
      expect(find.text('Tiêu thụ kỳ này'), findsNothing);
      expect(find.text('Tiền điện kỳ này'), findsNothing);
      expect(find.textContaining('195', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'electricity labels roll January back to December of prior year',
    (tester) async {
      await tester.pumpWidget(
        _home(
          homeService: _HomeFixtureService(),
          invoiceService: _MeterInvoiceService(
            latestReadingPeriod: '2026-01',
            latestBillingPeriod: '2026-02',
            latestDate: DateTime(2026, 1, 31),
            previousReadingPeriod: '2025-12',
            previousDate: DateTime(2025, 12, 31),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chỉ số T1/2026'), findsOneWidget);
      expect(find.text('Chỉ số T12/2025'), findsOneWidget);
      expect(find.text('Lượng điện tiêu thụ T1/2026'), findsOneWidget);
      expect(find.text('Tiền điện T1/2026'), findsOneWidget);
      expect(find.textContaining('T0/'), findsNothing);
    },
  );

  testWidgets('invalid electricity period keeps generic labels and values', (
    tester,
  ) async {
    await tester.pumpWidget(
      _home(
        homeService: _HomeFixtureService(),
        invoiceService: _MeterInvoiceService(
          latestReadingPeriod: '2026-00',
          latestBillingPeriod: 'không hợp lệ',
          latestDate: DateTime(2026, 7, 31),
          previousReadingPeriod: '2026-06',
          previousDate: DateTime(2026, 6, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chỉ số hiện tại'), findsOneWidget);
    expect(find.text('Chỉ số tháng trước'), findsOneWidget);
    expect(find.text('Tiêu thụ kỳ này'), findsOneWidget);
    expect(find.text('Tiền điện kỳ này'), findsOneWidget);
    expect(find.textContaining('195', findRichText: true), findsOneWidget);
    expect(find.textContaining('T0/'), findsNothing);
  });

  testWidgets('long electricity period labels remain overflow-free on phones', (
    tester,
  ) async {
    for (final size in const [
      Size(320, 640),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _home(
          homeService: _HomeFixtureService(),
          invoiceService: _MeterInvoiceService(
            latestReadingPeriod: '2025-12',
            latestBillingPeriod: '2025-12',
            latestDate: DateTime(2025, 12, 31),
            previousReadingPeriod: '2025-11',
            previousDate: DateTime(2025, 11, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lượng điện tiêu thụ T12/2025'), findsOneWidget);
      expect(find.text('Tiền điện T12/2025'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets(
    'payment success uses the overview copy and keeps HomeScreen route',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final observer = _RecordingNavigatorObserver();
      final invoice = _meterInvoice(
        id: 8,
        billingPeriod: '2026-07',
        readingPeriod: '2026-07',
        readingDate: DateTime(2026, 7, 31),
        previousValue: 165,
        currentValue: 195,
        usageAmount: 30,
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: PaymentSuccessPage(invoice: invoice),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quay về Tổng quan'), findsOneWidget);
      expect(find.text('Quay lại trang chủ'), findsNothing);

      final overviewAction = find.text('Quay về Tổng quan');
      await tester.ensureVisible(overviewAction);
      await tester.tap(overviewAction);
      final route = observer.pushedRoutes.last as MaterialPageRoute<dynamic>;
      final destination = route.builder(tester.element(find.byType(Navigator)));
      expect(destination, isA<HomeScreen>());
      expect((destination as HomeScreen).initialRoom?.contractId, 23);
    },
  );

  testWidgets(
    'payment preview opens the production success screen with new copy',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: PaymentPreviewPage()));
      await tester.pumpAndSettle();

      final tile = find.text('Thanh toán thành công — Tiền phòng & dịch vụ');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      final overviewAction = find.text('Quay về Tổng quan');
      await tester.ensureVisible(overviewAction);
      expect(overviewAction, findsOneWidget);
      expect(find.text('Quay lại trang chủ'), findsNothing);
    },
  );
}
