import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import '../../models/payment/tenant_invoice_model.dart';
import '../../services/home/current_room_service.dart';
import '../../services/payment/tenant_invoice_service.dart';
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
import '../../widgets/app_list_state.dart';

class BillSelectionPage extends StatefulWidget {
  const BillSelectionPage({
    super.key,
    this.invoiceService = const TenantInvoiceService(),
    this.currentRoomService = const CurrentRoomService(),
    this.roomId,
    this.roomCode = '',
    this.previewInvoices,
    this.previewServicePaymentCycleMonths,
    this.notificationInitialUnreadCount,
  });

  final TenantInvoiceService invoiceService;
  final CurrentRoomService currentRoomService;
  final int? roomId;
  final String roomCode;

  /// Local-only invoices used by the internal preview launcher.
  final List<TenantInvoice>? previewInvoices;

  /// Local-only contract cycle used to render a demonstrably correct service
  /// fee breakdown in the internal preview flow. Production screens load the
  /// cycle from the invoice contract instead.
  final int? previewServicePaymentCycleMonths;
  final int? notificationInitialUnreadCount;

  @override
  State<BillSelectionPage> createState() => _BillSelectionPageState();
}

class _BillSelectionPageState extends State<BillSelectionPage> {
  _BillTypeFilter _activeTypeFilter = _BillTypeFilter.all;
  late Future<List<TenantInvoice>> _invoicesFuture;
  RoomScope _roomScope = const RoomScope();

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
          header: _BillHeader(
            onOpenHistory: _openPaymentHistory,
            notificationInitialUnreadCount:
                widget.notificationInitialUnreadCount,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
            children: [
              const Text(
                'Hóa đơn cần thanh toán',
                style: AppTypography.pageTitle,
              ),
              const SizedBox(height: 14),
              _BillFilterBar(
                activeType: _activeTypeFilter,
                onTypeChanged: (filter) =>
                    setState(() => _activeTypeFilter = filter),
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
                      .where(
                        (invoice) => invoice.isTenantVisible && !invoice.isPaid,
                      )
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
                roomId: _activeRoomId,
                roomCode: _activeRoomCode,
              ),
            ),
          );
        },
        onProfileTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TenantProfileScreen(
                roomId: _activeRoomId,
                roomCode: _activeRoomCode,
              ),
            ),
          );
        },
        onRequestsTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TenantRequestScreen(
              roomId: _activeRoomId,
              roomCode: _activeRoomCode,
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
    final previewInvoices = widget.previewInvoices;
    if (previewInvoices != null) return previewInvoices;
    final scope = await resolveRoomScope(
      roomId: widget.roomId,
      roomCode: widget.roomCode,
      currentRoomService: widget.currentRoomService,
    );
    _roomScope = scope;
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
          roomId: _activeRoomId,
          roomCode: _activeRoomCode,
        ),
      ),
    );
  }

  int? get _activeRoomId => _roomScope.roomId ?? widget.roomId;

  String get _activeRoomCode =>
      _roomScope.roomCode.isNotEmpty ? _roomScope.roomCode : widget.roomCode;

  void _openInvoicePreviewFlow(BuildContext context, TenantInvoice invoice) {
    final isUtility = invoice.invoiceType.toUpperCase() == 'UTILITY';
    final canOpenQr =
        invoice.canPay &&
        (invoice.qrCode.isNotEmpty || invoice.transferDescription.isNotEmpty);

    // The list is only an index: every invoice is reviewed before payment.
    if (invoice.isTenantVisible || isUtility || !canOpenQr) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => BillDetailScreen(
                invoice: invoice,
                invoiceService: widget.invoiceService,
                servicePaymentCycleMonths:
                    widget.previewServicePaymentCycleMonths,
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
        (invoice.hasPayosQr || invoice.transferDescription.isNotEmpty)) {
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
    final typeFilteredInvoices =
        invoices
            .where((invoice) => _matchesTypeFilter(invoice, _activeTypeFilter))
            .toList()
          ..sort(_compareInvoicesByCreatedDate);

    final pendingBills = _withSpacing(
      typeFilteredInvoices
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

    if (invoices.isEmpty) {
      return const [
        _BillEmptyState(
          title: 'Không có khoản cần thanh toán',
          message:
              'Các hóa đơn đã thanh toán được lưu trong Lịch sử thanh toán.',
        ),
      ];
    }

    if (typeFilteredInvoices.isEmpty) {
      return [
        _BillEmptyState(
          title: 'Không có khoản cần thanh toán',
          message: 'Thử chọn loại hóa đơn khác hoặc xem Lịch sử thanh toán.',
        ),
      ];
    }

    return pendingBills;
  }
}

enum _BillTypeFilter { all, rent, utility, other }

bool _matchesTypeFilter(TenantInvoice invoice, _BillTypeFilter filter) {
  return switch (filter) {
    _BillTypeFilter.all => true,
    _BillTypeFilter.rent => invoice.isRentType,
    _BillTypeFilter.utility => invoice.isUtilityType,
    _BillTypeFilter.other => invoice.isOtherType,
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

int _compareInvoicesByCreatedDate(TenantInvoice first, TenantInvoice second) {
  final firstDate = _invoiceCreatedDate(first);
  final secondDate = _invoiceCreatedDate(second);
  final dateOrder = secondDate.compareTo(firstDate);
  if (dateOrder != 0) return dateOrder;
  return (second.id ?? 0).compareTo(first.id ?? 0);
}

DateTime _invoiceCreatedDate(TenantInvoice invoice) {
  return invoice.issueDate ??
      invoice.issuedAt ??
      invoice.paidAt ??
      invoice.dueDate ??
      DateTime.fromMillisecondsSinceEpoch(0);
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
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
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
  Widget build(BuildContext context) => AppListState(
    kind: AppListStateKind.error,
    title: 'Không tải được hóa đơn',
    description: message,
    actionLabel: 'Thử lại',
    actionIcon: Icons.refresh_rounded,
    onAction: onRetry,
  );
}

class _BillEmptyState extends StatelessWidget {
  const _BillEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => AppListState(
    kind: AppListStateKind.empty,
    title: title,
    description: message,
    icon: Icons.receipt_long_outlined,
  );
}

class _BillFilterBar extends StatelessWidget {
  const _BillFilterBar({required this.activeType, required this.onTypeChanged});

  final _BillTypeFilter activeType;
  final ValueChanged<_BillTypeFilter> onTypeChanged;

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
                icon: Icons.grid_view_rounded,
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
                label: 'Tiền điện & dịch vụ',
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
      ],
    );
  }
}

