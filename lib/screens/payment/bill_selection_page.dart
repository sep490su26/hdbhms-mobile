import 'package:flutter/material.dart';
import '../../models/payment/tenant_invoice_model.dart';
import '../../services/home/current_room_service.dart';
import '../../services/payment/tenant_invoice_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/room_scope.dart';
import '../../widgets/tenant_bottom_navigation.dart';
import '../../widgets/app_screen_shell.dart';
import '../../widgets/app_notification_bell.dart';
import '../../widgets/app_top_bar.dart';
import '../maintenance/maintenance_ticket_list_screen.dart';
import '../notification/notification_list_screen.dart';
import '../profile_request/tenant_profile_screen.dart';
import '../profile_request/tenant_request_screen.dart';
import 'bill_detail_screen.dart';
import 'payment_history_page.dart';
import 'qr_payment_page.dart';
import 'utility_complaint_screen.dart';
import '../../widgets/app_filter_chip.dart';

class BillSelectionPage extends StatefulWidget {
  const BillSelectionPage({
    super.key,
    this.invoiceService = const TenantInvoiceService(),
    this.currentRoomService = const CurrentRoomService(),
    this.roomId,
    this.roomCode = '',
  });

  final TenantInvoiceService invoiceService;
  final CurrentRoomService currentRoomService;
  final int? roomId;
  final String roomCode;

  @override
  State<BillSelectionPage> createState() => _BillSelectionPageState();
}

class _BillSelectionPageState extends State<BillSelectionPage> {
  _BillStatusFilter _activeStatusFilter = _BillStatusFilter.all;
  _BillTypeFilter _activeTypeFilter = _BillTypeFilter.all;
  _BillDateFilter _activeDateFilter = _BillDateFilter.all;
  DateTimeRange? _customDueDateRange;
  late Future<List<TenantInvoice>> _invoicesFuture;

