import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/models/payment/invoice_payment_presentation.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/screens/payment/bill_detail_screen.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/payment/payment_history_page.dart';
import 'package:hdbhms_mobile/screens/payment/payment_success_page.dart';
import 'package:hdbhms_mobile/screens/payment/qr_payment_page.dart';
import 'package:hdbhms_mobile/screens/payment/qr_receipt_download_page.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';

TenantInvoice _invoice({
  required int id,
  required String type,
  required List<TenantInvoiceLine> lines,
  int totalAmount = 100000,
  int subtotalAmount = 100000,
  int discountAmount = 0,
  String status = 'ISSUED',
}) {
  final isPaid = status == 'PAID';
  return TenantInvoice(
    id: id,
    invoiceCode: 'INV-$id',
    invoiceType: type,
    billingPeriod: '2026-06',
    status: status,
    roomId: 101,
    roomCode: 'P.101',
    contractId: 11,
    contractCode: 'HD-11',
    dueDate: DateTime(2026, 6, 20),
    issuedAt: DateTime(2026, 6, 1),
    paidAt: isPaid ? DateTime(2026, 6, 4) : null,
    totalAmount: totalAmount,
    subtotalAmount: subtotalAmount,
    discountAmount: discountAmount,
    paidAmount: isPaid ? totalAmount : 0,
    remainingAmount: isPaid ? 0 : totalAmount,
    paymentIntentId: null,
    checkoutUrl: '',
    qrCode: '0002010102123857$id',
    providerOrderCode: '',
    paymentLinkId: '',
    bankBin: '970436',
    bankShortName: 'Vietcombank',
    accountNumber: '001234567890',
    accountName: 'HDBHMS',
    transferDescription: 'THANHTOAN INV-$id',
    lines: lines,
    priceDifferenceSettlementType: null,
  );
}

final _rentInvoice = _invoice(
  id: 1,
  type: 'RENT',
  totalAmount: 13300000,
  subtotalAmount: 13800000,
  discountAmount: 500000,
  lines: const [
    TenantInvoiceLine(
      id: 11,
      lineType: 'ROOM_RENT',
      description: 'Tiền phòng kỳ 06/2026',
      quantity: 3,
      unitPrice: 4500000,
      amount: 13500000,
    ),
    TenantInvoiceLine(
      id: 12,
      lineType: 'SERVICE_FEE',
      description: 'Phí dịch vụ kỳ 06/2026',
      quantity: 6,
      unitPrice: 50000,
      amount: 300000,
    ),
  ],
);

final _electricityInvoice = _invoice(
  id: 2,
  type: 'UTILITY',
  totalAmount: 600000,
  subtotalAmount: 630000,
  discountAmount: 30000,
  lines: const [
    TenantInvoiceLine(
      id: 21,
      lineType: 'ELECTRICITY',
      description: 'Tiền điện',
      quantity: 180,
      unitPrice: 3500,
      amount: 630000,
      previousValue: 1010,
      currentValue: 1190,
      usageAmount: 180,
      canComplain: true,
    ),
  ],
);

final _otherDiscountInvoice = _invoice(
  id: 3,
  type: 'OTHER',
  totalAmount: 450000,
  subtotalAmount: 500000,
  discountAmount: 50000,
  lines: const [
    TenantInvoiceLine(
      id: 31,
      lineType: 'MAINTENANCE_COMPENSATION',
      description: 'Chi phí sửa chữa',
      quantity: 1,
      unitPrice: 500000,
      amount: 500000,
    ),
  ],
);

class _InvoiceService extends TenantInvoiceService {
  const _InvoiceService(this.invoices);

  final List<TenantInvoice> invoices;

  @override
  Future<List<TenantInvoice>> fetchMyInvoices({
    int? roomId,
    String? roomCode,
  }) async => invoices;
}

class _NoopNotificationService extends NotificationService {
  const _NoopNotificationService();

  @override
  Future<int> getUnreadCount({int? roomId, String? roomCode}) async => 0;

  @override
  Future<void> markTargetAsRead({
    required String targetType,
    required int targetId,
  }) async {}
}

