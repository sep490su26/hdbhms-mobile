import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

import '../../models/payment/tenant_invoice_model.dart';
import '../../services/home/current_room_service.dart';
import '../../services/payment/tenant_invoice_service.dart';
import '../../utils/room_scope.dart';
import '../../widgets/app_notification_bell.dart';
import '../../widgets/app_screen_shell.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/app_filter_chip.dart';
import '../../widgets/app_list_state.dart';
import '../../widgets/app_month_year_picker.dart';
import '../../widgets/tenant_bottom_navigation.dart';
import '../maintenance/maintenance_ticket_list_screen.dart';
import '../notification/notification_list_screen.dart';
import '../profile_request/tenant_profile_screen.dart';
import '../profile_request/tenant_request_screen.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({
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
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<TenantInvoice>> _invoicesFuture;
  DateTime? _selectedPaidMonth;
  _HistoryInvoiceTypeFilter _selectedTypeFilter = _HistoryInvoiceTypeFilter.all;

  @override
  void initState() {
    super.initState();
    _invoicesFuture = _loadInvoices();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
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

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedPaidMonth = null;
      _selectedTypeFilter = _HistoryInvoiceTypeFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: const _HistoryHeader(),
          child: FutureBuilder<List<TenantInvoice>>(
            future: _invoicesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _HistoryLoading();
              }
              if (snapshot.hasError) {
                return _HistoryError(
                  message: snapshot.error is TenantInvoiceException
                      ? (snapshot.error as TenantInvoiceException).message
                      : 'Không tải được lịch sử thanh toán.',
                  onRetry: _reload,
                );
              }

              final paidInvoices = _paidInvoices(snapshot.data ?? const []);
              final filteredInvoices = _filterInvoices(paidInvoices);

              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                children: [
                  // Page title
                  const Text(
                    'Hoá đơn đã thanh toán',
                    style: TextStyle(
                      color: AppColors.darkBlue,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 30 / 24,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search field
                  _SearchField(controller: _searchController),
                  const SizedBox(height: 12),

                  _HistoryDateFilterControl(
                    selectedMonth: _selectedPaidMonth,
                    onTap: paidInvoices.isEmpty
                        ? null
                        : () => _selectPaidDateFilter(paidInvoices),
                  ),
                  const SizedBox(height: 12),
                  _HistoryTypeFilterBar(
                    selectedFilter: _selectedTypeFilter,
                    onChanged: (filter) =>
                        setState(() => _selectedTypeFilter = filter),
                  ),
                  const SizedBox(height: 16),

                  // Content
                  if (filteredInvoices.isEmpty)
                    _HistoryEmpty(
                      hasAnyPaidInvoice: paidInvoices.isNotEmpty,
                      onClearFilter: _clearFilters,
                    )
                  else ...[
                    for (var i = 0; i < filteredInvoices.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _HistoryCard(invoice: filteredInvoices[i]),
                    ],
                  ],
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.bills,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
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

  List<TenantInvoice> _paidInvoices(List<TenantInvoice> invoices) {
    final result = invoices.where((invoice) => invoice.isPaid).toList()
      ..sort((a, b) => _historyDate(b).compareTo(_historyDate(a)));
    return List.unmodifiable(result);
  }

  List<TenantInvoice> _filterInvoices(List<TenantInvoice> invoices) {
    final keyword = _searchController.text.trim().toLowerCase();
    return invoices
        .where((invoice) {
          if (!_matchesHistoryTypeFilter(invoice, _selectedTypeFilter)) {
            return false;
          }
          final date = _historyDate(invoice);
          if (!_matchesHistoryDateFilter(date, _selectedPaidMonth)) {
            return false;
          }
          if (keyword.isEmpty) return true;
          final haystack = [
            invoice.title,
            invoice.invoiceCode,
            invoice.roomCode,
            invoice.contractCode,
            invoice.billingPeriod,
            _formatAmount(_historyAmount(invoice)),
            ...invoice.lines.map((line) => line.description),
          ].join(' ').toLowerCase();
          return haystack.contains(keyword);
        })
        .toList(growable: false);
  }

  Future<void> _selectPaidDateFilter(List<TenantInvoice> paidInvoices) async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month);
    final datedInvoices = paidInvoices
        .map(_historyDate)
        .where((date) => date.year >= 2000 && !date.isAfter(now))
        .toList(growable: false);
    if (datedInvoices.isEmpty) return;
    var firstDate = datedInvoices.first;
    for (final date in datedInvoices.skip(1)) {
      if (date.isBefore(firstDate)) firstDate = date;
    }
    final firstMonth = DateTime(firstDate.year, firstDate.month);
    final selected = await showAppMonthYearPicker(
      context: context,
      selectedMonth: _selectedPaidMonth,
      title: 'Chọn tháng giao dịch',
      firstMonth: firstMonth,
      lastMonth: lastMonth,
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedPaidMonth = selected.year == 0 ? null : selected);
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return AppTopBar(
      title: 'Lịch sử thanh toán',
      onBack: () => Navigator.of(context).maybePop(),
      trailing: IconButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const NotificationListScreen(),
          ),
        ),
        icon: const AppNotificationBell(),
        tooltip: 'Thông báo',
      ),
    );
  }
}

