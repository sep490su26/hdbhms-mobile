import 'package:flutter/material.dart';

import '../../models/payment/tenant_invoice_model.dart';
import '../../services/payment/tenant_invoice_service.dart';
import '../../theme/app_colors.dart';
import 'qr_payment_page.dart';
import 'utility_complaint_screen.dart';

/// Màn chi tiết hóa đơn: hiển thị breakdown từng dòng, trạng thái,
/// nút thanh toán và (nếu là UTILITY) nút khiếu nại điện nước.
class BillDetailScreen extends StatelessWidget {
  const BillDetailScreen({
    super.key,
    required this.invoice,
    required this.invoiceService,
  });

  final TenantInvoice invoice;
  final TenantInvoiceService invoiceService;

  // ── Helpers ──────────────────────────────────────────────────

  static const _lineIcons = <String, IconData>{
    'ELECTRICITY': Icons.bolt_rounded,
    'WATER': Icons.water_drop_rounded,
    'RENT': Icons.apartment_rounded,
    'SERVICE': Icons.miscellaneous_services_rounded,
    'VIOLATION_FINE': Icons.gavel_rounded,
    'MAINTENANCE_COMPENSATION': Icons.build_rounded,
  };

  static const _lineColors = <String, Color>{
    'ELECTRICITY': Color(0xFFF59E0B),
    'WATER': Color(0xFF0EA5E9),
    'RENT': Color(0xFF6366F1),
    'SERVICE': Color(0xFF10B981),
    'VIOLATION_FINE': Color(0xFFEF4444),
    'MAINTENANCE_COMPENSATION': Color(0xFFF97316),
  };

