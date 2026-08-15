import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/payment/invoice_payment_presentation.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/screens/room_transfer/create_room_transfer_screen.dart';
import 'package:hdbhms_mobile/screens/payment/payment_success_page.dart';
import 'package:hdbhms_mobile/screens/payment/bill_detail_screen.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/utils/user_facing_error_message.dart';
import 'package:hdbhms_mobile/widgets/app_action_tile.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';

TenantInvoice _invoice({
  required String type,
  List<TenantInvoiceLine> lines = const [],
}) => TenantInvoice(
  id: 1,
  invoiceCode: 'INV-001',
  invoiceType: type,
  billingPeriod: '2026-08',
  status: 'ISSUED',
  roomId: 1,
  roomCode: 'P.101',
  contractId: 1,
  contractCode: 'HD-001',
  dueDate: DateTime(2026, 8, 20),
  issuedAt: DateTime(2026, 8, 1),
  paidAt: null,
  totalAmount: 900000,
  subtotalAmount: 1000000,
  discountAmount: 100000,
  paidAmount: 0,
  remainingAmount: 900000,
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

void main() {
  group('Round 14 presentation', () {
    test('first day of next month handles August and December rollover', () {
      expect(firstDayOfNextMonth(DateTime(2026, 8, 15)), DateTime(2026, 9));
      expect(firstDayOfNextMonth(DateTime(2026, 12, 20)), DateTime(2027, 1));
    });

    test('parses invoice subtotal and discount without changing total', () {
      final invoice = TenantInvoice.fromJson({
        'totalAmount': 900000,
        'subtotalAmount': 1000000,
        'discountAmount': 100000,
      });
      expect(invoice.totalAmount, 900000);
      expect(invoice.resolvedSubtotalAmount, 1000000);
      expect(invoice.discountAmount, 100000);
    });

    test('maintenance OTHER gets its own payment semantics', () {
      final presentation = InvoicePaymentPresentation.fromInvoice(
        _invoice(
          type: 'OTHER',
          lines: const [
            TenantInvoiceLine(
              id: 2,
              lineType: 'MAINTENANCE_COMPENSATION',
              description: '',
              quantity: 1,
              unitPrice: 450000,
              amount: 450000,
            ),
          ],
        ),
      );
      expect(presentation.paymentPageTitle, 'Thanh toán chi phí sửa chữa');
      expect(presentation.receiptHeading, 'THANH TOÁN CHI PHÍ SỬA CHỮA');
    });

    test('technical raw errors are not exposed to tenants', () {
      expect(
        toUserFacingMessage('INVALID_REQUEST'),
        'Yêu cầu không hợp lệ. Vui lòng kiểm tra thông tin và thử lại.',
      );
      expect(
        toUserFacingMessage('Phòng đích không đủ sức chứa.'),
        'Phòng đích không đủ sức chứa.',
      );
    });

    testWidgets('full action tile stays visible but is semantically disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppActionTile(
              icon: Icons.person_add_outlined,
              label: 'Thêm người ở cùng',
              accentColor: Colors.green,
              enabled: false,
              disabledReason: 'Phòng đã đủ số người tối đa.',
            ),
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(AppActionTile));
      expect(
        semantics.flagsCollection.isEnabled.toString(),
        'Tristate.isFalse',
      );
      expect(find.text('Thêm người ở cùng'), findsOneWidget);
    });

    testWidgets('maintenance success has no top bar or paid chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentSuccessPage(
            invoice: _invoice(
              type: 'OTHER',
              lines: const [
                TenantInvoiceLine(
                  id: 3,
                  lineType: 'MAINTENANCE_COMPENSATION',
                  description: '',
                  quantity: 1,
                  unitPrice: 450000,
                  amount: 450000,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AppTopBar), findsNothing);
      expect(find.text('Chi phí sửa chữa'), findsOneWidget);
      expect(find.text('ĐÃ THANH TOÁN'), findsNothing);
    });

    testWidgets(
      'invoice detail keeps one grand total without repeating the billing period',
      (tester) async {
        final invoice = _invoice(
          type: 'RENT',
          lines: const [
            TenantInvoiceLine(
              id: 4,
              lineType: 'ROOM_RENT',
              description: 'Tiền phòng',
              quantity: 1,
              unitPrice: 4500000,
              amount: 4500000,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BillDetailScreen(
              invoice: invoice,
              invoiceService: const TenantInvoiceService(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Tổng cộng'), findsOneWidget);
        expect(find.text('Đã thanh toán'), findsNothing);
        expect(find.text('Còn phải trả'), findsNothing);
        expect(find.text('Đơn giá'), findsOneWidget);
        expect(find.text('Số tháng'), findsOneWidget);
        expect(find.text('Cách tính'), findsNothing);
        expect(find.text('4.500.000đ × 1 tháng'), findsNothing);
        expect(find.text('Phòng P.101'), findsNothing);
        expect(find.byIcon(Icons.meeting_room_outlined), findsOneWidget);
        expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
      },
    );
  });
}