// ignore: unused_element
class _LegacyHistoryHeader extends StatelessWidget {
  const _LegacyHistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppColors.topBarHeight,
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.topBarIconColor,
              size: AppColors.topBarIconSize,
            ),
            tooltip: 'Quay lại',
          ),
          const Expanded(
            child: Text(
              'Lịch sử thanh toán',
              style: AppColors.topBarTitleStyle,
            ),
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

// ── Search Field ──────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Tìm theo mã hóa đơn, phòng, nội dung...',
        hintStyle: const TextStyle(
          color: AppColors.bodyText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.bodyText,
          size: 20,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
        ),
      ),
      style: const TextStyle(
        color: AppColors.inputText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── Period Filter Card ────────────────────────────────────────────────────────

class _HistoryDateFilterControl extends StatelessWidget {
  const _HistoryDateFilterControl({
    required this.selectedMonth,
    required this.onTap,
  });

  final DateTime? selectedMonth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Ink(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selectedMonth == null
                ? AppColors.surface
                : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(
              color: selectedMonth == null
                  ? AppColors.cardBorder
                  : AppColors.primary.withValues(alpha: 0.38),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 19,
                  color: selectedMonth == null
                      ? AppColors.bodyText
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thời gian giao dịch',
                      style: TextStyle(
                        color: AppColors.inputText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _monthLabel(selectedMonth),
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.bodyText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.deepBlue,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTypeFilterBar extends StatelessWidget {
  const _HistoryTypeFilterBar({
    required this.selectedFilter,
    required this.onChanged,
  });

  final _HistoryInvoiceTypeFilter selectedFilter;
  final ValueChanged<_HistoryInvoiceTypeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          AppFilterChip(
            label: 'Mọi loại',
            icon: Icons.category_outlined,
            isActive: selectedFilter == _HistoryInvoiceTypeFilter.all,
            onTap: () => onChanged(_HistoryInvoiceTypeFilter.all),
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            label: 'Tiền phòng',
            icon: Icons.apartment_rounded,
            isActive: selectedFilter == _HistoryInvoiceTypeFilter.rent,
            onTap: () => onChanged(_HistoryInvoiceTypeFilter.rent),
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            label: 'Điện & dịch vụ',
            icon: Icons.bolt_rounded,
            isActive: selectedFilter == _HistoryInvoiceTypeFilter.utility,
            onTap: () => onChanged(_HistoryInvoiceTypeFilter.utility),
          ),
          const SizedBox(width: 8),
          AppFilterChip(
            label: 'Khác',
            icon: Icons.more_horiz_rounded,
            isActive: selectedFilter == _HistoryInvoiceTypeFilter.other,
            onTap: () => onChanged(_HistoryInvoiceTypeFilter.other),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _HistoryDateFilterSheet extends StatelessWidget {
  const _HistoryDateFilterSheet({required this.activeFilter});

  final _HistoryDateFilter activeFilter;

  @override
  Widget build(BuildContext context) {
    final filters = _HistoryDateFilter.values;
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
                  Center(child: _HistoryBottomSheetHandle()),
                  SizedBox(height: 18),
                  Text(
                    'Lọc theo ngày giao dịch',
                    style: TextStyle(
                      color: AppColors.inputText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Dựa trên ngày hóa đơn được thanh toán.',
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
                  return _HistoryDateFilterOption(
                    label: _historyDateFilterLabel(filter, null),
                    icon: switch (filter) {
                      _HistoryDateFilter.all => Icons.date_range_outlined,
                      _HistoryDateFilter.last7Days => Icons.looks_one_outlined,
                      _HistoryDateFilter.last30Days => Icons.date_range_rounded,
                      _HistoryDateFilter.last90Days =>
                        Icons.calendar_month_rounded,
                      _HistoryDateFilter.custom => Icons.edit_calendar_outlined,
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

class _HistoryBottomSheetHandle extends StatelessWidget {
  const _HistoryBottomSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
    );
  }
}

class _HistoryDateFilterOption extends StatelessWidget {
  const _HistoryDateFilterOption({
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
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
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

// ── History Card (individual) ─────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.invoice});

  final TenantInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final amount = _historyAmount(invoice);
    final date = _historyDate(invoice);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar (green = paid)
            Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.success, Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEFFF),
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      ),
                      child: Icon(
                        _historyIcon(invoice),
                        color: AppColors.deepBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title & meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.inputText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 20 / 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (invoice.roomCode.isNotEmpty)
                                'Phòng ${invoice.roomCode}',
                              _formatDate(date),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.bodyText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 17 / 12,
                            ),
                          ),
                          if (invoice.invoiceCode.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              invoice.invoiceCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.hintText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 15 / 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          // Paid badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD7FBE4),
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusPill,
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.successText,
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'ĐÃ THANH TOÁN',
                                    style: TextStyle(
                                      color: Color(0xFF15803D),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      height: 13 / 10,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Amount
                    Text(
                      '${_formatAmount(amount)}đ',
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 21 / 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      children: const [
        AppSkeleton(width: double.infinity, height: 36, borderRadius: 8),
        SizedBox(height: 14),
        AppSkeleton(width: double.infinity, height: 44, borderRadius: 12),
        SizedBox(height: 14),
        Row(
          children: [
            AppSkeleton(width: 68, height: 34, borderRadius: 999),
            SizedBox(width: 8),
            AppSkeleton(width: 56, height: 34, borderRadius: 999),
            SizedBox(width: 8),
            AppSkeleton(width: 56, height: 34, borderRadius: 999),
          ],
        ),
        SizedBox(height: 24),
        AppSkeleton(width: double.infinity, height: 98, borderRadius: 16),
        SizedBox(height: 12),
        AppSkeleton(width: double.infinity, height: 98, borderRadius: 16),
        SizedBox(height: 12),
        AppSkeleton(width: double.infinity, height: 98, borderRadius: 16),
      ],
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppListState(
    kind: AppListStateKind.error,
    title: 'Không tải được lịch sử thanh toán',
    description: message,
    actionLabel: 'Thử lại',
    onAction: onRetry,
  );
}

// ── Empty ─────────────────────────────────────────────────────────────────────

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({
    required this.hasAnyPaidInvoice,
    required this.onClearFilter,
  });

  final bool hasAnyPaidInvoice;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) => AppListState(
    kind: AppListStateKind.empty,
    title: hasAnyPaidInvoice
        ? 'Không có giao dịch phù hợp'
        : 'Chưa có lịch sử thanh toán',
    description: hasAnyPaidInvoice
        ? 'Thử thay đổi bộ lọc hoặc từ khóa tìm kiếm.'
        : 'Các giao dịch đã thanh toán sẽ xuất hiện ở đây.',
    icon: Icons.receipt_long_outlined,
    actionLabel: hasAnyPaidInvoice ? 'Xóa bộ lọc' : null,
    onAction: hasAnyPaidInvoice ? onClearFilter : null,
  );

  // Retained temporarily to preserve the previous layout during migration.
  // ignore: unused_element
  Widget _buildLegacy(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
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
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
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
                  hasAnyPaidInvoice
                      ? 'Không có giao dịch phù hợp'
                      : 'Chưa có lịch sử thanh toán',
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 18 / 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAnyPaidInvoice
                      ? 'Thử thay đổi bộ lọc hoặc từ khoá tìm kiếm.'
                      : 'Các giao dịch đã thanh toán sẽ xuất hiện ở đây.',
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 18 / 13,
                  ),
                ),
                if (hasAnyPaidInvoice) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onClearFilter,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.deepBlue,
                      minimumSize: const Size(0, 32),
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Xoá bộ lọc'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Enums & helpers ───────────────────────────────────────────────────────────

enum _HistoryDateFilter { all, last7Days, last30Days, last90Days, custom }

enum _HistoryInvoiceTypeFilter { all, rent, utility, other }

DateTime _historyDate(TenantInvoice invoice) {
  return invoice.paidAt ??
      invoice.issuedAt ??
      invoice.dueDate ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

bool _matchesHistoryTypeFilter(
  TenantInvoice invoice,
  _HistoryInvoiceTypeFilter filter,
) {
  return switch (filter) {
    _HistoryInvoiceTypeFilter.all => true,
    _HistoryInvoiceTypeFilter.rent => invoice.isRentType,
    _HistoryInvoiceTypeFilter.utility => invoice.isUtilityType,
    _HistoryInvoiceTypeFilter.other => invoice.isOtherType,
  };
}

bool _matchesHistoryDateFilter(DateTime date, DateTime? selectedMonth) {
  return selectedMonth == null ||
      (date.year == selectedMonth.year && date.month == selectedMonth.month);
}

// ignore: unused_element
DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _monthLabel(DateTime? selectedMonth) => selectedMonth == null
    ? 'Tất cả tháng'
    : 'Tháng ${selectedMonth.month.toString().padLeft(2, '0')}/${selectedMonth.year}';

String _historyDateFilterLabel(
  _HistoryDateFilter filter,
  DateTimeRange? customRange,
) {
  return switch (filter) {
    _HistoryDateFilter.all => 'Tất cả thời gian',
    _HistoryDateFilter.last7Days => '7 ngày qua',
    _HistoryDateFilter.last30Days => '30 ngày qua',
    _HistoryDateFilter.last90Days => '90 ngày qua',
    _HistoryDateFilter.custom =>
      customRange == null
          ? 'Khoảng ngày'
          : '${_formatDate(customRange.start)} - ${_formatDate(customRange.end)}',
  };
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return 'Chưa có ngày';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

int _historyAmount(TenantInvoice invoice) {
  if (invoice.paidAmount > 0) return invoice.paidAmount;
  return invoice.totalAmount;
}

String _formatAmount(int amount) {
  final value = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < value.length; index += 1) {
    if (index > 0 && (value.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(value[index]);
  }
  return buffer.toString();
}

IconData _historyIcon(TenantInvoice invoice) {
  final lineTypes = invoice.lines.map((line) => line.lineType).toSet();
  if (lineTypes.contains('VIOLATION_FINE')) {
    return Icons.gavel_rounded;
  }
  if (lineTypes.contains('MAINTENANCE_COMPENSATION')) {
    return Icons.construction_rounded;
  }
  if (invoice.invoiceType == 'UTILITY') {
    return Icons.flash_on_outlined;
  }
  if (invoice.invoiceType == 'RENT') {
    return Icons.receipt_long_outlined;
  }
  return Icons.payments_outlined;
}
