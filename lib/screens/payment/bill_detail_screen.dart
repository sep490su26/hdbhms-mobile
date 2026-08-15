import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

import '../../models/payment/tenant_invoice_model.dart';
import '../../services/contract/lease_contract_service.dart';
import '../../services/payment/tenant_invoice_service.dart';
import '../../services/notification/notification_service.dart';
import '../../widgets/app_top_bar.dart';
import 'qr_payment_page.dart';
import 'utility_complaint_screen.dart';

/// Màn chi tiết hóa đơn: hiển thị breakdown từng dòng, trạng thái,
/// nút thanh toán và (nếu là UTILITY) nút khiếu nại số điện.
class BillDetailScreen extends StatefulWidget {
  const BillDetailScreen({
    super.key,
    required this.invoice,
    required this.invoiceService,
    this.notificationService = const NotificationService(),
    this.leaseContractService = const LeaseContractService(),
    this.servicePaymentCycleMonths,
  });

  final TenantInvoice invoice;
  final TenantInvoiceService invoiceService;
  final NotificationService notificationService;
  final LeaseContractService leaseContractService;
  final int? servicePaymentCycleMonths;

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  TenantInvoice get invoice => widget.invoice;
  TenantInvoiceService get invoiceService => widget.invoiceService;
  NotificationService get notificationService => widget.notificationService;

  int? _serviceCycleMonths;

  @override
  void initState() {
    super.initState();
    _serviceCycleMonths = widget.servicePaymentCycleMonths;
    _loadServiceCycle();
  }

  Future<void> _loadServiceCycle() async {
    if (_serviceCycleMonths != null) return;
    final contractId = invoice.contractId;
    if (contractId == null ||
        contractId <= 0 ||
        !invoice.lines.any((line) => line.normalizedLineType == 'SERVICE')) {
      return;
    }
    try {
      final contract = await widget.leaseContractService.getContractById(
        contractId,
      );
      if (mounted) {
        setState(() => _serviceCycleMonths = contract.paymentCycleMonths);
      }
    } catch (_) {
      // Historical invoices must remain readable when contract context is gone.
    }
  }

  // ── Helpers ──────────────────────────────────────────────────

  static const _lineIcons = <String, IconData>{
    'ELECTRICITY': Icons.bolt_rounded,
    'RENT': Icons.door_front_door_outlined,
    'SERVICE': Icons.room_service_outlined,
    'VIOLATION_FINE': Icons.gavel_rounded,
    'MAINTENANCE_COMPENSATION': Icons.build_rounded,
  };

  static const _lineColors = <String, Color>{
    'ELECTRICITY': AppColors.warning,
    'RENT': AppColors.primary,
    'SERVICE': AppColors.actionCyan,
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
    if (line.normalizedLineType == 'ELECTRICITY' ||
        line.normalizedLineType == 'WATER') {
      return '${line.quantity} ${_unitForLine(line.lineType)}';
    }
    return line.quantity.toString();
  }

  static String _rentQuantityLabel(TenantInvoiceLine line) {
    if (line.normalizedLineType == 'RENT') {
      return '${line.quantity} tháng';
    }
    return _fmtQuantityWithUnit(line);
  }

  static String _formatBillingPeriod(String value) {
    final normalized = value.trim();
    final match = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(normalized);
    if (match == null) return normalized.isEmpty ? 'Chưa cập nhật' : normalized;
    final month = int.tryParse(match.group(2)!);
    if (month == null || month < 1 || month > 12) return normalized;
    return 'Tháng ${month.toString().padLeft(2, '0')}/${match.group(1)}';
  }

  ({TenantInvoiceLine line, int cycle, int people})? get _serviceFormula {
    final serviceLines = invoice.lines
        .where((line) => line.normalizedLineType == 'SERVICE')
        .toList(growable: false);
    final hasLegacyWater = invoice.lines.any(
      (line) => line.normalizedLineType == 'WATER',
    );
    final cycle = _serviceCycleMonths;
    if (hasLegacyWater ||
        serviceLines.length != 1 ||
        cycle == null ||
        cycle <= 0) {
      return null;
    }
    final line = serviceLines.single;
    if (line.quantity <= 0 ||
        line.quantity % cycle != 0 ||
        line.unitPrice <= 0 ||
        line.unitPrice * line.quantity != line.amount) {
      return null;
    }
    return (line: line, cycle: cycle, people: line.quantity ~/ cycle);
  }