class _BillHeader extends StatelessWidget {
  const _BillHeader({
    required this.onOpenHistory,
    this.notificationInitialUnreadCount,
  });

  final VoidCallback onOpenHistory;
  final int? notificationInitialUnreadCount;

  @override
  Widget build(BuildContext context) {
    return AppTopBar(
      title: 'Hóa đơn',
      pageIcon: Icons.receipt_long_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onOpenHistory,
            constraints: const BoxConstraints.tightFor(
              width: AppColors.minimumTouchTarget,
              height: AppColors.minimumTouchTarget,
            ),
            icon: const Icon(
              Icons.history_rounded,
              color: AppColors.topBarIconColor,
            ),
            tooltip: 'Lịch sử thanh toán',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            icon: AppNotificationBell(
              initialUnreadCount: notificationInitialUnreadCount,
            ),
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
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
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
                                  borderRadius: BorderRadius.circular(
                                    AppColors.radiusPill,
                                  ),
                                ),
                                child: const Text(
                                  'CHỜ THANH TOÁN',
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    height: 14 / 10,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              _InvoiceTypePill(invoice: invoice),
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
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: AppColors.bodyText,
                                size: 14,
                              ),
                              const SizedBox(width: 7),
                              const Text(
                                'Hạn nộp:',
                                style: TextStyle(
                                  color: AppColors.bodyText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(invoice.dueDate),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (invoice.utilityMeterLines.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            if (invoice.hasOpenMeterReadingReview)
                              const _ReviewStatusChip(),
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
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
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

// Retained only as a local presentation primitive for future contextual detail UI.
// ignore: unused_element
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
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          border: Border.all(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.15),
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
              'Khiếu nại số điện',
              style: TextStyle(
                color: AppColors.warningText,
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