  @override
  void initState() {
    super.initState();
    _invoicesFuture = _loadInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: _BillHeader(onOpenHistory: _openPaymentHistory),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
            children: [
              const Text('Tất cả hoá đơn', style: AppTypography.pageTitle),
              const SizedBox(height: 14),
              _BillFilterBar(
                activeStatus: _activeStatusFilter,
                activeType: _activeTypeFilter,
                activeDateFilter: _activeDateFilter,
                customDateRange: _customDueDateRange,
                onStatusChanged: (filter) =>
                    setState(() => _activeStatusFilter = filter),
                onTypeChanged: (filter) =>
                    setState(() => _activeTypeFilter = filter),
                onDateFilterTap: _selectDueDateFilter,
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
              builder: (context) => MaintenanceTicketListScreen(
                roomId: widget.roomId,
                roomCode: widget.roomCode,
              ),
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
          MaterialPageRoute(
            builder: (context) => TenantRequestScreen(
              roomId: widget.roomId,
              roomCode: widget.roomCode,
            ),
          ),
        ),
      ),
    );
  }

  void _reloadInvoices() {
    setState(() {
      _invoicesFuture = _loadInvoices();
    });
  }

  Future<List<TenantInvoice>> _loadInvoices() async {
    final scope = await resolveRoomScope(
      roomId: widget.roomId,
      roomCode: widget.roomCode,
      currentRoomService: widget.currentRoomService,
    );
    if (!scope.hasRoom) return const [];
    return widget.invoiceService.fetchMyInvoices(
      roomId: scope.roomId,
      roomCode: scope.roomCode,
    );
  }

  void _openPaymentHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentHistoryPage(
          invoiceService: widget.invoiceService,
          currentRoomService: widget.currentRoomService,
          roomId: widget.roomId,
          roomCode: widget.roomCode,
        ),
      ),
    );
  }

  Future<void> _selectDueDateFilter() async {
    final selected = await showModalBottomSheet<_BillDateFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) =>
          _BillDateFilterSheet(activeFilter: _activeDateFilter),
    );
    if (!mounted || selected == null) return;

    if (selected == _BillDateFilter.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 10),
        initialDateRange: _customDueDateRange,
        helpText: 'Chọn khoảng hạn thanh toán',
      );
      if (!mounted || picked == null) return;
      setState(() {
        _activeDateFilter = selected;
        _customDueDateRange = picked;
      });
      return;
    }

    setState(() => _activeDateFilter = selected);
  }

  void _openInvoicePreviewFlow(BuildContext context, TenantInvoice invoice) {
    final isUtility = invoice.invoiceType.toUpperCase() == 'UTILITY';
    final canOpenQr =
        invoice.canPay &&
        (invoice.qrCode.isNotEmpty || invoice.transferDescription.isNotEmpty);

    if (isUtility || !canOpenQr) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => BillDetailScreen(
                invoice: invoice,
                invoiceService: widget.invoiceService,
              ),
            ),
          )
          .then((_) => _reloadInvoices());
      return;
    }

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
    if (invoice.hasOpenMeterReadingReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hóa đơn này đã có khiếu nại đang chờ xử lý.'),
        ),
      );
      return;
    }
    if (invoice.reviewableUtilityLines.isEmpty || invoice.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hóa đơn này chưa thể gửi khiếu nại chỉ số.'),
        ),
      );
      return;
    }
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => UtilityComplaintScreen(
          invoice: invoice,
          invoiceService: widget.invoiceService,
        ),
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
    final typeFilteredInvoices = invoices
        .where((invoice) => _matchesTypeFilter(invoice, _activeTypeFilter))
        .where(
          (invoice) => _matchesDueDateFilter(
            invoice,
            _activeDateFilter,
            _customDueDateRange,
          ),
        )
        .toList(growable: false);

    final pendingBills = _withSpacing(
      typeFilteredInvoices
          .where((invoice) => !invoice.isPaid)
          .map(
            (invoice) => _PendingBillCard(
              invoice: invoice,
              onTap: () => _openInvoicePreviewFlow(context, invoice),
              onComplain: () => _openMeterReadingReview(context, invoice),
            ),
          )
          .toList(),
      16,
    );

    final paidBills = _withSpacing(
      typeFilteredInvoices
          .where((invoice) => invoice.isPaid)
          .map(
            (invoice) => _PaidBillCard(
              invoice: invoice,
              onTap: () => _openInvoicePreviewFlow(context, invoice),
            ),
          )
          .toList(),
      12,
    );

    if (invoices.isEmpty) {
      return const [
        _BillEmptyState(
          title: 'Chưa có hóa đơn',
          message: 'Khi chủ trọ phát hành hóa đơn, bạn sẽ thấy tại đây.',
        ),
      ];
    }

    if (typeFilteredInvoices.isEmpty) {
      final hasDateFilter = _activeDateFilter != _BillDateFilter.all;
      return [
        _BillEmptyState(
          title: hasDateFilter
              ? 'Không có hóa đơn trong khoảng đã chọn'
              : 'Không có hóa đơn ${_typeFilterEmptyLabel(_activeTypeFilter)}',
          message: hasDateFilter
              ? 'Thử thay đổi hạn thanh toán hoặc loại hóa đơn để xem các khoản khác.'
              : 'Thử chọn loại hóa đơn khác để xem các khoản đang có.',
        ),
      ];
    }

    return switch (_activeStatusFilter) {
      _BillStatusFilter.all => [
        if (pendingBills.isNotEmpty) ...pendingBills,
        if (paidBills.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _PaidDivider(),
          const SizedBox(height: 22),
          ...paidBills,
        ],
      ],
      _BillStatusFilter.unpaid =>
        pendingBills.isEmpty
            ? const [
                _BillEmptyState(
                  title: 'Không có khoản cần trả',
                  message: 'Phòng hiện tại chưa có hóa đơn chờ thanh toán.',
                ),
              ]
            : pendingBills,
      _BillStatusFilter.paid =>
        paidBills.isEmpty
            ? const [
                _BillEmptyState(
                  title: 'Chưa có lịch sử thanh toán',
                  message: 'Các hóa đơn đã thanh toán sẽ được lưu ở đây.',
                ),
              ]
            : paidBills,
    };
  }
}

enum _BillStatusFilter { all, unpaid, paid }

enum _BillTypeFilter { all, rent, utility, other }

enum _BillDateFilter { all, overdue, next7Days, next30Days, next90Days, custom }

bool _matchesTypeFilter(TenantInvoice invoice, _BillTypeFilter filter) {
  return switch (filter) {
    _BillTypeFilter.all => true,
    _BillTypeFilter.rent => invoice.isRentType,
    _BillTypeFilter.utility => invoice.isUtilityType,
    _BillTypeFilter.other => invoice.isOtherType,
  };
}

String _typeFilterEmptyLabel(_BillTypeFilter filter) {
  return switch (filter) {
    _BillTypeFilter.all => '',
    _BillTypeFilter.rent => 'tiền phòng',
    _BillTypeFilter.utility => 'điện nước & dịch vụ',
    _BillTypeFilter.other => 'khác',
  };
}

