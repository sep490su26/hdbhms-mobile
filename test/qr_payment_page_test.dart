import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/screens/payment/qr_payment_page.dart';
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
}
