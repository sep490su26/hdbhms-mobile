import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/models/home/electricity_consumption_entry.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/screens/home/electricity_consumption_history_screen.dart';

ElectricityConsumptionEntry _entry({
  required String period,
  required double usage,
  int amount = 90000,
}) {
  final line = TenantInvoiceLine(
    id: 1,
    lineType: 'ELECTRICITY',
    description: 'Tiền điện',
    quantity: usage.round(),
    unitPrice: 3000,
    amount: amount,
    readingPeriod: period,
    previousValue: 120,
    currentValue: 120 + usage,
    usageAmount: usage,
  );
  final invoice = TenantInvoice(
    id: 1,
    invoiceCode: 'INV-$period',
    invoiceType: 'UTILITY',
    billingPeriod: period,
    status: 'PAID',
    roomId: 103,
    roomCode: '103',
    contractId: 23,
    contractCode: 'HD-23',
    dueDate: null,
    issuedAt: DateTime(2026, int.parse(period.substring(5)), 28),
    paidAt: null,
    totalAmount: amount,
    paidAmount: amount,
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
    lines: [line],
    priceDifferenceSettlementType: null,
  );
  return ElectricityConsumptionEntry(
    invoice: invoice,
    line: line,
    periodKey: period,
    periodLabel: 'Kỳ ${period.substring(5)}/${period.substring(0, 4)}',
    referenceDate: invoice.issuedAt!,
    previousReading: line.previousValue,
    currentReading: line.currentValue,
    usage: usage,
    unitPrice: line.unitPrice,
    amount: amount,
  );
}

Widget _screen(List<ElectricityConsumptionEntry> entries) => MaterialApp(
  home: ElectricityConsumptionHistoryScreen(
    entries: entries,
    roomLabel: 'Phòng 103',
    occupancyStart: DateTime(2026, 5, 15),
  ),
);

void main() {
  test('chart points fill only eligible gaps and use a round axis', () {
    final points = buildElectricityChartPoints(
      entries: [
        _entry(period: '2026-08', usage: 73.7),
        _entry(period: '2026-05', usage: 47),
      ],
      occupancyStart: DateTime(2026, 5, 15),
    );

    expect(points.map((point) => point.month.month), [5, 6, 7, 8]);
    expect(points.map((point) => point.hasReading), [true, false, false, true]);
    expect(
      points
          .where((point) => !point.hasReading)
          .every((point) => point.usage == 0),
      isTrue,
    );
    expect(buildElectricityChartAxis([47]).ticks, [0, 20, 40, 60]);
    expect(buildElectricityChartAxis([221]).ticks, [0, 100, 200, 300]);
    expect(formatElectricityChartMonth(DateTime(2026, 6)), 'T6');
    expect(
      formatElectricityChartMonth(DateTime(2026, 1), includeYear: true),
      'T1/26',
    );
  });

  testWidgets('history empty state remains usable', (tester) async {
    await tester.pumpWidget(_screen(const []));

    expect(find.text('Lịch sử tiêu thụ điện'), findsOneWidget);
    expect(find.text('Chưa có dữ liệu tiêu thụ điện'), findsOneWidget);
  });

  testWidgets('history shows one and multiple periods with correct units', (
    tester,
  ) async {
    await tester.pumpWidget(_screen([_entry(period: '2026-06', usage: 30)]));

    expect(find.text('Từ 15/05/2026'), findsOneWidget);
    expect(find.text('30 kWh'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(find.text('3.000 đ/kWh'), findsOneWidget);
    expect(find.text('90.000 đ'), findsOneWidget);

    await tester.pumpWidget(
      _screen([
        _entry(period: '2026-07', usage: 45),
        _entry(period: '2026-06', usage: 30),
      ]),
    );
    expect(find.text('Biểu đồ tiêu thụ điện'), findsOneWidget);
    expect(find.text('Đơn vị: kWh'), findsOneWidget);
    expect(
      find.text(
        'Tháng chưa có kỳ ghi nhận được hiển thị ở mức 0 trên biểu đồ.',
      ),
      findsOneWidget,
    );
    expect(find.text('Kỳ 07/2026'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Kỳ 06/2026'), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });

  testWidgets('history layout stays scroll-safe at supported mobile widths', (
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
        _screen([
          _entry(period: '2026-07', usage: 45),
          _entry(period: '2026-06', usage: 30),
          _entry(period: '2026-05', usage: 25),
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Phòng 103'), findsOneWidget);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
