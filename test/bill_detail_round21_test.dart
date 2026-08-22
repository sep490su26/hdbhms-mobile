import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/screens/payment/bill_detail_screen.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';

TenantInvoice _invoice({
  required int id,
  required String type,
  required List<TenantInvoiceLine> lines,
  int subtotal = 500000,
  int discount = 0,
  int total = 500000,
}) => TenantInvoice(
  id: id,
  invoiceCode: 'INV-$id',
  invoiceType: type,
  billingPeriod: '2026-12',
  status: 'ISSUED',
  roomId: 101,
  roomCode: 'P.101',
  contractId: 11,
  contractCode: 'HD-11',
  dueDate: DateTime(2026, 12, 20),
  issuedAt: DateTime(2026, 12, 1),
  paidAt: null,
  totalAmount: total,
  subtotalAmount: subtotal,
  discountAmount: discount,
  paidAmount: 0,
  remainingAmount: total,
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
  lines: lines,
  priceDifferenceSettlementType: null,
);

final _rentInvoice = _invoice(
  id: 101,
  type: 'RENT',
  subtotal: 13800000,
  discount: 500000,
  total: 13300000,
  lines: const [
    TenantInvoiceLine(
      id: 1,
      lineType: 'ROOM_RENT',
      description: 'Tiền phòng',
      quantity: 3,
      unitPrice: 4500000,
      amount: 13500000,
    ),
    TenantInvoiceLine(
      id: 2,
      lineType: 'SERVICE_FEE',
      description: 'Phí dịch vụ',
      quantity: 6,
      unitPrice: 50000,
      amount: 300000,
    ),
  ],
);