  Widget _buildServiceFormula() {
    final formula = _serviceFormula;
    if (formula == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text(
          'Khoản dịch vụ theo hóa đơn',
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          _CalculationRow(
            label: 'Đơn giá',
            value: '${_fmt(formula.line.unitPrice)} / người / tháng',
          ),
          const SizedBox(height: 8),
          _CalculationRow(label: 'Chu kỳ', value: '${formula.cycle} tháng'),
          const SizedBox(height: 8),
          _CalculationRow(label: 'Số người', value: '${formula.people} người'),
        ],
      ),
    );
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
    'RENT' => 'Tiền phòng',
    'SERVICE' => 'Phí dịch vụ',
    'VIOLATION_FINE' => 'Phạt vi phạm',
    'MAINTENANCE_COMPENSATION' => 'Bồi thường bảo trì',
    _ => 'Khoản thanh toán',
  };

  bool get _isUtility => invoice.isUtilityType;
  bool get _hasComplainableLines => invoice.reviewableUtilityLines.any(
    (line) => line.normalizedLineType == 'ELECTRICITY',
  );
  bool get _canPay => invoice.canPay && !invoice.hasOpenMeterReadingReview;

  List<({TenantInvoiceLine? line, int amount, bool serviceGroup})>
  _presentationLines() {
    final waterAndService = invoice.lines
        .where(
          (line) =>
              line.normalizedLineType == 'WATER' ||
              line.normalizedLineType == 'SERVICE',
        )
        .toList(growable: false);
    final groupedAmount = waterAndService.fold<int>(
      0,
      (sum, line) => sum + line.amount,
    );
    final visible =
        <({TenantInvoiceLine? line, int amount, bool serviceGroup})>[
          ...invoice.lines
              .where(
                (line) =>
                    line.normalizedLineType != 'WATER' &&
                    line.normalizedLineType != 'SERVICE',
              )
              .map(
                (line) =>
                    (line: line, amount: line.amount, serviceGroup: false),
              ),
        ];
    if (waterAndService.isNotEmpty) {
      visible.add((line: null, amount: groupedAmount, serviceGroup: true));
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppTopBar(
                title: 'Chi tiết hóa đơn',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(color: Colors.transparent),
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
                        if (invoice.discountAmount > 0) _buildDiscountCard(),
                        if (invoice.discountAmount > 0)
                          const SizedBox(height: 12),
                        _buildGrandTotalCard(),
                        const SizedBox(height: 16),
                        if (invoice.isRentType) _buildRentContextCard(),
                        if (invoice.isRentType) const SizedBox(height: 16),
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

  // Retained temporarily for source compatibility with legacy previews. The
  // production screen now uses [AppTopBar] directly above.
  // ignore: unused_element
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceMuted,
              foregroundColor: AppColors.topBarIconColor,
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
                    color: AppColors.darkBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Xem chi tiết và thanh toán',
                  style: TextStyle(
                    color: AppColors.bodyText,
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
    final heroIcon = _isUtility
        ? Icons.bolt_rounded
        : invoice.isRentType
        ? Icons.door_front_door_outlined
        : Icons.build_outlined;
    final heroAccent = _isUtility
        ? AppColors.warning
        : invoice.isRentType
        ? AppColors.primaryLight
        : AppColors.accent;
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(heroIcon, color: heroAccent, size: 36),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    if (invoice.invoiceCode.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Mã hóa đơn: ${invoice.invoiceCode}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (invoice.roomCode.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            color: heroAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              invoice.roomCode.trim(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
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
    final lines = _presentationLines();
    if (lines.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
                    color: AppColors.infoSurface,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${lines.length} khoản',
                    style: const TextStyle(
                      color: AppColors.bodyText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F4F8)),

          // Lines
          ...lines.asMap().entries.map((entry) {
            final idx = entry.key;
            final displayLine = entry.value;
            final line = displayLine.line;
            final color = displayLine.serviceGroup
                ? AppColors.actionCyan
                : _lineColors[line!.normalizedLineType] ?? AppColors.bodyText;
            final icon = displayLine.serviceGroup
                ? Icons.home_work_outlined
                : _lineIcons[line!.normalizedLineType] ??
                      Icons.receipt_long_outlined;
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
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusMd,
                              ),
                            ),
                            child: Icon(icon, color: color, size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayLine.serviceGroup
                                      ? 'Phí dịch vụ'
                                      : line!.description.isEmpty
                                      ? _typeLabel(line.normalizedLineType)
                                      : line.description,
                                  style: const TextStyle(
                                    color: AppColors.inputText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (!displayLine.serviceGroup &&
                                    line!.quantity > 0 &&
                                    line.unitPrice > 0) ...[
                                  const SizedBox(height: 8),
                                  if (line.normalizedLineType == 'RENT') ...[
                                    _CalculationRow(
                                      label: 'Đơn giá',
                                      value: '${_fmt(line.unitPrice)} / tháng',
                                    ),
                                    const SizedBox(height: 6),
                                    _CalculationRow(
                                      label: 'Số tháng',
                                      value: '${line.quantity} tháng',
                                    ),
                                  ] else
                                    Text(
                                      '${_fmt(line.unitPrice)} × ${_rentQuantityLabel(line)}',
                                      style: const TextStyle(
                                        color: AppColors.bodyText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            _fmt(displayLine.amount),
                            style: TextStyle(
                              color: AppColors.inputText,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      if (displayLine.serviceGroup) _buildServiceFormula(),
                      // Meter reading row (điện/nước)
                      if (!displayLine.serviceGroup &&
                          line!.previousValue != null &&
                          line.currentValue != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusSm,
                            ),
                            border: Border.all(
                              color: color.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.normalizedLineType == 'ELECTRICITY'
                                    ? 'Chỉ số điện'
                                    : 'Chỉ số nước',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _CalculationRow(
                                label: 'Kỳ trước',
                                value: _fmtReadingWithUnit(
                                  line.previousValue,
                                  line.normalizedLineType,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _CalculationRow(
                                label: 'Kỳ này',
                                value: _fmtReadingWithUnit(
                                  line.currentValue,
                                  line.normalizedLineType,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _CalculationRow(
                                label: 'Tiêu thụ',
                                value: _fmtReadingWithUnit(
                                  _usageForLine(line),
                                  line.normalizedLineType,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _CalculationRow(
                                label: 'Đơn giá',
                                value:
                                    '${_fmt(line.unitPrice)} / ${_unitForLine(line.normalizedLineType)}',
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
        ],
      ),
    );
  }

  // ── Complaint section ─────────────────────────────────────────

  Widget _buildComplaintSection(BuildContext context) {
    // Review statuses for existing lines
    final lines = invoice.lines;
    final reviewLines = lines
        .where(
          (l) =>
              l.lineType == 'ELECTRICITY' &&
              l.reviewStatus.isNotEmpty &&
              l.reviewStatus != 'NONE',
        )
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
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warningSurface,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: const Icon(
                      Icons.report_problem_outlined,
                      color: AppColors.warning,
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
                            color: AppColors.warningText,
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: .72),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.warningText,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Gửi khiếu nại số điện',
                      style: TextStyle(
                        color: AppColors.warningText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.warningText,
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

  Widget _buildDiscountCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.successSurface,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.percent_rounded,
          color: AppColors.successText,
          size: 20,
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Giảm giá đã áp dụng',
            style: TextStyle(
              color: AppColors.successText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '-${_fmt(invoice.discountAmount)}',
          style: const TextStyle(
            color: AppColors.successText,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _buildGrandTotalCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Tổng cộng',
            style: TextStyle(
              color: AppColors.inputText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          _fmt(invoice.totalAmount),
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _buildRentContextCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: const Icon(
                  Icons.key_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Thông tin kỳ thuê',
                style: TextStyle(
                  color: AppColors.inputText,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RentContextRow(label: 'Phòng', value: invoice.roomCode),
          const SizedBox(height: 10),
          _RentContextRow(
            label: 'Kỳ hóa đơn',
            value: _formatBillingPeriod(invoice.billingPeriod),
          ),
          const SizedBox(height: 10),
          _RentContextRow(
            label: 'Hạn thanh toán',
            value: _formatDate(invoice.dueDate),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return 'Chưa cập nhật';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        if (_canPay)
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [AppColors.deepBlue, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => QrPaymentPage(
                    invoice: invoice,
                    invoiceService: invoiceService,
                    notificationService: notificationService,
                  ),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
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

class _RentContextRow extends StatelessWidget {
  const _RentContextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value.isEmpty ? 'Chưa cập nhật' : value,
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CalculationRow extends StatelessWidget {
  const _CalculationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

IconData _invoiceTypeIcon(TenantInvoice invoice) {
  if (invoice.isRentType) return Icons.apartment_rounded;
  if (invoice.isUtilityType) return Icons.bolt_rounded;
  return Icons.more_horiz_rounded;
}

// ignore: unused_element
class _InvoiceTypeBadge extends StatelessWidget {
  const _InvoiceTypeBadge({required this.invoice});

  final TenantInvoice invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_invoiceTypeIcon(invoice), color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            invoice.invoiceTypeLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 14 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewStatusCard extends StatelessWidget {
  const _ReviewStatusCard({required this.line});
  final TenantInvoiceLine line;

  static (Color, Color, String, IconData) _statusInfo(String status) =>
      switch (status.toUpperCase()) {
        'PENDING' => (
          AppColors.warningSurface,
          AppColors.warning,
          'Đang xem xét',
          Icons.hourglass_top_rounded,
        ),
        'APPROVED' => (
          const Color(0xFFF0FDF4),
          AppColors.success,
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
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isElec ? Icons.bolt_rounded : Icons.water_drop_rounded,
            color: isElec ? AppColors.warning : const Color(0xFF0EA5E9),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isElec ? 'Khiếu nại số điện' : 'Khiếu nại chỉ số',
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
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
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

// ignore: unused_element
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
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
