import 'package:flutter/material.dart';

import '../../models/payment/tenant_invoice_model.dart';
import 'payment_success_page.dart';
import 'qr_payment_page.dart';

/// TEMPORARY: Màn hình chỉ dùng để xem trước UI thanh toán.
/// Xóa file này và nút gọi từ HomeScreen khi không còn cần preview.
class PaymentPreviewPage extends StatelessWidget {
  const PaymentPreviewPage({super.key});

  static final TenantInvoice _rentInvoice = _mockInvoice(
    id: -101,
    invoiceCode: 'RENT-DEMO-001',
    invoiceType: 'RENT',
    totalAmount: 4500000,
    transferDescription: 'THANHTOAN RENT DEMO 001',
    lines: const [
      TenantInvoiceLine(
        id: -101,
        lineType: 'RENT',
        description: 'Tiền phòng tháng 06/2026',
        quantity: 1,
        unitPrice: 4500000,
        amount: 4500000,
      ),
    ],
  );

  static final TenantInvoice _utilityInvoice = _mockInvoice(
    id: -102,
    invoiceCode: 'UTILITY-DEMO-001',
    invoiceType: 'UTILITY',
    totalAmount: 786000,
    transferDescription: 'THANHTOAN UTILITY DEMO 001',
    lines: const [
      TenantInvoiceLine(
        id: -102,
        lineType: 'ELECTRICITY',
        description: 'Tiền điện',
        quantity: 180,
        unitPrice: 3500,
        amount: 630000,
      ),
      TenantInvoiceLine(
        id: -103,
        lineType: 'WATER',
        description: 'Tiền nước',
        quantity: 12,
        unitPrice: 13000,
        amount: 156000,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xem thử màn thanh toán')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Dữ liệu bên dưới chỉ để xem giao diện, không tạo giao dịch thật.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          _PreviewButton(
            icon: Icons.apartment_rounded,
            title: 'QR thanh toán tiền phòng',
            subtitle: 'Xem giao diện QR loại RENT',
            onTap: () => _openQr(context, _rentInvoice),
          ),
          const SizedBox(height: 12),
          _PreviewButton(
            icon: Icons.bolt_rounded,
            title: 'QR điện nước & dịch vụ',
            subtitle: 'Xem giao diện QR loại UTILITY',
            onTap: () => _openQr(context, _utilityInvoice),
          ),
          const SizedBox(height: 12),
          _PreviewButton(
            icon: Icons.check_circle_rounded,
            title: 'Thành công - tiền phòng',
            subtitle: 'Danh sách chỉ hiển thị khoản tiền phòng',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      PaymentSuccessPage(invoice: _rentInvoice),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _PreviewButton(
            icon: Icons.verified_rounded,
            title: 'Thành công - điện nước',
            subtitle: 'Danh sách hiển thị đúng điện và nước',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      PaymentSuccessPage(invoice: _utilityInvoice),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openQr(BuildContext context, TenantInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QrPaymentPage(
          invoice: invoice,
          // Không gọi kiểm tra trạng thái trong lúc xem preview.
          pollInterval: const Duration(days: 1),
        ),
      ),
    );
  }

  static TenantInvoice _mockInvoice({
    required int id,
    required String invoiceCode,
    required String invoiceType,
    required int totalAmount,
    required String transferDescription,
    required List<TenantInvoiceLine> lines,
    String? priceDifferenceSettlementType,
  }) {
    return TenantInvoice(
      id: id,
      invoiceCode: invoiceCode,
      invoiceType: invoiceType,
      billingPeriod: '2026-06',
      status: 'ISSUED',
      roomId: -1,
      roomCode: 'P.203',
      contractId: -1,
      contractCode: 'HD-DEMO-001',
      dueDate: DateTime(2026, 6, 30),
      issuedAt: DateTime(2026, 6, 22),
      paidAt: null,
      totalAmount: totalAmount,
      paidAmount: 0,
      remainingAmount: totalAmount,
      paymentIntentId: null,
      checkoutUrl: '',
      qrCode:
          '00020101021238570010A00000072701270006970436011300123456789010208QRIBFTTA530370454${totalAmount.toString()}5802VN62${transferDescription.length.toString().padLeft(2, '0')}${transferDescription}6304ABCD',
      providerOrderCode: '',
      paymentLinkId: '',
      bankBin: '970436',
      bankShortName: 'Vietcombank',
      accountNumber: '001234567890',
      accountName: 'CONG TY HDBHMS',
      transferDescription: transferDescription,
      lines: lines,
      priceDifferenceSettlementType: priceDifferenceSettlementType,
    );
  }
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        minVerticalPadding: 16,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
