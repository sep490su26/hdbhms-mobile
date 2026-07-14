import 'package:flutter/material.dart';

import '../../models/payment/tenant_invoice_model.dart';
import '../../services/payment/tenant_invoice_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_action_tile.dart';
import 'bill_detail_screen.dart';
import 'payment_success_page.dart';
import 'qr_payment_page.dart';
import 'utility_complaint_screen.dart';

/// TEMPORARY: Màn hình chỉ dùng để xem trước UI thanh toán & khiếu nại.
/// Xóa file này và nút gọi từ HomeScreen khi không còn cần preview.
class PaymentPreviewPage extends StatelessWidget {
  const PaymentPreviewPage({super.key});

  static const TenantInvoiceService _previewInvoiceService =
      _PreviewTenantInvoiceService();

  // ── Mock: hóa đơn tiền phòng ──────────────────────────────
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

  // ── Mock: hóa đơn điện nước (KHÔNG có khiếu nại) ─────────
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
        previousValue: 1010.0,
        currentValue: 1190.0,
        usageAmount: 180.0,
      ),
      TenantInvoiceLine(
        id: -103,
        lineType: 'WATER',
        description: 'Tiền nước',
        quantity: 12,
        unitPrice: 13000,
        amount: 156000,
        previousValue: 44.0,
        currentValue: 56.0,
        usageAmount: 12.0,
      ),
    ],
  );

  // ── Mock: hóa đơn điện nước CÓ thể khiếu nại ────────────
  static final TenantInvoice _complainableInvoice = _mockInvoice(
    id: -104,
    invoiceCode: 'UTILITY-DEMO-002',
    invoiceType: 'UTILITY',
    totalAmount: 920000,
    transferDescription: 'THANHTOAN UTILITY DEMO 002',
    lines: const [
      TenantInvoiceLine(
        id: -104,
        lineType: 'ELECTRICITY',
        description: 'Tiền điện',
        quantity: 210,
        unitPrice: 3500,
        amount: 735000,
        previousValue: 1240.0,
        currentValue: 1450.0,
        usageAmount: 210.0,
        canComplain: true,
        reviewStatus: 'NONE',
      ),
      TenantInvoiceLine(
        id: -105,
        lineType: 'WATER',
        description: 'Tiền nước',
        quantity: 14,
        unitPrice: 13000,
        amount: 182000,
        previousValue: 56.0,
        currentValue: 70.0,
        usageAmount: 14.0,
        canComplain: true,
        reviewStatus: 'NONE',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF061827), Color(0xFF0D2137)],
                  stops: [0, 0.32],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -70,
                    right: -50,
                    child: _PreviewGlowOrb(color: AppColors.primary, size: 180),
                  ),
                  Positioned.fill(
                    top: MediaQuery.sizeOf(context).height * 0.26,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF6FAF9),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Quay lại',
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UI Preview',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Dữ liệu demo – không tạo giao dịch thật',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.preview_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Preview',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      // ── Section: Màn đã cập nhật ─────────────
                      const _SectionHeader(
                        icon: Icons.dashboard_customize_rounded,
                        label: 'Màn đã cập nhật',
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 10),
                      _PreviewButton(
                        icon: Icons.receipt_long_rounded,
                        title: 'Bill detail điện nước',
                        subtitle:
                            'Mở đúng màn chi tiết bill hiện tại, có CTA khiếu nại và đơn vị kWh/m³',
                        accentColor: AppColors.actionBlue,
                        onTap: () =>
                            _openBillDetail(context, _complainableInvoice),
                      ),
                      const SizedBox(height: 10),
                      _PreviewButton(
                        icon: Icons.report_problem_rounded,
                        title: 'Khiếu nại điện nước',
                        subtitle:
                            'Mở form khiếu nại với topbar và panel đã đồng bộ',
                        accentColor: const Color(0xFFD97706),
                        onTap: () =>
                            _openComplaint(context, _complainableInvoice),
                      ),

                      const SizedBox(height: 24),

                      // ── Section: Thanh toán ──────────────────
                      const _SectionHeader(
                        icon: Icons.payment_rounded,
                        label: 'Thanh toán',
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 10),
                      _PreviewButton(
                        icon: Icons.apartment_rounded,
                        title: 'QR thanh toán tiền phòng',
                        subtitle: 'Preview QR cho hóa đơn RENT',
                        accentColor: AppColors.actionBlue,
                        onTap: () => _openQr(context, _rentInvoice),
                      ),
                      const SizedBox(height: 10),
                      _PreviewButton(
                        icon: Icons.bolt_rounded,
                        title: 'QR điện nước & dịch vụ',
                        subtitle: 'Preview QR cho hóa đơn UTILITY',
                        accentColor: AppColors.actionOrange,
                        onTap: () => _openQr(context, _utilityInvoice),
                      ),
                      const SizedBox(height: 10),
                      _PreviewButton(
                        icon: Icons.receipt_long_rounded,
                        title: 'Bill detail không khiếu nại',
                        subtitle:
                            'Xem hóa đơn điện nước chỉ có chỉ số và đơn vị đo',
                        accentColor: AppColors.actionBlue,
                        onTap: () => _openBillDetail(context, _utilityInvoice),
                      ),
                      const SizedBox(height: 10),
                      _PreviewButton(
                        icon: Icons.check_circle_rounded,
                        title: 'Thành công – tiền phòng',
                        subtitle: 'Màn xác nhận với khoản tiền phòng',
                        accentColor: AppColors.actionEmerald,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  PaymentSuccessPage(invoice: _rentInvoice),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _PreviewButton(
                        icon: Icons.verified_rounded,
                        title: 'Thành công – điện nước',
                        subtitle: 'Màn xác nhận có breakdown điện và nước',
                        accentColor: AppColors.actionViolet,
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
                ),
              ],
            ),
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

  void _openBillDetail(BuildContext context, TenantInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BillDetailScreen(
          invoice: invoice,
          invoiceService: _previewInvoiceService,
        ),
      ),
    );
  }

  void _openComplaint(BuildContext context, TenantInvoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UtilityComplaintScreen(
          invoice: invoice,
          invoiceService: _previewInvoiceService,
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
      priceDifferenceSettlementType: null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

class _PreviewTenantInvoiceService extends TenantInvoiceService {
  const _PreviewTenantInvoiceService();

  @override
  Future<void> submitMeterReadingReview({
    required int invoiceId,
    required int lineId,
    required double reportedCurrentValue,
    required String description,
  }) async {}
}

class _PreviewGlowOrb extends StatelessWidget {
  const _PreviewGlowOrb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(color: color.withValues(alpha: 0.2), height: 1),
        ),
      ],
    );
  }
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppActionRowButton(
      icon: icon,
      title: title,
      subtitle: subtitle,
      accentColor: accentColor,
      onTap: onTap,
    );
  }
}
