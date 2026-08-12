import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_profile_model.dart';
import 'package:hdbhms_mobile/providers/home_provider.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';

class _FakeHomeService extends HomeService {
  const _FakeHomeService();

  @override
  Future<HomeSummary> fetchHomeSummary({int? contractId}) async {
    return HomeSummary(
      user: const HomeUser(
        id: 1,
        fullName: 'POAKLAK',
        phone: '0900000000',
        email: 'tenant@example.com',
        role: 'TENANT',
      ),
      tenant: const HomeTenant(id: 1, name: 'Nha tro Hai Dang 1'),
      room: const HomeRoom(
        id: 103,
        roomCode: '103',
        name: 'Phong 103',
        currentStatus: 'OCCUPIED',
      ),
      rooms: const [],
      contract: HomeContract(
        id: 23,
        contractCode: 'HD-2026-H103-23',
        status: 'ACTIVE',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2027, 6, 1),
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

class _RecordingHomeService extends HomeService {
  _RecordingHomeService();

  final List<int?> requestedContractIds = [];

  @override
  Future<HomeSummary> fetchHomeSummary({int? contractId}) async {
    requestedContractIds.add(contractId);
    final roomId = contractId == 24 ? 104 : 103;
    return HomeSummary(
      user: const HomeUser(
        id: 1,
        fullName: 'POAKLAK',
        phone: '0900000000',
        email: 'tenant@example.com',
        role: 'TENANT',
      ),
      tenant: const HomeTenant(id: 1, name: 'Nha tro Hai Dang 1'),
      room: HomeRoom(
        id: roomId,
        roomCode: '$roomId',
        name: 'Phong $roomId',
        currentStatus: 'OCCUPIED',
      ),
      rooms: const [],
      contract: HomeContract(
        id: contractId ?? 23,
        contractCode: contractId == 24 ? 'HD-2026-H104-24' : 'HD-2026-H103-23',
        status: 'ACTIVE',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2027, 6, 1),
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

class _FakeLeaseContractService extends LeaseContractService {
  const _FakeLeaseContractService();

  @override
  Future<List<ActiveRoomItem>> fetchMyActiveRooms() async {
    return const [
      ActiveRoomItem(
        contractId: 23,
        contractCode: 'HD-2026-H103-23',
        roomId: 103,
        roomCode: '103',
        roomName: 'Phong 103',
        propertyName: 'Nha tro Hai Dang 1',
      ),
      ActiveRoomItem(
        contractId: 24,
        contractCode: 'HD-2026-H104-24',
        roomId: 104,
        roomCode: '104',
        roomName: 'Phong 104',
        propertyName: 'Nha tro Hai Dang 1',
      ),
    ];
  }

  @override
  Future<LeaseContract> getContractById(int contractId, {int? tenantId}) async {
    return LeaseContract.fromJson({
      'id': contractId,
      'contractCode': 'HD-2026-$contractId',
      'startDate': '2026-05-01',
      'occupants': [
        {
          'tenantProfileId': 1,
          'fullName': 'Tenant Test',
          'occupantRole': 'PRIMARY',
          'status': 'ACTIVE',
        },
      ],
    });
  }
}

class _FakeTenantProfileService extends TenantProfileService {
  const _FakeTenantProfileService();

  @override
  Future<TenantProfileResponse> getMyProfile() async {
    return TenantProfileResponse.fromJson({
      'tenantProfileId': 1,
      'person': <String, dynamic>{},
    });
  }
}

class _FakeTenantInvoiceService extends TenantInvoiceService {
  const _FakeTenantInvoiceService();

  @override
  Future<List<TenantInvoice>> fetchMyInvoices({
    int? roomId,
    String? roomCode,
  }) async {
    return [
      _invoice(
        id: 1,
        roomId: 103,
        roomCode: '103',
        contractId: 23,
        contractCode: 'HD-2026-H103-23',
        remainingAmount: 4000,
      ),
      _invoice(
        id: 2,
        roomId: 104,
        roomCode: '104',
        contractId: 24,
        contractCode: 'HD-2026-H104-24',
        remainingAmount: 9000,
      ),
    ];
  }

  TenantInvoice _invoice({
    required int id,
    required int roomId,
    required String roomCode,
    required int contractId,
    required String contractCode,
    required int remainingAmount,
    String? priceDifferenceSettlementType,
  }) {
    return TenantInvoice(
      id: id,
      invoiceCode: 'INV-$id',
      invoiceType: 'UTILITY',
      billingPeriod: '2026-06',
      status: 'ISSUED',
      roomId: roomId,
      roomCode: roomCode,
      contractId: contractId,
      contractCode: contractCode,
      dueDate: DateTime(2026, 6, 18),
      issuedAt: DateTime(2026, 6, 15),
      paidAt: null,
      totalAmount: remainingAmount,
      paidAmount: 0,
      remainingAmount: remainingAmount,
      paymentIntentId: id,
      checkoutUrl: 'https://pay.payos.vn/web/$id',
      qrCode: 'PAYOS_QR_PAYLOAD_$id',
      providerOrderCode: '660000000000$id',
      paymentLinkId: 'plink-$id',
      bankBin: '970418',
      bankShortName: 'BIDV',
      accountNumber: 'V3CAS1510905318',
      accountName: 'NGUYEN HUU TIEN',
      transferDescription: 'CS$id 4000',
      lines: const [
        TenantInvoiceLine(
          id: 1,
          lineType: 'MAINTENANCE_COMPENSATION',
          description: 'Chi phi sua chua',
          quantity: 1,
          unitPrice: 4000,
          amount: 4000,
        ),
      ],
      priceDifferenceSettlementType: priceDifferenceSettlementType,
    );
  }
}

class _TrendTenantInvoiceService extends TenantInvoiceService {
  const _TrendTenantInvoiceService();

  @override
  Future<List<TenantInvoice>> fetchMyInvoices({
    int? roomId,
    String? roomCode,
  }) async {
    return [
      _utilityInvoice(
        id: 11,
        period: '2026-05',
        previousValue: 120,
        currentValue: 150,
        usageAmount: 30,
      ),
      _utilityInvoice(
        id: 12,
        period: '2026-06',
        previousValue: 150,
        currentValue: 195,
        usageAmount: 45,
      ),
    ];
  }

  TenantInvoice _utilityInvoice({
    required int id,
    required String period,
    required double previousValue,
    required double currentValue,
    required double usageAmount,
  }) {
    return TenantInvoice(
      id: id,
      invoiceCode: 'INV-$id',
      invoiceType: 'UTILITY',
      billingPeriod: period,
      status: 'ISSUED',
      roomId: 103,
      roomCode: '103',
      contractId: 23,
      contractCode: 'HD-2026-H103-23',
      dueDate: DateTime(2026, 6, 18),
      issuedAt: DateTime(2026, int.parse(period.substring(5)), 15),
      paidAt: null,
      totalAmount: 0,
      paidAmount: 0,
      remainingAmount: 0,
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
          description: 'Tiền điện $period',
          quantity: usageAmount.round(),
          unitPrice: 0,
          amount: 0,
          meterReadingId: id,
          meterType: 'ELECTRICITY',
          readingPeriod: period,
          previousValue: previousValue,
          currentValue: currentValue,
          usageAmount: usageAmount,
        ),
      ],
      priceDifferenceSettlementType: null,
    );
  }
}

TenantInvoice _meterInvoice({
  required int id,
  required int contractId,
  required String period,
  DateTime? readingDate,
  double usage = 30,
  int remainingAmount = 0,
}) {
  return TenantInvoice(
    id: id,
    invoiceCode: 'INV-$id',
    invoiceType: 'UTILITY',
    billingPeriod: period,
    status: 'ISSUED',
    roomId: 103,
    roomCode: '103',
    contractId: contractId,
    contractCode: 'HD-$contractId',
    dueDate: DateTime(2026, 6, 18),
    issuedAt: DateTime(2026, int.parse(period.substring(5)), 10),
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
    lines: [
      TenantInvoiceLine(
        id: id,
        lineType: 'ELECTRICITY',
        description: 'Tiền điện',
        quantity: usage.round(),
        unitPrice: 3000,
        amount: usage.round() * 3000,
        readingPeriod: period,
        readingDate: readingDate,
        previousValue: 100,
        currentValue: 100 + usage,
        usageAmount: usage,
      ),
    ],
    priceDifferenceSettlementType: null,
  );
}

class _TwoPayableInvoiceService extends TenantInvoiceService {
  const _TwoPayableInvoiceService();

  @override
  Future<List<TenantInvoice>> fetchMyInvoices({
    int? roomId,
    String? roomCode,
  }) async => [
    _meterInvoice(
      id: 1,
      contractId: 23,
      period: '2026-06',
      remainingAmount: 500000,
    ),
    _meterInvoice(
      id: 2,
      contractId: 23,
      period: '2026-07',
      remainingAmount: 1000000,
    ),
  ];
}

void main() {
  test(
    'home provider uses tenant invoice API and filters by selected room',
    () async {
      final provider = HomeProvider(
        homeService: const _FakeHomeService(),
        leaseContractService: const _FakeLeaseContractService(),
        tenantInvoiceService: const _FakeTenantInvoiceService(),
        tenantProfileService: const _FakeTenantProfileService(),
      );

      await provider.load();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      provider.selectRoom(
        const ActiveRoomItem(
          contractId: 23,
          contractCode: 'HD-2026-H103-23',
          roomId: 103,
          roomCode: '103',
          roomName: 'Phong 103',
          propertyName: 'Nha tro Hai Dang 1',
        ),
      );

      expect(provider.invoices, hasLength(2));
      expect(provider.payableInvoices, hasLength(1));
      expect(provider.payableInvoices.single.roomCode, '103');
      expect(provider.invoiceSummary.unpaidCount, 1);
      expect(provider.invoiceSummary.totalUnpaidAmount, 4000);
      expect(provider.payableInvoices.single.qrCode, 'PAYOS_QR_PAYLOAD_1');
      expect(provider.payableInvoices.single.transferDescription, 'CS1 4000');
      expect(provider.payableInvoices.single.accountNumber, 'V3CAS1510905318');
      expect(
        provider.payableInvoices.single.displayAccountNumber,
        '1510905318',
      );
    },
  );

  test('home provider loads selected initial room contract', () async {
    final homeService = _RecordingHomeService();
    final provider = HomeProvider(
      homeService: homeService,
      leaseContractService: const _FakeLeaseContractService(),
      tenantInvoiceService: const _FakeTenantInvoiceService(),
      tenantProfileService: const _FakeTenantProfileService(),
      initialRoom: const ActiveRoomItem(
        contractId: 24,
        contractCode: 'HD-2026-H104-24',
        roomId: 104,
        roomCode: '104',
        roomName: 'Phong 104',
        propertyName: 'Nha tro Hai Dang 1',
      ),
    );

    await provider.load();
    await Future<void>.delayed(Duration.zero);

    expect(homeService.requestedContractIds.first, 24);
    expect(provider.summary?.room?.roomCode, '104');
    expect(provider.selectedRoom?.contractId, 24);
  });

  test(
    'home provider derives a utility trend from the two newest invoices',
    () async {
      final provider = HomeProvider(
        homeService: const _FakeHomeService(),
        leaseContractService: const _FakeLeaseContractService(),
        tenantInvoiceService: const _TrendTenantInvoiceService(),
        tenantProfileService: const _FakeTenantProfileService(),
      );

      await provider.load();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      provider.selectRoom(
        const ActiveRoomItem(
          contractId: 23,
          contractCode: 'HD-2026-H103-23',
          roomId: 103,
          roomCode: '103',
          roomName: 'Phong 103',
          propertyName: 'Nha tro Hai Dang 1',
        ),
      );

      final trend = provider.electricityTrend;
      expect(trend, isNotNull);
      expect(trend!.invoice.billingPeriod, '2026-06');
      expect(trend.currentReading, 195);
      expect(trend.previousReading, 150);
      expect(trend.currentUsage, 45);
      expect(trend.previousUsage, 30);
      expect(trend.difference, 15);
      expect(trend.direction, UtilityTrendDirection.increase);
    },
  );

  test('invoice summary sums payable remaining amounts', () async {
    final provider = HomeProvider(
      homeService: const _FakeHomeService(),
      leaseContractService: const _FakeLeaseContractService(),
      tenantInvoiceService: const _TwoPayableInvoiceService(),
      tenantProfileService: const _FakeTenantProfileService(),
    );
    await provider.load();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(provider.payableInvoices, hasLength(2));
    expect(provider.invoiceSummary.totalUnpaidAmount, 1500000);
  });

  test(
    'electricity entries require the selected contract even in the same room',
    () {
      final entries = buildTenantScopedElectricityEntries(
        invoices: [
          _meterInvoice(id: 1, contractId: 23, period: '2026-06'),
          _meterInvoice(id: 2, contractId: 24, period: '2026-06'),
        ],
        selectedContractId: 24,
        occupancyStart: DateTime(2026, 5, 1),
      );

      expect(entries, hasLength(1));
      expect(entries.single.invoice.contractId, 24);
    },
  );

  test(
    'electricity entries honor move-in and conservatively omit ambiguous periods',
    () {
      final entries = buildTenantScopedElectricityEntries(
        invoices: [
          _meterInvoice(
            id: 1,
            contractId: 23,
            period: '2026-04',
            readingDate: DateTime(2026, 4, 30),
          ),
          _meterInvoice(
            id: 2,
            contractId: 23,
            period: '2026-05',
            readingDate: DateTime(2026, 5, 31),
          ),
          _meterInvoice(
            id: 3,
            contractId: 23,
            period: '2026-06',
            readingDate: DateTime(2026, 6, 30),
          ),
          _meterInvoice(id: 4, contractId: 23, period: '2026-05'),
        ],
        selectedContractId: 23,
        occupancyStart: DateTime(2026, 5, 15),
      );

      expect(entries.map((entry) => entry.invoice.id), [3, 2]);
      expect(entries.any((entry) => entry.invoice.id == 4), isFalse);
    },
  );
}
