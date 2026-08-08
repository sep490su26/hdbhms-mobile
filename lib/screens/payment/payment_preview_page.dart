import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

import '../../models/payment/tenant_invoice_model.dart';
import '../../services/payment/tenant_invoice_service.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_screen_shell.dart';
import '../../widgets/app_top_bar.dart';
import 'bill_detail_screen.dart';
import 'payment_success_page.dart';
import 'payment_history_page.dart';
import 'qr_payment_page.dart';
import 'qr_receipt_download_page.dart';
import 'utility_complaint_screen.dart';

/// Internal launcher for validating production payment flows with sample data.
class PaymentPreviewPage extends StatelessWidget {
  const PaymentPreviewPage({super.key});

  static const TenantInvoiceService _invoiceService =
      _PreviewTenantInvoiceService();

  static final TenantInvoice _rentInvoice = _invoice(
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

  static final TenantInvoice _utilityInvoice = _invoice(
    id: -102,
    invoiceCode: 'UTILITY-DEMO-001',
    invoiceType: 'UTILITY',
    totalAmount: 906000,
    transferDescription: 'THANHTOAN UTILITY DEMO 001',
    lines: const [
      TenantInvoiceLine(
        id: -102,
        lineType: 'ELECTRICITY',
        description: 'Tiền điện',
        quantity: 180,
        unitPrice: 3500,
        amount: 630000,
        previousValue: 1010,
        currentValue: 1190,
        usageAmount: 180,
      ),
      TenantInvoiceLine(
        id: -106,
        lineType: 'SERVICE',
        description: 'Phí dịch vụ',
        quantity: 1,
        unitPrice: 276000,
        amount: 276000,
      ),
    ],
  );

  static final TenantInvoice _reviewableUtilityInvoice = _invoice(
    id: -104,
    invoiceCode: 'UTILITY-DEMO-002',
    invoiceType: 'UTILITY',
    totalAmount: 1037000,
    transferDescription: 'THANHTOAN UTILITY DEMO 002',
    lines: const [
      TenantInvoiceLine(
        id: -104,
        lineType: 'ELECTRICITY',
        description: 'Tiền điện',
        quantity: 210,
        unitPrice: 3500,
        amount: 735000,
        previousValue: 1240,
        currentValue: 1450,
        usageAmount: 210,
        canComplain: true,
        reviewStatus: 'NONE',
      ),
      TenantInvoiceLine(
        id: -105,
        lineType: 'SERVICE',
        description: 'Phí dịch vụ',
        quantity: 1,
        unitPrice: 302000,
        amount: 302000,
      ),
    ],
  );

  static final List<TenantInvoice> _paidHistoryInvoices = [
    _paidHistoryInvoice(
      id: -201,
      invoiceCode: 'RENT-2025-01',
      invoiceType: 'RENT',
      amount: 4200000,
      month: DateTime(2025, 1, 18),
    ),
    _paidHistoryInvoice(
      id: -202,
      invoiceCode: 'UTILITY-2025-04',
      invoiceType: 'UTILITY',
      amount: 884000,
      month: DateTime(2025, 4, 12),
    ),
    _paidHistoryInvoice(
      id: -203,
      invoiceCode: 'RENT-2025-08',
      invoiceType: 'RENT',
      amount: 4400000,
      month: DateTime(2025, 8, 5),
    ),
    _paidHistoryInvoice(
      id: -204,
      invoiceCode: 'UTILITY-2025-12',
      invoiceType: 'UTILITY',
      amount: 965000,
      month: DateTime(2025, 12, 22),
    ),
    _paidHistoryInvoice(
      id: -205,
      invoiceCode: 'RENT-2026-03',
      invoiceType: 'RENT',
      amount: 4500000,
      month: DateTime(2026, 3, 9),
    ),
    _paidHistoryInvoice(
      id: -206,
      invoiceCode: 'UTILITY-2026-07',
      invoiceType: 'UTILITY',
      amount: 1037000,
      month: DateTime(2026, 7, 20),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: AppTopBar(
            title: 'Xem trước thanh toán',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
            children: [
              const Text('Luồng hóa đơn', style: AppTypography.pageTitle),
              const SizedBox(height: 6),
              const Text(
                'Dữ liệu mẫu chỉ phục vụ kiểm tra giao diện và không tạo giao dịch.',
                style: AppTypography.body,
              ),
              const SizedBox(height: 20),
              const _PreviewSectionTitle('Hóa đơn'),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.receipt_long_rounded,
                title: 'Chi tiết hóa đơn tiền phòng',
                subtitle: 'Kiểm tra loại, trạng thái và thanh toán',
                onTap: () => _openBillDetail(context, _rentInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.receipt_long_rounded,
                title: 'Chi tiết hóa đơn tiền điện & dịch vụ',
                subtitle: 'Hiển thị chỉ số và quyền khiếu nại',
                onTap: () =>
                    _openBillDetail(context, _reviewableUtilityInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.report_problem_outlined,
                title: 'Khiếu nại tiền điện',
                subtitle: 'Kiểm tra form phản hồi chỉ số',
                onTap: () => _openComplaint(context, _reviewableUtilityInvoice),
              ),
              const SizedBox(height: 20),
              const _PreviewSectionTitle('Thanh toán'),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.qr_code_rounded,
                title: 'QR tiền phòng',
                subtitle: 'Hóa đơn tiền phòng',
                onTap: () => _openQr(context, _rentInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.qr_code_rounded,
                title: 'QR tiền điện & dịch vụ',
                subtitle: 'Hóa đơn tiền điện & dịch vụ',
                onTap: () => _openQr(context, _utilityInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.check_circle_outline_rounded,
                title: 'Thanh toán thành công tiền phòng',
                subtitle: 'Trạng thái hoàn tất của hóa đơn tiền phòng',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        PaymentSuccessPage(invoice: _rentInvoice),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.check_circle_outline_rounded,
                title: 'Thanh toán thành công tiền điện & dịch vụ',
                subtitle: 'Trạng thái hoàn tất của hóa đơn tiền điện & dịch vụ',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        PaymentSuccessPage(invoice: _utilityInvoice),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _PreviewSectionTitle('Lịch sử thanh toán'),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.history_rounded,
                title: 'Lịch sử thanh toán nhiều kỳ',
                subtitle:
                    'Dữ liệu từ 01/2025 đến 07/2026 để thử bộ lọc tháng/năm',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaymentHistoryPage(
                      invoiceService: _invoiceService,
                      roomCode: 'P.203',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _PreviewSectionTitle('Mẫu QR tải xuống'),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.download_rounded,
                title: 'Mẫu QR tiền phòng',
                subtitle: 'Xem trước ảnh QR có thể tải về',
                onTap: () => _openReceiptPreview(context, _rentInvoice),
              ),
              const SizedBox(height: 8),
              _PreviewTile(
                icon: Icons.download_rounded,
                title: 'Mẫu QR tiền điện & dịch vụ',
                subtitle: 'Xem trước ảnh QR có thể tải về',
                onTap: () => _openReceiptPreview(context, _utilityInvoice),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQr(BuildContext context, TenantInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QrPaymentPage(
          invoice: invoice,
          pollInterval: const Duration(days: 1),
        ),
      ),
    );
  }

  void _openBillDetail(BuildContext context, TenantInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            BillDetailScreen(invoice: invoice, invoiceService: _invoiceService),
      ),
    );
  }

  void _openComplaint(BuildContext context, TenantInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UtilityComplaintScreen(
          invoice: invoice,
          invoiceService: _invoiceService,
        ),
      ),
    );
  }

  void _openReceiptPreview(BuildContext context, TenantInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QrReceiptPreviewPage(invoice: invoice),
      ),
    );
  }

  static TenantInvoice _invoice({
    required int id,
    required String invoiceCode,
    required String invoiceType,
    required int totalAmount,
    required String transferDescription,
    required List<TenantInvoiceLine> lines,
    String billingPeriod = '2026-06',
    String status = 'ISSUED',
    DateTime? issuedAt,
    DateTime? dueDate,
    DateTime? paidAt,
    int? paidAmount,
    int? remainingAmount,
  }) {
    return TenantInvoice(
      id: id,
      invoiceCode: invoiceCode,
      invoiceType: invoiceType,
      billingPeriod: billingPeriod,
      status: status,
      roomId: -1,
      roomCode: 'P.203',
      contractId: -1,
      contractCode: 'HD-DEMO-001',
      dueDate: dueDate ?? DateTime(2026, 6, 30),
      issuedAt: issuedAt ?? DateTime(2026, 6, 22),
      paidAt: paidAt,
      totalAmount: totalAmount,
      paidAmount: paidAmount ?? 0,
      remainingAmount: remainingAmount ?? totalAmount,
      paymentIntentId: null,
      checkoutUrl: '',
      qrCode: 'HDBHMS:$invoiceCode:$totalAmount:$transferDescription',
      providerOrderCode: '',
      paymentLinkId: '',
      bankBin: '970436',
      bankShortName: 'Vietcombank',
      accountNumber: '001234567890',
      accountName: 'CONG TY HDBHMS',
      transferDescription: transferDescription,
      lines: lines,
      priceDifferenceSettlementType: null,
    );
  }

  static TenantInvoice _paidHistoryInvoice({
    required int id,
    required String invoiceCode,
    required String invoiceType,
    required int amount,
    required DateTime month,
  }) {
    final period = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return _invoice(
      id: id,
      invoiceCode: invoiceCode,
      invoiceType: invoiceType,
      totalAmount: amount,
      transferDescription: 'THANHTOAN $invoiceCode',
      lines: const [],
      billingPeriod: period,
      status: 'PAID',
      issuedAt: DateTime(month.year, month.month, 1),
      dueDate: DateTime(month.year, month.month, 25),
      paidAt: month,
      paidAmount: amount,
      remainingAmount: 0,
    );
  }
}

class _PreviewTenantInvoiceService extends TenantInvoiceService {
  const _PreviewTenantInvoiceService();

  @override
  Future<List<TenantInvoice>> fetchMyInvoices({
    int? roomId,
    String? roomCode,
  }) async => PaymentPreviewPage._paidHistoryInvoices;

  @override
  Future<void> submitMeterReadingReview({
    required int invoiceId,
    required int lineId,
    required double reportedCurrentValue,
    required String description,
  }) async {}
}

class _PreviewSectionTitle extends StatelessWidget {
  const _PreviewSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.sectionTitle);
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.cardTitle),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.bodyText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