final _utilityInvoice = _invoice(
  id: 102,
  type: 'UTILITY',
  subtotal: 630000,
  discount: 30000,
  total: 600000,
  lines: const [
    TenantInvoiceLine(
      id: 3,
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

final _otherInvoice = _invoice(
  id: 103,
  type: 'OTHER',
  subtotal: 500000,
  discount: 50000,
  total: 450000,
  lines: const [
    TenantInvoiceLine(
      id: 4,
      lineType: 'MAINTENANCE_COMPENSATION',
      description: 'Chi phí sửa chữa thiết bị',
      quantity: 1,
      unitPrice: 500000,
      amount: 500000,
    ),
  ],
);

Future<void> _pumpDetail(WidgetTester tester, TenantInvoice invoice) async {
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
}

void _expectSectionOrder(WidgetTester tester, List<String> ids) {
  var previousTop = -1.0;
  for (final id in ids) {
    final finder = find.byKey(ValueKey(id));
    expect(finder, findsOneWidget, reason: 'missing $id');
    final top = tester.getTopLeft(finder).dy;
    expect(
      top,
      greaterThan(previousTop),
      reason: '$id must follow its predecessor',
    );
    previousTop = top;
  }
}

void _expectFullWidthCard(WidgetTester tester, String id, double width) {
  final rect = tester.getRect(find.byKey(ValueKey(id)));
  expect(rect.left, closeTo(16, 0.1));
  expect(rect.width, closeTo(width - 32, 0.1));
}

void main() {
  group('Round 21 BillDetail wireframe', () {
    testWidgets(
      'RENT uses the compact context, facts, discount and total order',
      (tester) async {
        await _pumpDetail(tester, _rentInvoice);

        _expectSectionOrder(tester, const [
          'bill-detail-hero',
          'bill-detail-context',
          'bill-detail-breakdown',
          'bill-detail-discount',
          'bill-detail-total',
          'bill-detail-actions',
        ]);
        final width = tester.getSize(find.byType(Scaffold)).width;
        _expectFullWidthCard(tester, 'bill-detail-hero', width);
        _expectFullWidthCard(tester, 'bill-detail-context', width);
        _expectFullWidthCard(tester, 'bill-detail-breakdown', width);
        final discountRect = tester.getRect(
          find.byKey(const ValueKey('bill-detail-discount')),
        );
        final totalRect = tester.getRect(
          find.byKey(const ValueKey('bill-detail-total')),
        );
        expect(totalRect.top - discountRect.bottom, closeTo(12, 0.1));
        expect(
          tester
              .getSize(find.byKey(const ValueKey('bill-detail-actions')))
              .height,
          54,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('bill-detail-hero-icon'))),
          const Size(44, 44),
        );
        expect(find.text('Thông tin kỳ thuê'), findsOneWidget);
        expect(find.text('Tiền phòng'), findsOneWidget);
        expect(find.text('Phí dịch vụ'), findsOneWidget);
        expect(find.text('Số tháng'), findsOneWidget);
        expect(find.text('Chu kỳ'), findsOneWidget);
        expect(find.text('Số người'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('bill-detail-line-details-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('bill-detail-line-details-1')),
          findsOneWidget,
        );
        expect(find.text('Cách tính'), findsNothing);
        expect(find.textContaining('×'), findsNothing);
      },
    );

    testWidgets('UTILITY keeps meter and complaint after the total', (
      tester,
    ) async {
      await _pumpDetail(tester, _utilityInvoice);

      _expectSectionOrder(tester, const [
        'bill-detail-hero',
        'bill-detail-breakdown',
        'bill-detail-discount',
        'bill-detail-total',
        'bill-detail-complaint',
        'bill-detail-actions',
      ]);
      expect(find.byKey(const ValueKey('bill-detail-context')), findsNothing);
      expect(find.text('Chỉ số điện'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bill-detail-line-details-0')),
        findsOneWidget,
      );
      expect(find.text('Kỳ trước'), findsOneWidget);
      expect(find.text('Kỳ này'), findsOneWidget);
      expect(find.text('Tiêu thụ'), findsOneWidget);
      expect(find.text('Gửi khiếu nại số điện'), findsOneWidget);
    });

    testWidgets('OTHER has invoice context and retains quantity one', (
      tester,
    ) async {
      await _pumpDetail(tester, _otherInvoice);

      _expectSectionOrder(tester, const [
        'bill-detail-hero',
        'bill-detail-context',
        'bill-detail-breakdown',
        'bill-detail-discount',
        'bill-detail-total',
        'bill-detail-actions',
      ]);
      expect(find.text('Thông tin hóa đơn'), findsOneWidget);
      expect(find.text('Kỳ hóa đơn'), findsNothing);
      expect(find.text('12/2026'), findsNothing);
      expect(find.text('Phòng P.101'), findsNothing);
      expect(find.text('P.101'), findsWidgets);
      expect(find.text('Chi phí sửa chữa thiết bị'), findsOneWidget);
      expect(find.text('Số lượng'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bill-detail-line-details-0')),
        findsOneWidget,
      );
    });

    testWidgets('known and unknown OTHER lines are never discarded', (
      tester,
    ) async {
      final known = _invoice(
        id: 104,
        type: 'OTHER',
        lines: const [
          TenantInvoiceLine(
            id: 5,
            lineType: 'VIOLATION_FINE',
            description: '',
            quantity: 1,
            unitPrice: 200000,
            amount: 200000,
          ),
        ],
        subtotal: 200000,
        total: 200000,
      );
      await _pumpDetail(tester, known);
      expect(find.text('Phạt vi phạm'), findsOneWidget);

      final unknown = _invoice(
        id: 105,
        type: 'OTHER',
        lines: const [
          TenantInvoiceLine(
            id: 6,
            lineType: 'FUTURE_OTHER_TYPE',
            description: 'Phụ phí phát sinh',
            quantity: 1,
            unitPrice: 125000,
            amount: 125000,
          ),
        ],
        subtotal: 125000,
        total: 125000,
      );
      await _pumpDetail(tester, unknown);
      expect(find.text('Phụ phí phát sinh'), findsOneWidget);
      expect(find.byKey(const ValueKey('bill-detail-line-0')), findsOneWidget);
    });

    testWidgets('empty lines do not render a fake breakdown or discount', (
      tester,
    ) async {
      final empty = _invoice(id: 106, type: 'OTHER', lines: const []);
      await _pumpDetail(tester, empty);

      expect(find.byKey(const ValueKey('bill-detail-breakdown')), findsNothing);
      expect(find.byKey(const ValueKey('bill-detail-discount')), findsNothing);
      expect(find.byKey(const ValueKey('bill-detail-total')), findsOneWidget);
      expect(find.byKey(const ValueKey('bill-detail-actions')), findsOneWidget);
    });

    testWidgets('all invoice types remain scroll-safe at target phone sizes', (
      tester,
    ) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const sizes = [
        Size(320, 640),
        Size(360, 800),
        Size(390, 844),
        Size(430, 932),
      ];

      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final invoice in [_rentInvoice, _utilityInvoice, _otherInvoice]) {
          await _pumpDetail(tester, invoice);
          expect(
            tester.takeException(),
            isNull,
            reason: '${invoice.invoiceType} at $size',
          );
          _expectFullWidthCard(tester, 'bill-detail-hero', size.width);
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -500),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'scroll at $size');
        }
      }
    });
  });
}
