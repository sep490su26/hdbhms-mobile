import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';

TenantInvoice _invoice({
  required int id,
  required String status,
  required int remainingAmount,
  required String roomCode,
}) => TenantInvoice(
  id: id,
  invoiceCode: 'INV-$id',
  invoiceType: 'RENT',
  billingPeriod: '2026-06',
  status: status,
  roomId: id,
  roomCode: roomCode,
  contractId: 10,
  contractCode: 'HD-10',
  dueDate: DateTime(2026, 6, 20),
  issuedAt: DateTime(2026, 6, 1),
  paidAt: status == 'PAID' ? DateTime(2026, 6, 2) : null,
  totalAmount: 500000,
  paidAmount: status == 'PAID' ? 500000 : 0,
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
  lines: const [],
  priceDifferenceSettlementType: null,
);

void main() {
  testWidgets('bill selection only shows unpaid invoices and type filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BillSelectionPage(
          notificationInitialUnreadCount: 0,
          previewInvoices: [
            _invoice(
              id: 1,
              status: 'ISSUED',
              remainingAmount: 500000,
              roomCode: 'P.101',
            ),
            _invoice(
              id: 2,
              status: 'PAID',
              remainingAmount: 0,
              roomCode: 'P.202',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hóa đơn cần thanh toán'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    expect(find.text('Chưa thanh toán'), findsNothing);
    expect(find.text('Phòng P.101'), findsOneWidget);
    expect(find.text('Phòng P.202'), findsNothing);
  });

  testWidgets('all-paid invoices use the required-payment empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BillSelectionPage(
          notificationInitialUnreadCount: 0,
          previewInvoices: [
            _invoice(
              id: 2,
              status: 'PAID',
              remainingAmount: 0,
              roomCode: 'P.202',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không có khoản cần thanh toán'), findsOneWidget);
    expect(
      find.text('Các hóa đơn đã thanh toán được lưu trong Lịch sử thanh toán.'),
      findsOneWidget,
    );
  });
}
