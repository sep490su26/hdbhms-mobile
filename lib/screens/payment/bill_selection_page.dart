import 'package:flutter/material.dart';
import '../../models/payment/tenant_invoice_model.dart';
import '../../services/payment/tenant_invoice_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_action_tile.dart';
import '../../widgets/tenant_bottom_navigation.dart';
import '../../widgets/app_screen_shell.dart';
import '../maintenance/maintenance_ticket_list_screen.dart';
import '../notification/notification_list_screen.dart';
import '../profileRequest/tenant_profile_screen.dart';
import '../profileRequest/tenant_request_screen.dart';
import 'payment_history_page.dart';
import 'qr_payment_page.dart';

class BillSelectionPage extends StatefulWidget {
  const BillSelectionPage({
    super.key,
    this.invoiceService = const TenantInvoiceService(),
  });

  final TenantInvoiceService invoiceService;

  @override
  State<BillSelectionPage> createState() => _BillSelectionPageState();
}

class _BillSelectionPageState extends State<BillSelectionPage> {
  _BillFilter _activeFilter = _BillFilter.all;
  late Future<List<TenantInvoice>> _invoicesFuture;

  @override
  void initState() {
    super.initState();
    _invoicesFuture = widget.invoiceService.fetchMyInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: const _BillHeader(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
            children: [
              const Text('Tất cả hoá đơn', style: AppTypography.pageTitle),
              const SizedBox(height: 14),
              _BillFilterBar(
                active: _activeFilter,
                onChanged: (filter) {
                  setState(() => _activeFilter = filter);
                },
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<TenantInvoice>>(
                future: _invoicesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _BillLoadingState();
                  }
                  if (snapshot.hasError) {
                    return _BillErrorState(
                      message: snapshot.error is TenantInvoiceException
                          ? (snapshot.error as TenantInvoiceException).message
                          : 'Không tải được hóa đơn. Vui lòng thử lại.',
                      onRetry: _reloadInvoices,
                    );
                  }
                  final visibleInvoices = (snapshot.data ?? const [])
                      .where((invoice) => invoice.isTenantVisible)
                      .toList();
                  return Column(
                    children: _buildFilteredBills(context, visibleInvoices),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.bills,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onBillsTap: () {},
        onSupportTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const MaintenanceTicketListScreen(),
            ),
          );
        },
        onProfileTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const TenantProfileScreen(),
            ),
          );
        },
        onRequestsTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const TenantRequestScreen()),
        ),
      ),
    );
  }

  void _reloadInvoices() {
    setState(() {
      _invoicesFuture = widget.invoiceService.fetchMyInvoices();
    });
  }

  void _openPayment(BuildContext context, TenantInvoice invoice) {
    if (invoice.hasOpenMeterReadingReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hóa đơn đang có khiếu nại chỉ số chờ xử lý.'),
        ),
      );
      return;
    }
    if (invoice.canPay &&
        (invoice.qrCode.isNotEmpty || invoice.transferDescription.isNotEmpty)) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => QrPaymentPage(
                invoice: invoice,
                invoiceService: widget.invoiceService,
              ),
            ),
          )
          .then((_) => _reloadInvoices());
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hóa đơn chưa thể thanh toán. Vui lòng liên hệ quản lý.'),
      ),
    );
  }

  Future<void> _openMeterReadingReview(
    BuildContext context,
    TenantInvoice invoice,
  ) async {
    final lines = invoice.reviewableUtilityLines;
    if (invoice.hasOpenMeterReadingReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hóa đơn này đã có khiếu nại đang chờ xử lý.')),
      );
      return;
    }
    if (lines.isEmpty || invoice.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hóa đơn này chưa thể gửi khiếu nại chỉ số.')),
      );
      return;
    }
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MeterReadingReviewSheet(
        invoice: invoice,
        lines: lines,
        invoiceService: widget.invoiceService,
      ),
    );
    if (submitted == true) {
      _reloadInvoices();
    }
  }

  List<Widget> _buildFilteredBills(
    BuildContext context,
    List<TenantInvoice> invoices,
  ) {
    final pendingBills = _withSpacing(
      invoices
          .where((invoice) => !invoice.isPaid)
          .map(
            (invoice) => _PendingBillCard(
              invoice: invoice,
              onTap: () => _openPayment(context, invoice),
              onComplain: () => _openMeterReadingReview(context, invoice),
            ),
          )
          .toList(),
      16,
    );

    final paidBills = _withSpacing(
      invoices
          .where((invoice) => invoice.isPaid)
          .map((invoice) => _PaidBillCard(invoice: invoice))
          .toList(),
      12,
    );

    final historyButton = _ViewHistoryButton(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                PaymentHistoryPage(invoiceService: widget.invoiceService),
          ),
        );
      },
    );

    if (invoices.isEmpty) {
      return const [
        _BillEmptyState(
          title: 'Chưa có hóa đơn',
          message: 'Khi chủ trọ phát hành hóa đơn, bạn sẽ thấy tại đây.',
        ),
      ];
    }

    return switch (_activeFilter) {
      _BillFilter.all => [
        if (pendingBills.isNotEmpty) ...pendingBills,
        if (paidBills.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _PaidDivider(),
          const SizedBox(height: 22),
          ...paidBills,
        ],
        const SizedBox(height: 18),
        historyButton,
      ],
      _BillFilter.unpaid =>
        pendingBills.isEmpty
            ? const [
                _BillEmptyState(
                  title: 'Không có khoản cần trả',
                  message: 'Phòng hiện tại chưa có hóa đơn chờ thanh toán.',
                ),
              ]
            : pendingBills,
      _BillFilter.paid =>
        paidBills.isEmpty
            ? const [
                _BillEmptyState(
                  title: 'Chưa có lịch sử thanh toán',
                  message: 'Các hóa đơn đã thanh toán sẽ được lưu ở đây.',
                ),
              ]
            : [...paidBills, const SizedBox(height: 18), historyButton],
    };
  }
}