void main() {
  group('Round 19 invoice taxonomy', () {
    test('model and central presentation use the new backend taxonomy', () {
      final legacyUtility = _invoice(
        id: 4,
        type: 'UTILITY',
        totalAmount: 700000,
        lines: const [
          TenantInvoiceLine(
            id: 41,
            lineType: 'ELECTRICITY',
            description: '',
            quantity: 100,
            unitPrice: 3500,
            amount: 350000,
          ),
          TenantInvoiceLine(
            id: 42,
            lineType: 'SERVICE_FEE',
            description: '',
            quantity: 7,
            unitPrice: 50000,
            amount: 350000,
          ),
        ],
      );

      expect(_rentInvoice.invoiceTypeLabel, 'Tiền phòng & dịch vụ');
      expect(_rentInvoice.title, 'Hóa đơn tiền phòng & dịch vụ tháng 06/2026');
      expect(_electricityInvoice.invoiceTypeLabel, 'Tiền điện');
      expect(_electricityInvoice.title, 'Hóa đơn tiền điện tháng 06/2026');
      expect(legacyUtility.isLegacyUtilityWithService, isTrue);
      expect(legacyUtility.invoiceTypeLabel, 'Tiền điện & dịch vụ');

      final rent = InvoicePaymentPresentation.fromInvoice(_rentInvoice);
      expect(rent.displayName, 'Tiền phòng & dịch vụ');
      expect(rent.paymentPageTitle, 'Thanh toán tiền phòng & dịch vụ');
      expect(rent.receiptHeading, 'THANH TOÁN TIỀN PHÒNG & DỊCH VỤ');

      final electricity = InvoicePaymentPresentation.fromInvoice(
        _electricityInvoice,
      );
      expect(electricity.displayName, 'Tiền điện');
      expect(electricity.paymentPageTitle, 'Thanh toán tiền điện');
      expect(electricity.receiptHeading, 'THANH TOÁN TIỀN ĐIỆN');

      final legacy = InvoicePaymentPresentation.fromInvoice(legacyUtility);
      expect(legacy.displayName, 'Tiền điện & dịch vụ');
      expect(legacy.paymentPageTitle, 'Thanh toán tiền điện & dịch vụ');
    });

    testWidgets('RENT detail keeps rent and service facts without formulas', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BillDetailScreen(
            invoice: _rentInvoice,
            invoiceService: const TenantInvoiceService(),
            servicePaymentCycleMonths: 3,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tiền phòng & dịch vụ'), findsOneWidget);
      expect(find.text('Tiền phòng'), findsOneWidget);
      expect(find.text('Phí dịch vụ'), findsOneWidget);
      expect(find.text('Đơn giá'), findsNWidgets(2));
      expect(find.text('Số tháng'), findsOneWidget);
      expect(find.text('Chu kỳ'), findsOneWidget);
      expect(find.text('Số người'), findsOneWidget);
      expect(find.text('Giảm giá đã áp dụng'), findsOneWidget);
      expect(find.text('Tổng cộng'), findsOneWidget);
      expect(find.text('Cách tính'), findsNothing);
      expect(find.textContaining('×'), findsNothing);
    });

    testWidgets('electricity detail keeps meter data and complaint action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BillDetailScreen(
            invoice: _electricityInvoice,
            invoiceService: const TenantInvoiceService(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tiền điện'), findsNWidgets(2));
      expect(find.text('Phí dịch vụ'), findsNothing);
      expect(find.text('Chỉ số điện'), findsOneWidget);
      expect(find.text('Kỳ trước'), findsOneWidget);
      expect(find.text('Kỳ này'), findsOneWidget);
      expect(find.text('Tiêu thụ'), findsOneWidget);
      expect(find.text('Đơn giá'), findsOneWidget);
      expect(find.text('Gửi khiếu nại số điện'), findsOneWidget);
      expect(find.text('Giảm giá đã áp dụng'), findsOneWidget);
    });

    testWidgets('existing electricity review still has complaint status', (
      tester,
    ) async {
      final reviewed = _invoice(
        id: 5,
        type: 'UTILITY',
        lines: const [
          TenantInvoiceLine(
            id: 51,
            lineType: 'ELECTRICITY',
            description: '',
            quantity: 12,
            unitPrice: 3500,
            amount: 42000,
            reviewStatus: 'UNDER_REVIEW',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BillDetailScreen(
            invoice: reviewed,
            invoiceService: const TenantInvoiceService(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Trạng thái khiếu nại'), findsOneWidget);
      expect(find.text('Gửi khiếu nại số điện'), findsNothing);
    });

    testWidgets('discount is rendered for every invoice type only when sent', (
      tester,
    ) async {
      for (final invoice in [
        _rentInvoice,
        _electricityInvoice,
        _otherDiscountInvoice,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: BillDetailScreen(
              invoice: invoice,
              invoiceService: const TenantInvoiceService(),
              servicePaymentCycleMonths: invoice.isRentType ? 3 : null,
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Giảm giá đã áp dụng'), findsOneWidget);
      }

      final noDiscount = _invoice(
        id: 6,
        type: 'UTILITY',
        lines: _electricityInvoice.lines,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BillDetailScreen(
            invoice: noDiscount,
            invoiceService: const TenantInvoiceService(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Giảm giá đã áp dụng'), findsNothing);
    });

    testWidgets('bill selection and history expose the same taxonomy filters', (
      tester,
    ) async {
      final other = _invoice(id: 7, type: 'OTHER', lines: const []);
      await tester.pumpWidget(
        MaterialApp(
          home: BillSelectionPage(
            notificationInitialUnreadCount: 0,
            notificationService: const _NoopNotificationService(),
            roomCode: 'P.101',
            invoiceService: _InvoiceService([
              _rentInvoice,
              _electricityInvoice,
              other,
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Tiền phòng & dịch vụ'), findsWidgets);
      expect(find.text('Tiền điện'), findsWidgets);
      expect(find.text('Tiền điện & dịch vụ'), findsNothing);
      expect(
        find.text('Hóa đơn tiền phòng & dịch vụ tháng 06/2026'),
        findsOneWidget,
      );
      expect(find.text('Hóa đơn tiền điện tháng 06/2026'), findsOneWidget);

      final electricityFilter = find.text('Tiền điện').first;
      await tester.ensureVisible(electricityFilter);
      await tester.tap(electricityFilter);
      await tester.pumpAndSettle();
      expect(find.text('Hóa đơn tiền điện tháng 06/2026'), findsOneWidget);
      expect(
        find.text('Hóa đơn tiền phòng & dịch vụ tháng 06/2026'),
        findsNothing,
      );

      final paidRent = _invoice(
        id: 8,
        type: 'RENT',
        lines: const [],
        status: 'PAID',
      );
      final paidElectricity = _invoice(
        id: 9,
        type: 'UTILITY',
        lines: const [],
        status: 'PAID',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentHistoryPage(
            invoiceService: _InvoiceService([paidRent, paidElectricity]),
            notificationService: const _NoopNotificationService(),
            roomCode: 'P.101',
            notificationInitialUnreadCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Tiền phòng & dịch vụ'), findsWidgets);
      expect(find.text('Tiền điện'), findsWidgets);
      expect(find.text('Mọi loại'), findsNothing);
      final historyElectricityFilter = find.text('Tiền điện').first;
      await tester.ensureVisible(historyElectricityFilter);
      await tester.tap(historyElectricityFilter);
      await tester.pumpAndSettle();
      expect(find.text('Hóa đơn tiền điện tháng 06/2026'), findsOneWidget);
      expect(
        find.text('Hóa đơn tiền phòng & dịch vụ tháng 06/2026'),
        findsNothing,
      );

      final rentFilter = find.text('Tiền phòng & dịch vụ').first;
      await tester.ensureVisible(rentFilter);
      await tester.tap(rentFilter);
      await tester.pumpAndSettle();
      expect(
        find.text('Hóa đơn tiền phòng & dịch vụ tháng 06/2026'),
        findsOneWidget,
      );
      expect(find.text('Hóa đơn tiền điện tháng 06/2026'), findsNothing);
    });

    testWidgets('QR, receipt, and success use the new labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QrPaymentPage(
            invoice: _rentInvoice,
            pollInterval: const Duration(days: 1),
            notificationService: const _NoopNotificationService(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Thanh toán tiền phòng & dịch vụ'), findsWidgets);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: QrReceiptTemplate(invoice: _electricityInvoice),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('THANH TOÁN TIỀN ĐIỆN'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(home: PaymentSuccessPage(invoice: _rentInvoice)),
      );
      await tester.pump();
      expect(find.text('Tiền phòng & dịch vụ'), findsOneWidget);
      expect(find.text('Tiền phòng'), findsOneWidget);
      expect(find.text('Phí dịch vụ'), findsOneWidget);
    });

    for (final size in const [
      Size(320, 640),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ]) {
      testWidgets('rent detail stays usable at ${size.width}×${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: BillDetailScreen(
              invoice: _rentInvoice,
              invoiceService: const TenantInvoiceService(),
              servicePaymentCycleMonths: 3,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Tiền phòng & dịch vụ'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
