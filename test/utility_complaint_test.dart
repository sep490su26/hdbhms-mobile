import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/screens/payment/utility_complaint_screen.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';

class _RecordingInvoiceService extends TenantInvoiceService {
  _RecordingInvoiceService();

  double? reportedCurrentValue;
  String? description;
  int? invoiceId;
  int? lineId;

  @override
  Future<void> submitMeterReadingReview({
    required int invoiceId,
    required int lineId,
    required double reportedCurrentValue,
    required String description,
  }) async {
    this.invoiceId = invoiceId;
    this.lineId = lineId;
    this.reportedCurrentValue = reportedCurrentValue;
    this.description = description;
  }
}

TenantInvoice _invoice() => TenantInvoice(
  id: 1203,
  invoiceCode: 'INV-12',
  invoiceType: 'UTILITY',
  billingPeriod: '2026-08',
  status: 'ISSUED',
  roomId: 103,
  roomCode: '103',
  contractId: 9,
  contractCode: 'HD-201',
  dueDate: DateTime(2026, 8, 10),
  issuedAt: DateTime(2026, 8, 1),
  paidAt: null,
  totalAmount: 450000,
  paidAmount: 0,
  remainingAmount: 450000,
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
  lines: const [
    TenantInvoiceLine(
      id: 8803,
      lineType: 'ELECTRICITY',
      description: 'Điện tháng 08/2026',
      quantity: 50,
      unitPrice: 3000,
      amount: 150000,
      previousValue: 100,
      currentValue: 150,
      usageAmount: 50,
      canComplain: true,
    ),
  ],
  priceDifferenceSettlementType: null,
);

void main() {
  testWidgets('meter complaint validates and submits tenant reported value', (
    tester,
  ) async {
    final service = _RecordingInvoiceService();
    await tester.pumpWidget(
      MaterialApp(
        home: UtilityComplaintScreen(
          invoice: _invoice(),
          invoiceService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reportedValue = find.byKey(const Key('meter-reported-current-value'));
    final description = find.byType(TextFormField).last;
    final submit = find.byKey(const Key('meter-complaint-submit'));

    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Vui lòng nhập chỉ số điện hợp lệ'), findsOneWidget);

    await tester.enterText(reportedValue, '99');
    await tester.enterText(
      description,
      'Chỉ số điện trên đồng hồ thực tế thấp hơn.',
    );
    await tester.tap(submit);
    await tester.pump();
    expect(find.textContaining('không được nhỏ hơn chỉ số cũ'), findsOneWidget);
    expect(service.reportedCurrentValue, isNull);

    await tester.enterText(reportedValue, '130');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(service.reportedCurrentValue, 130);
    expect(service.invoiceId, 1203);
    expect(service.lineId, 8803);
    expect(service.description, 'Chỉ số điện trên đồng hồ thực tế thấp hơn.');
  });
}
