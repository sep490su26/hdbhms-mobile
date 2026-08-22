import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/utils/room_code_formatter.dart';

import '../../models/payment/invoice_payment_presentation.dart';
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
    'SERVICE': Icons.home_work_outlined,
    'WATER': Icons.water_drop_outlined,
    'VIOLATION_FINE': Icons.gavel_rounded,
    'MAINTENANCE_COMPENSATION': Icons.build_rounded,
    'TRANSFER_DIFFERENCE': Icons.swap_horiz_rounded,
    'DEPOSIT_DEDUCTION': Icons.account_balance_wallet_outlined,
    'MANUAL_ADJUSTMENT': Icons.tune_rounded,
  };

  static const _lineColors = <String, Color>{
    'ELECTRICITY': AppColors.warning,
    'RENT': AppColors.primary,
    'SERVICE': AppColors.actionCyan,
    'WATER': AppColors.actionCyan,
    'VIOLATION_FINE': AppColors.danger,
    'MAINTENANCE_COMPENSATION': AppColors.actionOrange,
    'TRANSFER_DIFFERENCE': AppColors.actionCyan,
    'DEPOSIT_DEDUCTION': AppColors.warningText,
    'MANUAL_ADJUSTMENT': AppColors.bodyText,
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

  List<Widget> _serviceFactWidgets(TenantInvoiceLine serviceLine) {
    final formula = _serviceFormula;
    if (formula == null || formula.line != serviceLine) {
      return [
        if (serviceLine.unitPrice > 0)
          _CalculationRow(
            label: 'Đơn giá',
            value: '${_fmt(serviceLine.unitPrice)} / đơn vị',
          ),
        if (serviceLine.unitPrice > 0 && serviceLine.quantity > 0)
          const SizedBox(height: 8),
        if (serviceLine.quantity > 0)
          _CalculationRow(
            label: 'Số đơn vị',
            value: serviceLine.quantity.toString(),
          ),
      ];
    }
    return [
      _CalculationRow(
        label: 'Đơn giá',
        value: '${_fmt(formula.line.unitPrice)} / người / tháng',
      ),
      const SizedBox(height: 8),
      _CalculationRow(label: 'Chu kỳ', value: '${formula.cycle} tháng'),
      const SizedBox(height: 8),
      _CalculationRow(label: 'Số người', value: '${formula.people} người'),
    ];
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
    'WATER' => 'Tiền nước',
    'VIOLATION_FINE' => 'Phạt vi phạm',
    'MAINTENANCE_COMPENSATION' => 'Bồi thường bảo trì',
    'TRANSFER_DIFFERENCE' => 'Chênh lệch chuyển phòng',
    'DEPOSIT_DEDUCTION' => 'Khấu trừ tiền cọc',
    'MANUAL_ADJUSTMENT' => 'Điều chỉnh',
    _ => 'Khoản thanh toán',
  };

  static String _lineTitle(TenantInvoiceLine line) {
    final normalizedType = line.normalizedLineType;
    if (normalizedType == 'RENT' ||
        normalizedType == 'SERVICE' ||
        normalizedType == 'ELECTRICITY' ||
        normalizedType == 'WATER') {
      return _typeLabel(normalizedType);
    }
    final description = line.description.trim();
    return description.isEmpty ? _typeLabel(normalizedType) : description;
  }

  List<TenantInvoiceLine> get _electricityLines => invoice.lines
      .where((line) => line.normalizedLineType == 'ELECTRICITY')
      .toList(growable: false);
  List<TenantInvoiceLine> get _reviewLines => _electricityLines
      .where((line) {
        final status = line.reviewStatus.trim().toUpperCase();
        return status.isNotEmpty && status != 'NONE';
      })
      .toList(growable: false);
  bool get _hasComplainableLines =>
      _electricityLines.any((line) => line.canComplain && line.id != null);
  bool get _showsComplaintSection =>
      _reviewLines.isNotEmpty || _hasComplainableLines;
  bool get _canPay => invoice.canPay && !invoice.hasOpenMeterReadingReview;

  List<TenantInvoiceLine> _presentationLines() =>
      List.unmodifiable(invoice.lines);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: 'Chi tiết hóa đơn',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildSections(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final sections = <Widget>[_buildHeroCard()];

    void addSection(Widget section, {double gap = 16}) {
      sections.add(SizedBox(height: gap));
      sections.add(section);
    }

    if (invoice.isRentType || invoice.isOtherType) {
      addSection(_buildInvoiceContextCard());
    }
    if (_presentationLines().isNotEmpty) {
      addSection(_buildLineBreakdown());
    }
    if (invoice.discountAmount > 0) {
      addSection(_buildDiscountCard());
      addSection(_buildGrandTotalCard(), gap: 12);
    } else {
      addSection(_buildGrandTotalCard());
    }
    if (_showsComplaintSection) {
      addSection(_buildComplaintSection(context));
    }
    if (_canPay) {
      addSection(_buildActions(context));
    }

    return sections;
  }

  // ── Hero card ────────────────────────────────────────────────

  Widget _buildHeroCard() {
    final presentation = InvoicePaymentPresentation.fromInvoice(invoice);
    final heroIcon = presentation.icon;
    final heroAccent = presentation.accentColor;
    final metadata = _heroMetadata();
    return Container(
      key: const ValueKey('bill-detail-hero'),
      width: double.infinity,
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
                key: const ValueKey('bill-detail-hero-icon'),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(heroIcon, color: heroAccent, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presentation.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                        invoice.invoiceCode,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (metadata.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        metadata,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 16 / 12,
                        ),
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

  String _heroMetadata() {
    final parts = <String>[];
    final roomCode = invoice.roomCode.trim();
    if (roomCode.isNotEmpty) parts.add(formatRoomCode(roomCode));

    if (!invoice.isOtherType) {
      final period = _formatBillingPeriod(invoice.billingPeriod);
      if (period != 'Chưa cập nhật') parts.add(period);
    }
    return parts.join(' • ');
  }

  // ── Invoice line breakdown ────────────────────────────────────

  Widget _buildLineBreakdown() {
    final lines = _presentationLines();
    if (lines.isEmpty) return const SizedBox.shrink();

    return Container(
      key: const ValueKey('bill-detail-breakdown'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
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
                const Expanded(
                  child: Text(
                    'Chi tiết các khoản',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.inputText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
          const Divider(height: 1, color: AppColors.cardBorder),
          ...lines.asMap().entries.map((entry) {
            final idx = entry.key;
            final line = entry.value;
            final normalizedType = line.normalizedLineType;
            final color = _lineColors[normalizedType] ?? AppColors.bodyText;
            final icon =
                _lineIcons[normalizedType] ?? Icons.receipt_long_outlined;
            final isLast = idx == lines.length - 1;
            final facts = _factWidgetsForLine(line);
            final detailBlock = _detailBlockForLine(line, color, facts);

            return Column(
              children: [
                Padding(
                  key: ValueKey('bill-detail-line-$idx'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            child: Text(
                              _lineTitle(line),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.inputText,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                height: 18 / 14,
                              ),
                            ),
                          ),
                          Text(
                            _fmt(line.amount),
                            style: TextStyle(
                              color: AppColors.inputText,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      if (detailBlock != null) ...[
                        const SizedBox(height: 12),
                        KeyedSubtree(
                          key: ValueKey('bill-detail-line-details-$idx'),
                          child: detailBlock,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isLast)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, color: AppColors.cardBorder),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _factWidgetsForLine(TenantInvoiceLine line) {
    final type = line.normalizedLineType;
    if (type == 'RENT') {
      return [
        if (line.unitPrice > 0)
          _CalculationRow(
            label: 'Đơn giá',
            value: '${_fmt(line.unitPrice)} / tháng',
          ),
        if (line.unitPrice > 0 && line.quantity > 0) const SizedBox(height: 8),
        if (line.quantity > 0)
          _CalculationRow(label: 'Số tháng', value: '${line.quantity} tháng'),
      ];
    }
    if (type == 'SERVICE') return _serviceFactWidgets(line);
    if (type == 'ELECTRICITY' || type == 'WATER') return const [];

    return [
      if (line.unitPrice > 0)
        _CalculationRow(label: 'Đơn giá', value: _fmt(line.unitPrice)),
      if (line.unitPrice > 0 && line.quantity > 0) const SizedBox(height: 8),
      if (line.quantity > 0)
        _CalculationRow(label: 'Số lượng', value: line.quantity.toString()),
    ];
  }

  Widget? _detailBlockForLine(
    TenantInvoiceLine line,
    Color color,
    List<Widget> facts,
  ) {
    final meterBlock = _meterBlockForLine(line, color);
    if (meterBlock != null) return meterBlock;
    if (facts.isEmpty) return null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: facts,
      ),
    );
  }

  Widget? _meterBlockForLine(TenantInvoiceLine line, Color color) {
    final type = line.normalizedLineType;
    if ((type != 'ELECTRICITY' && type != 'WATER') ||
        (line.previousValue == null &&
            line.currentValue == null &&
            _usageForLine(line) == null)) {
      return null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type == 'ELECTRICITY' ? 'Chỉ số điện' : 'Chỉ số nước',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _CalculationRow(
            label: 'Kỳ trước',
            value: _fmtReadingWithUnit(line.previousValue, type),
          ),
          const SizedBox(height: 6),
          _CalculationRow(
            label: 'Kỳ này',
            value: _fmtReadingWithUnit(line.currentValue, type),
          ),
          const SizedBox(height: 10),
          _CalculationRow(
            label: 'Tiêu thụ',
            value: _fmtReadingWithUnit(_usageForLine(line), type),
          ),
          const SizedBox(height: 6),
          _CalculationRow(
            label: 'Đơn giá',
            value: '${_fmt(line.unitPrice)} / ${_unitForLine(type)}',
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
        .where(
          (l) =>
              l.normalizedLineType == 'ELECTRICITY' &&
              l.reviewStatus.trim().isNotEmpty &&
              l.reviewStatus.trim().toUpperCase() != 'NONE',
        )
        .toList();

    if (reviewLines.isNotEmpty) {
      // Show review status cards
      return KeyedSubtree(
        key: const ValueKey('bill-detail-complaint'),
        child: Column(
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
        ),
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

    return KeyedSubtree(
      key: const ValueKey('bill-detail-complaint'),
      child: Material(
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
                            'Chỉ số điện chưa chính xác?',
                            style: TextStyle(
                              color: AppColors.warningText,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 18 / 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Gửi yêu cầu để quản lý kiểm tra lại chỉ số điện trên hóa đơn.',
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
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.warningText,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Gửi khiếu nại số điện',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.warningText,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
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
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────

  Widget _buildDiscountCard() => Container(
    key: const ValueKey('bill-detail-discount'),
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
    key: const ValueKey('bill-detail-total'),
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
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

  Widget _buildInvoiceContextCard() {
    final isRent = invoice.isRentType;
    return Container(
      key: const ValueKey('bill-detail-context'),
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
                  color: isRent
                      ? AppColors.primaryLight
                      : AppColors.infoSurface,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Icon(
                  isRent ? Icons.key_outlined : Icons.receipt_long_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isRent ? 'Thông tin kỳ thuê' : 'Thông tin hóa đơn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inputText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RentContextRow(label: 'Phòng', value: invoice.roomCode),
          if (!invoice.isOtherType) const SizedBox(height: 10),
          if (!invoice.isOtherType)
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
    return Container(
      key: const ValueKey('bill-detail-actions'),
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
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        icon: const Icon(Icons.qr_code_rounded, size: 20),
        label: const Text('Thanh toán ngay'),
      ),
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value.isEmpty ? 'Chưa cập nhật' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
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
    final isElec = line.normalizedLineType == 'ELECTRICITY';

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