bool _matchesDueDateFilter(
  TenantInvoice invoice,
  _BillDateFilter filter,
  DateTimeRange? customRange,
) {
  if (filter == _BillDateFilter.all) return true;
  final dueDate = invoice.dueDate;
  if (dueDate == null) return false;

  final today = _dateOnly(DateTime.now());
  final normalizedDueDate = _dateOnly(dueDate);
  if (filter == _BillDateFilter.overdue) {
    return !invoice.isPaid && normalizedDueDate.isBefore(today);
  }
  if (filter == _BillDateFilter.custom) {
    if (customRange == null) return true;
    return !normalizedDueDate.isBefore(_dateOnly(customRange.start)) &&
        !normalizedDueDate.isAfter(_dateOnly(customRange.end));
  }

  final days = switch (filter) {
    _BillDateFilter.next7Days => 7,
    _BillDateFilter.next30Days => 30,
    _BillDateFilter.next90Days => 90,
    _ => 0,
  };
  final endDate = today.add(Duration(days: days - 1));
  return !normalizedDueDate.isBefore(today) &&
      !normalizedDueDate.isAfter(endDate);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _billDateFilterLabel(
  _BillDateFilter filter,
  DateTimeRange? customRange,
) {
  return switch (filter) {
    _BillDateFilter.all => 'Tất cả thời hạn',
    _BillDateFilter.overdue => 'Quá hạn',
    _BillDateFilter.next7Days => '7 ngày tới',
    _BillDateFilter.next30Days => '30 ngày tới',
    _BillDateFilter.next90Days => '90 ngày tới',
    _BillDateFilter.custom =>
      customRange == null
          ? 'Khoảng ngày'
          : '${_formatDate(customRange.start)} - ${_formatDate(customRange.end)}',
  };
}

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

IconData _invoiceTypeIcon(TenantInvoice invoice) {
  if (invoice.isRentType) return Icons.apartment_rounded;
  if (invoice.isUtilityType) return Icons.bolt_rounded;
  return Icons.more_horiz_rounded;
}

Color _invoiceTypeColor(TenantInvoice invoice) {
  if (invoice.isRentType) return AppColors.deepBlue;
  if (invoice.isUtilityType) return const Color(0xFF0EA5E9);
  return const Color(0xFF64748B);
}

class _InvoiceTypePill extends StatelessWidget {
  const _InvoiceTypePill({required this.invoice});

  final TenantInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final color = _invoiceTypeColor(invoice);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_invoiceTypeIcon(invoice), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            invoice.invoiceTypeLabel,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 14 / 10,
            ),
          ),
        ],
      ),
    );
  }
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
  const _BillFilterBar({
    required this.activeStatus,
    required this.activeType,
    required this.activeDateFilter,
    required this.customDateRange,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onDateFilterTap,
  });

  final _BillStatusFilter activeStatus;
  final _BillTypeFilter activeType;
  final _BillDateFilter activeDateFilter;
  final DateTimeRange? customDateRange;
  final ValueChanged<_BillStatusFilter> onStatusChanged;
  final ValueChanged<_BillTypeFilter> onTypeChanged;
  final VoidCallback onDateFilterTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppFilterChip(
                label: 'Tất cả',
                icon: Icons.list_rounded,
                isActive: activeStatus == _BillStatusFilter.all,
                onTap: () => onStatusChanged(_BillStatusFilter.all),
              ),
              const SizedBox(width: 8),
              AppFilterChip(
                label: 'Chưa thanh toán',
                icon: Icons.pending_actions_rounded,
                isActive: activeStatus == _BillStatusFilter.unpaid,
                onTap: () => onStatusChanged(_BillStatusFilter.unpaid),
              ),
              const SizedBox(width: 8),
              AppFilterChip(
                label: 'Đã thanh toán',
                icon: Icons.task_alt_rounded,
                isActive: activeStatus == _BillStatusFilter.paid,
                onTap: () => onStatusChanged(_BillStatusFilter.paid),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AppFilterChip(
                label: 'Mọi loại',
                icon: Icons.category_outlined,
                isActive: activeType == _BillTypeFilter.all,
                onTap: () => onTypeChanged(_BillTypeFilter.all),
              ),
              const SizedBox(width: 8),
              AppFilterChip(
                label: 'Tiền phòng',
                icon: Icons.apartment_rounded,
                isActive: activeType == _BillTypeFilter.rent,
                onTap: () => onTypeChanged(_BillTypeFilter.rent),
              ),
              const SizedBox(width: 8),
              AppFilterChip(
                label: 'Điện nước & DV',
                icon: Icons.bolt_rounded,
                isActive: activeType == _BillTypeFilter.utility,
                onTap: () => onTypeChanged(_BillTypeFilter.utility),
              ),
              const SizedBox(width: 8),
              AppFilterChip(
                label: 'Khác',
                icon: Icons.more_horiz_rounded,
                isActive: activeType == _BillTypeFilter.other,
                onTap: () => onTypeChanged(_BillTypeFilter.other),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label:
              'Lọc theo hạn thanh toán: ${_billDateFilterLabel(activeDateFilter, customDateRange)}',
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onDateFilterTap,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: activeDateFilter == _BillDateFilter.all
                      ? AppColors.surface
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activeDateFilter == _BillDateFilter.all
                        ? AppColors.cardBorder
                        : AppColors.primary.withValues(alpha: 0.38),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 19,
                      color: activeDateFilter == _BillDateFilter.all
                          ? AppColors.bodyText
                          : AppColors.deepBlue,
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'Hạn thanh toán',
                      style: TextStyle(
                        color: AppColors.bodyText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        _billDateFilterLabel(activeDateFilter, customDateRange),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.deepBlue,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BillDateFilterSheet extends StatelessWidget {
  const _BillDateFilterSheet({required this.activeFilter});

  final _BillDateFilter activeFilter;

  @override
  Widget build(BuildContext context) {
    final filters = _BillDateFilter.values;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    final preferredHeight = 128.0 + (filters.length * 48.0);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: preferredHeight > maxHeight ? maxHeight : preferredHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _BottomSheetHandle()),
                  SizedBox(height: 18),
                  Text(
                    'Lọc theo hạn thanh toán',
                    style: TextStyle(
                      color: AppColors.inputText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Các hóa đơn trong khoảng được chọn sẽ hiển thị.',
                    style: TextStyle(
                      color: AppColors.bodyText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.cardBorder),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                itemCount: filters.length,
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  return _DateFilterOption(
                    label: _billDateFilterLabel(filter, null),
                    icon: switch (filter) {
                      _BillDateFilter.all => Icons.date_range_outlined,
                      _BillDateFilter.overdue => Icons.warning_amber_rounded,
                      _BillDateFilter.next7Days => Icons.looks_one_outlined,
                      _BillDateFilter.next30Days => Icons.date_range_rounded,
                      _BillDateFilter.next90Days =>
                        Icons.calendar_month_rounded,
                      _BillDateFilter.custom => Icons.edit_calendar_outlined,
                    },
                    isSelected: activeFilter == filter,
                    onTap: () => Navigator.of(context).pop(filter),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetHandle extends StatelessWidget {
  const _BottomSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _DateFilterOption extends StatelessWidget {
  const _DateFilterOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.bodyText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.inputText,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillHeader extends StatelessWidget {
  const _BillHeader({required this.onOpenHistory});

  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return AppTopBar(
      title: 'Hóa đơn',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onOpenHistory,
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Lịch sử thanh toán',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            icon: const AppNotificationBell(),
            tooltip: 'Thông báo',
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _LegacyBillHeader extends StatelessWidget {
  const _LegacyBillHeader({required this.onOpenHistory});

  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppColors.topBarHeight,
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
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text('Hóa đơn', style: AppColors.topBarTitleStyle),
          ),
          IconButton(
            onPressed: onOpenHistory,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: const Icon(
              Icons.history_rounded,
              color: AppColors.topBarIconColor,
              size: AppColors.topBarIconSize,
            ),
            tooltip: 'Lịch sử thanh toán',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: const AppNotificationBell(
              color: AppColors.topBarIconColor,
              size: AppColors.topBarIconSize,
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
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
                              _InvoiceTypePill(invoice: invoice),
                              Text(
                                'Hạn: ${_formatDate(invoice.dueDate)}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.bodyText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  height: 15 / 11,
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
                          if (invoice.utilityMeterLines.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            if (invoice.hasOpenMeterReadingReview)
                              const _ReviewStatusChip()
                            else if (invoice.reviewableUtilityLines.isNotEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _ComplaintButton(onTap: onComplain),
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

class _ComplaintButton extends StatelessWidget {
  const _ComplaintButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFFFF7ED), const Color(0xFFFEF3C7)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.report_problem_rounded,
              size: 14,
              color: Color(0xFFD97706),
            ),
            SizedBox(width: 6),
            Text(
              'Khiếu nại điện nước',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 10,
              color: Color(0xFFD97706),
            ),
          ],
        ),
      ),
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
  const _PaidBillCard({required this.invoice, required this.onTap});

  final TenantInvoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                      const SizedBox(width: 8),
                      _InvoiceTypePill(invoice: invoice),
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
      ),
    );
  }
}
