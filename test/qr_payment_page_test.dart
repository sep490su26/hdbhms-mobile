import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/screens/payment/bill_detail_screen.dart';
import 'package:hdbhms_mobile/screens/payment/qr_payment_page.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('renders VietQR payload as a generated QR code', (tester) async {
    const invoice = TenantInvoice(
      id: null,
      invoiceCode: 'SEED-INV-503-TRANSFER-OUT-ISSUED',
      invoiceType: 'UTILITY',
      billingPeriod: '',
      status: 'ISSUED',
      roomId: null,
      roomCode: '401',
      contractId: null,
      contractCode: '',
      dueDate: null,
      issuedAt: null,
      paidAt: null,
      totalAmount: 480000,
      paidAmount: 0,
      remainingAmount: 480000,
      paymentIntentId: null,
      checkoutUrl: '',
      qrCode: '0002010102123857',
      providerOrderCode: '',
      paymentLinkId: '',
      bankBin: '',
      bankShortName: '',
      accountNumber: '',
      accountName: '',
      transferDescription: 'SEED-INV-503-TRANSFER-OUT-ISSUED',
      lines: [],
      priceDifferenceSettlementType: null,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: QrPaymentPage(invoice: invoice, pollInterval: Duration(days: 1)),
      ),
    );

    expect(invoice.payosQrValue, '0002010102123857');
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Mã QR chưa sẵn sàng'), findsNothing);
  });

  testWidgets('Bill detail pushes QR and keeps a normal back route', (
    tester,
  ) async {
    const invoice = TenantInvoice(
      id: 7,
      invoiceCode: 'INV-7',
      invoiceType: 'UTILITY',
      billingPeriod: '2026-06',
      status: 'ISSUED',
      roomId: 101,
      roomCode: 'P.101',
      contractId: 11,
      contractCode: 'HD-11',
      dueDate: null,
      issuedAt: null,
      paidAt: null,
      totalAmount: 480000,
      paidAmount: 0,
      remainingAmount: 480000,
      paymentIntentId: null,
      checkoutUrl: '',
      qrCode: '0002010102123857',
      providerOrderCode: '',
      paymentLinkId: '',
      bankBin: '',
      bankShortName: '',
      accountNumber: '',
      accountName: '',
      transferDescription: 'INV-7',
      lines: [],
      priceDifferenceSettlementType: null,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: BillDetailScreen(
          invoice: invoice,
          invoiceService: TenantInvoiceService(),
        ),
      ),
    );
    await tester.tap(find.text('Thanh toán ngay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(QrPaymentPage), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Đang tự động kiểm tra thanh toán'),
      find.byType(CustomScrollView),
      const Offset(0, -180),
    );
    await tester.pump();
    expect(find.text('Đang tự động kiểm tra thanh toán'), findsOneWidget);
    expect(find.text('Tôi đã chuyển khoản'), findsNothing);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BillDetailScreen), findsOneWidget);
    expect(find.text('Chi tiết hóa đơn'), findsOneWidget);
    expect(find.text('Xem chi tiết và thanh toán'), findsNothing);
  });
}