  static String _fmt(int amount) {
    final raw = amount.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buf.write('.');
      buf.write(raw[i]);
    }
    final sign = amount < 0 ? '-' : '';
    final s = buf.toString();
    return '$sign$sđ';
  }

  static String _fmtReading(double? v) {
    if (v == null) return '--';
    return v.truncateToDouble() == v
        ? v.toInt().toString()
        : v.toStringAsFixed(1);
  }

  static String _unitForLine(String lineType) {
    return lineType == 'ELECTRICITY' ? 'kWh' : 'm³';
  }

  static String _fmtReadingWithUnit(double? value, String lineType) {
    if (value == null) return '--';
    return '${_fmtReading(value)} ${_unitForLine(lineType)}';
  }

  static String _fmtQuantityWithUnit(TenantInvoiceLine line) {
    if (line.lineType == 'ELECTRICITY' || line.lineType == 'WATER') {
      return '${line.quantity} ${_unitForLine(line.lineType)}';
    }
    return line.quantity.toString();
  }

  static double? _usageForLine(TenantInvoiceLine line) {
    if (line.usageAmount != null) return line.usageAmount;
    final previous = line.previousValue;
    final current = line.currentValue;
    if (previous == null || current == null) return null;
    return current - previous;
  }

  static String _typeLabel(String type) => switch (type) {
    'ELECTRICITY' => 'Tiền điện',
    'WATER' => 'Tiền nước',
    'RENT' => 'Tiền phòng',
    'SERVICE' => 'Phí dịch vụ',
    'VIOLATION_FINE' => 'Phạt vi phạm',
    'MAINTENANCE_COMPENSATION' => 'Bồi thường bảo trì',
    _ => type,
  };

  bool get _isUtility => invoice.invoiceType == 'UTILITY';
  bool get _hasComplainableLines => invoice.reviewableUtilityLines.isNotEmpty;
  bool get _canPay => invoice.canPay && !invoice.hasOpenMeterReadingReview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A3A5C), Color(0xFF2563EB)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAppBar(context),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      32 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroCard(),
                        const SizedBox(height: 16),
                        _buildLineBreakdown(),
                        const SizedBox(height: 16),
                        if (_isUtility) _buildComplaintSection(context),
                        if (_isUtility) const SizedBox(height: 16),
                        _buildActions(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
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
                  'Chi tiết hóa đơn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Xem chi tiết và thanh toán',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero card ────────────────────────────────────────────────

  Widget _buildHeroCard() {
    final isPending = invoice.status == 'PENDING' || invoice.status == 'UNPAID';
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1F3A), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF451A03),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  invoice.invoiceCode.isEmpty
                      ? 'Phòng ${invoice.roomCode}'
                      : '${invoice.invoiceCode} · Phòng ${invoice.roomCode}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(invoice.totalAmount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFF6B6B).withValues(alpha: 0.25)
                      : const Color(0xFF10B981).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isPending ? 'Chờ thanh toán' : 'Đã thanh toán',
                  style: TextStyle(
                    color: isPending
                        ? const Color(0xFFFF8787)
                        : const Color(0xFF6EE7B7),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Invoice line breakdown ────────────────────────────────────

  Widget _buildLineBreakdown() {
    final lines = invoice.lines;
    if (lines.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.list_alt_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Chi tiết các khoản',
                  style: TextStyle(
                    color: AppColors.inputText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${lines.length} khoản',
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F4F8)),

          // Lines
          ...lines.asMap().entries.map((entry) {
            final idx = entry.key;
            final line = entry.value;
            final color = _lineColors[line.lineType] ?? AppColors.bodyText;
            final icon = _lineIcons[line.lineType] ?? Icons.circle_outlined;
            final isLast = idx == lines.length - 1;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(icon, color: color, size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.description.isEmpty
                                      ? _typeLabel(line.lineType)
                                      : line.description,
                                  style: const TextStyle(
                                    color: AppColors.inputText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (line.quantity > 0 &&
                                    line.unitPrice > 0) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    '${_fmtQuantityWithUnit(line)} × ${_fmt(line.unitPrice)}',
                                    style: const TextStyle(
                                      color: AppColors.bodyText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            _fmt(line.amount),
                            style: TextStyle(
                              color: color,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      // Meter reading row (điện/nước)
                      if (line.previousValue != null &&
                          line.currentValue != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: color.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    line.lineType == 'ELECTRICITY'
                                        ? Icons.electric_meter_outlined
                                        : Icons.water_outlined,
                                    color: color,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Chỉ số: ',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  _MeterValueChip(
                                    label: 'Cũ',
                                    value: _fmtReadingWithUnit(
                                      line.previousValue,
                                      line.lineType,
                                    ),
                                    color: AppColors.bodyText,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 11,
                                      color: AppColors.bodyText.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  _MeterValueChip(
                                    label: 'Mới',
                                    value: _fmtReadingWithUnit(
                                      line.currentValue,
                                      line.lineType,
                                    ),
                                    color: color,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Số lượng: ${_fmtReadingWithUnit(_usageForLine(line), line.lineType)}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isLast)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, color: Color(0xFFF0F4F8)),
                  ),
              ],
            );
          }),

          // Total
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFF0FDF4)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.summarize_outlined,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tổng cộng',
                  style: TextStyle(
                    color: AppColors.inputText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  _fmt(invoice.totalAmount),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Complaint section ─────────────────────────────────────────

  Widget _buildComplaintSection(BuildContext context) {
    // Review statuses for existing lines
    final lines = invoice.lines;
    final reviewLines = lines
        .where((l) => l.reviewStatus.isNotEmpty && l.reviewStatus != 'NONE')
        .toList();

    if (reviewLines.isNotEmpty) {
      // Show review status cards
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Trạng thái khiếu nại',
              style: TextStyle(
                color: AppColors.inputText,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ...reviewLines.map((line) => _ReviewStatusCard(line: line)),
        ],
      );
    }

    if (!_hasComplainableLines) return const SizedBox.shrink();

    void openComplaint() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => UtilityComplaintScreen(
            invoice: invoice,
            invoiceService: invoiceService,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: openComplaint,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.report_problem_outlined,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chỉ số không chính xác?',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 18 / 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Gửi khiếu nại để quản lý xem xét lại. Kết quả xử lý sẽ được gửi qua thông báo.',
                          style: TextStyle(
                            color: Color(0xFFA16207),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 17 / 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Gửi khiếu nại điện nước',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        if (_canPay)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => QrPaymentPage(
                    invoice: invoice,
                    invoiceService: invoiceService,
                  ),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              icon: const Icon(Icons.qr_code_rounded, size: 20),
              label: const Text('Thanh toán ngay'),
            ),
          ),
      ],
    );
  }
}

// ── Review status card ────────────────────────────────────────────────────────

class _ReviewStatusCard extends StatelessWidget {
  const _ReviewStatusCard({required this.line});
  final TenantInvoiceLine line;

  static (Color, Color, String, IconData) _statusInfo(String status) =>
      switch (status.toUpperCase()) {
        'PENDING' => (
          const Color(0xFFFFFBEB),
          const Color(0xFFF59E0B),
          'Đang xem xét',
          Icons.hourglass_top_rounded,
        ),
        'APPROVED' => (
          const Color(0xFFF0FDF4),
          const Color(0xFF10B981),
          'Được chấp thuận',
          Icons.check_circle_outline_rounded,
        ),
        'REJECTED' => (
          const Color(0xFFFFF1F2),
          const Color(0xFFEF4444),
          'Bị từ chối',
          Icons.cancel_outlined,
        ),
        _ => (
          const Color(0xFFF8FAFB),
          AppColors.bodyText,
          status,
          Icons.info_outline_rounded,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final status = line.reviewStatus;
    final (bg, color, label, icon) = _statusInfo(status);
    final isElec = line.lineType == 'ELECTRICITY';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isElec ? Icons.bolt_rounded : Icons.water_drop_rounded,
            color: isElec ? const Color(0xFFF59E0B) : const Color(0xFF0EA5E9),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isElec ? 'Khiếu nại điện' : 'Khiếu nại nước',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meter value chip ──────────────────────────────────────────────────────────

class _MeterValueChip extends StatelessWidget {
  const _MeterValueChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