enum _BillFilter { all, unpaid, paid }

List<Widget> _withSpacing(List<Widget> widgets, double spacing) {
  if (widgets.isEmpty) return const [];
  return [
    for (var index = 0; index < widgets.length; index++) ...[
      if (index > 0) SizedBox(height: spacing),
      widgets[index],
    ],
  ];
}

String _formatAmount(int amount) {
  final raw = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index += 1) {
    if (index > 0 && (raw.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(raw[index]);
  }
  return '${amount < 0 ? '-' : ''}${buffer.toString()}đ';
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Chưa có hạn';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _lineLabel(TenantInvoiceLine line) {
  if (line.lineType == 'VIOLATION_FINE') {
    return 'Phạt vi phạm nội quy: ${_formatAmount(line.amount)}';
  }
  if (line.lineType == 'MAINTENANCE_COMPENSATION') {
    return 'Bồi thường bảo trì: ${_formatAmount(line.amount)}';
  }
  return '${line.description}: ${_formatAmount(line.amount)}';
}

class _BillLoadingState extends StatelessWidget {
  const _BillLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _BillErrorState extends StatelessWidget {
  const _BillErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB5AE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFFB42318),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _BillEmptyState extends StatelessWidget {
  const _BillEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.deepBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 18 / 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 18 / 13,
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

class _BillFilterBar extends StatelessWidget {
  const _BillFilterBar({required this.active, required this.onChanged});

  final _BillFilter active;
  final ValueChanged<_BillFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _BillFilterChip(
            label: 'Tất cả',
            icon: Icons.list_rounded,
            isActive: active == _BillFilter.all,
            onTap: () => onChanged(_BillFilter.all),
          ),
          const SizedBox(width: 8),
          _BillFilterChip(
            label: 'Chưa thanh toán',
            icon: Icons.pending_actions_rounded,
            isActive: active == _BillFilter.unpaid,
            onTap: () => onChanged(_BillFilter.unpaid),
          ),
          const SizedBox(width: 8),
          _BillFilterChip(
            label: 'Đã thanh toán',
            icon: Icons.task_alt_rounded,
            isActive: active == _BillFilter.paid,
            onTap: () => onChanged(_BillFilter.paid),
          ),
        ],
      ),
    );
  }
}

