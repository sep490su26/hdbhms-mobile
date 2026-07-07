import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/providers/home_provider.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';

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
}

class _FakeTenantInvoiceService extends TenantInvoiceService {
  const _FakeTenantInvoiceService();

  @override
  Future<List<TenantInvoice>> fetchMyInvoices() async {
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

void main() {
  test(
    'home provider uses tenant invoice API and filters by selected room',
    () async {
      final provider = HomeProvider(
        homeService: const _FakeHomeService(),
        leaseContractService: const _FakeLeaseContractService(),
        tenantInvoiceService: const _FakeTenantInvoiceService(),
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
}