class _BillFilterChip extends StatelessWidget {
  const _BillFilterChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [AppColors.deepBlue, AppColors.primary],
                )
              : null,
          color: isActive ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.2)
                : AppColors.cardBorder.withValues(alpha: 0.8),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : AppColors.bodyText,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.bodyText,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillHeader extends StatelessWidget {
  const _BillHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.fromLTRB(4, 0, 15, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder.withValues(alpha: 0.65),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text(
              'Hóa đơn',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 20 / 16,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.inputText,
              size: 24,
            ),
            tooltip: 'Thông báo',
          ),
        ],
      ),
    );
  }
}

class _PendingBillCard extends StatelessWidget {
  const _PendingBillCard({
    required this.invoice,
    required this.onTap,
    required this.onComplain,
  });

  final TenantInvoice invoice;
  final VoidCallback onTap;
  final VoidCallback onComplain;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlue.withValues(alpha: 0.07),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 98),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.accentWarm, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  invoice.title,
                                  style: const TextStyle(
                                    color: AppColors.inputText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 20 / 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _formatAmount(
                                  invoice.remainingAmount > 0
                                      ? invoice.remainingAmount
                                      : invoice.totalAmount,
                                ),
                                style: const TextStyle(
                                  color: AppColors.deepBlue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  height: 21 / 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD6D6),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'CHỜ THANH TOÁN',
                                  style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    height: 14 / 10,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  'Hạn: ${_formatDate(invoice.dueDate)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.bodyText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    height: 15 / 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.apartment_rounded,
                                color: AppColors.bodyText,
                                size: 14,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                invoice.roomCode.isEmpty
                                    ? 'Chưa có phòng'
                                    : 'Phòng ${invoice.roomCode}',
                                style: const TextStyle(
                                  color: AppColors.bodyText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 16 / 12,
                                ),
                              ),
                            ],
                          ),
                          if (invoice.lines.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              invoice.lines.take(2).map(_lineLabel).join('\n'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.bodyText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 15 / 11,
                              ),
                            ),
                          ],
                          if (invoice.utilityMeterLines.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            if (invoice.hasOpenMeterReadingReview)
                              const _ReviewStatusChip()
                            else if (invoice.reviewableUtilityLines.isNotEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: onComplain,
                                  icon: const Icon(
                                    Icons.report_problem_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Khiếu nại chỉ số'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.deepBlue,
                                    side: BorderSide(
                                      color: AppColors.deepBlue.withValues(alpha: 0.25),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatReading(double? value) {
  if (value == null) return '--';
  final asInt = value.truncateToDouble() == value;
  return asInt ? value.toInt().toString() : value.toStringAsFixed(2);
}

String _utilityLineLabel(TenantInvoiceLine line) {
  if (line.lineType == 'ELECTRICITY') return 'Điện';
  if (line.lineType == 'WATER') return 'Nước';
  return line.description.isEmpty ? line.lineType : line.description;
}

class _ReviewStatusChip extends StatelessWidget {
  const _ReviewStatusChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFC2410C)),
          SizedBox(width: 6),
          Text(
            'Đang khiếu nại chỉ số',
            style: TextStyle(
              color: Color(0xFFC2410C),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeterReadingReviewSheet extends StatefulWidget {
  const _MeterReadingReviewSheet({
    required this.invoice,
    required this.lines,
    required this.invoiceService,
  });

  final TenantInvoice invoice;
  final List<TenantInvoiceLine> lines;
  final TenantInvoiceService invoiceService;

  @override
  State<_MeterReadingReviewSheet> createState() =>
      _MeterReadingReviewSheetState();
}

class _MeterReadingReviewSheetState extends State<_MeterReadingReviewSheet> {
  late TenantInvoiceLine _selectedLine = widget.lines.first;
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final current = _selectedLine.currentValue;
    if (current != null) {
      _valueController.text = _formatReading(current);
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Khiếu nại chỉ số điện nước',
                      style: TextStyle(
                        color: AppColors.inputText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TenantInvoiceLine>(
                initialValue: _selectedLine,
                items: widget.lines
                    .map(
                      (line) => DropdownMenuItem(
                        value: line,
                        child: Text(_utilityLineLabel(line)),
                      ),
                    )
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (line) {
                        if (line == null) return;
                        setState(() {
                          _selectedLine = line;
                          _valueController.text = line.currentValue == null
                              ? ''
                              : _formatReading(line.currentValue);
                        });
                      },
                decoration: const InputDecoration(
                  labelText: 'Dòng cần khiếu nại',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _ReadingSnapshot(line: _selectedLine),
              const SizedBox(height: 12),
              TextField(
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Chỉ số bạn cho là đúng',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Lý do khiếu nại',
                  hintText: 'Ví dụ: chỉ số trên đồng hồ hiện tại thấp hơn số trong hóa đơn...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Đang gửi...' : 'Gửi khiếu nại'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final invoiceId = widget.invoice.id;
    final lineId = _selectedLine.id;
    final value = double.tryParse(_valueController.text.trim().replaceAll(',', '.'));
    final reason = _reasonController.text.trim();
    if (invoiceId == null || lineId == null || value == null) {
      _snack('Vui lòng nhập chỉ số hợp lệ.');
      return;
    }
    final previous = _selectedLine.previousValue;
    if (previous != null && value < previous) {
      _snack('Chỉ số đề xuất không được nhỏ hơn chỉ số cũ.');
      return;
    }
    if (reason.length < 6) {
      _snack('Vui lòng mô tả lý do rõ hơn.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.invoiceService.submitMeterReadingReview(
        invoiceId: invoiceId,
        lineId: lineId,
        reportedCurrentValue: value,
        description: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi khiếu nại chỉ số.')),
      );
      Navigator.pop(context, true);
    } on TenantInvoiceException catch (error) {
      _snack(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReadingSnapshot extends StatelessWidget {
  const _ReadingSnapshot({required this.line});

  final TenantInvoiceLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _SnapshotRow(label: 'Chỉ số cũ', value: _formatReading(line.previousValue)),
          const SizedBox(height: 6),
          _SnapshotRow(label: 'Chỉ số trong hóa đơn', value: _formatReading(line.currentValue)),
          const SizedBox(height: 6),
          _SnapshotRow(label: 'Sản lượng tính tiền', value: _formatReading(line.usageAmount)),
          const SizedBox(height: 6),
          _SnapshotRow(label: 'Thành tiền', value: _formatAmount(line.amount)),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.label, required this.value});

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
          value,
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PaidDivider extends StatelessWidget {
  const _PaidDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFD7D7E0), height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'HÓA ĐƠN ĐÃ THANH TOÁN',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 14 / 10,
              letterSpacing: 0.9,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFD7D7E0), height: 1)),
      ],
    );
  }
}

class _PaidBillCard extends StatelessWidget {
  const _PaidBillCard({required this.invoice});

  final TenantInvoice invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.fromLTRB(22, 16, 18, 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        invoice.title,
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 20 / 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatAmount(invoice.totalAmount),
                      style: const TextStyle(
                        color: AppColors.inputText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 20 / 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8096FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'ĐÃ THANH TOÁN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 12 / 9,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        invoice.issuedAt == null
                            ? 'Đã thanh toán'
                            : 'Ngày: ${_formatDate(invoice.issuedAt)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.bodyText,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 15 / 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewHistoryButton extends StatelessWidget {
  const _ViewHistoryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppActionRowButton(
      icon: Icons.history_rounded,
      title: 'Xem toàn bộ lịch sử thanh toán',
      subtitle: 'Các hóa đơn đã thanh toán và biên nhận',
      accentColor: AppColors.actionCyan,
      onTap: onTap,
    );
  }
}
