// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/maintenance/maintenance_ticket_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/create_maintenance_ticket_screen.dart';
import 'package:hdbhms_mobile/screens/auth/login_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_detail_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';

class MaintenanceTicketListScreen extends StatefulWidget {
  const MaintenanceTicketListScreen({
    super.key,
    this.ticketService = const MaintenanceTicketService(),
  });

  final MaintenanceTicketService ticketService;

  @override
  State<MaintenanceTicketListScreen> createState() =>
      _MaintenanceTicketListScreenState();
}

class _MaintenanceTicketListScreenState
    extends State<MaintenanceTicketListScreen> {
  late Future<List<MaintenanceTicketModel>> _ticketsFuture;
  late final TextEditingController _keywordController;
  String _selectedStatus = _allOption;
  String _selectedCategory = _allOption;

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController();
    _ticketsFuture = _loadTickets();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<List<MaintenanceTicketModel>> _loadTickets() {
    return widget.ticketService.getTickets(
      keyword: _keywordController.text,
      status: _selectedStatus,
      category: _selectedCategory,
    );
  }

  bool get _hasActiveFilter =>
      _keywordController.text.trim().isNotEmpty ||
      _selectedStatus != _allOption ||
      _selectedCategory != _allOption;

  void _applyFilter() {
    setState(() {
      _ticketsFuture = _loadTickets();
    });
  }

  Future<void> _refresh() async {
    final future = _loadTickets();
    setState(() {
      _ticketsFuture = future;
    });
    await future;
  }

  Future<void> _openCreateTicket() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CreateMaintenanceTicketScreen(ticketService: widget.ticketService),
      ),
    );
    if (created == true && mounted) {
      _refresh();
    }
  }

  Future<void> _openTicketDetail(MaintenanceTicketModel ticket) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MaintenanceTicketDetailScreen(
          ticketId: ticket.id,
          ticket: ticket,
          ticketService: widget.ticketService,
        ),
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _handleLogout() async {
    await const AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: _buildHeader(),
          child: FutureBuilder<List<MaintenanceTicketModel>>(
            future: _ticketsFuture,
            builder: (context, snapshot) {
              final tickets = snapshot.data ?? const <MaintenanceTicketModel>[];

              return RefreshIndicator(
                color: AppColors.deepBlue,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 96),
                  children: [
                    _MaintenanceSectionHeader(
                      ticketCount: snapshot.hasData ? tickets.length : null,
                      onCreateTicket: _openCreateTicket,
                    ),
                    const SizedBox(height: 18),
                    _FilterPanel(
                      keywordController: _keywordController,
                      selectedStatus: _selectedStatus,
                      selectedCategory: _selectedCategory,
                      onStatusChanged: (value) {
                        setState(() {
                          _selectedStatus = value ?? _allOption;
                        });
                      },
                      onCategoryChanged: (value) {
                        setState(() {
                          _selectedCategory = value ?? _allOption;
                        });
                      },
                      onFilter: _applyFilter,
                    ),
                    const SizedBox(height: 20),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const _LoadingState()
                    else if (snapshot.hasError)
                      _ErrorState(onRetry: _applyFilter)
                    else if (tickets.isEmpty)
                      _EmptyState(
                        hasActiveFilter: _hasActiveFilter,
                        onRetry: _applyFilter,
                      )
                    else
                      _TicketTableCard(
                        tickets: tickets,
                        onTicketTap: _openTicketDetail,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.support,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onSupportTap: _refresh,
        onBillsTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const BillSelectionPage()),
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

  Widget _buildHeader() {
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
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text('Sự cố', style: AppColors.topBarTitleStyle),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const AppNotificationBell(
              color: AppColors.topBarIconColor,
              size: 24,
            ),
            tooltip: 'Thông báo',
          ),
        ],
      ),
    );
  }
}

class _MaintenanceSectionHeader extends StatelessWidget {
  const _MaintenanceSectionHeader({
    required this.ticketCount,
    required this.onCreateTicket,
  });

  final int? ticketCount;
  final VoidCallback onCreateTicket;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Danh sách sự cố', style: AppTypography.sectionTitle),
              const SizedBox(height: 7),
              _TicketCountBadge(ticketCount: ticketCount),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: onCreateTicket,
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('Báo cáo sự cố'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketCountBadge extends StatelessWidget {
  const _TicketCountBadge({required this.ticketCount});

  final int? ticketCount;

  @override
  Widget build(BuildContext context) {
    final isLoading = ticketCount == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLoading
                ? Icons.hourglass_empty_rounded
                : Icons.confirmation_number_outlined,
            color: AppColors.darkBlue,
            size: 14,
          ),
          const SizedBox(width: 5),
          if (isLoading)
            const Text(
              'Đang tải...',
              style: TextStyle(
                color: AppColors.darkBlue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 16 / 12,
              ),
            )
          else
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${ticketCount!}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const TextSpan(
                    text: ' phiếu',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              style: const TextStyle(color: AppColors.darkBlue, height: 1.2),
            ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.keywordController,
    required this.selectedStatus,
    required this.selectedCategory,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onFilter,
  });

  final TextEditingController keywordController;
  final String selectedStatus;
  final String selectedCategory;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Tìm kiếm ticket'),
        const SizedBox(height: 6),
        TextField(
          controller: keywordController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onFilter(),
          decoration: _inputDecoration(
            hintText: 'Nhập mã #SC-XXXX...',
            prefixIcon: Icons.search_rounded,
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Trạng thái'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedStatus,
          style: const TextStyle(
            color: AppColors.darkBlue,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 20 / 14,
          ),
          items: _statusOptions
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(growable: false),
          onChanged: onStatusChanged,
          decoration: _inputDecoration(),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Loại sự cố'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedCategory,
          style: const TextStyle(
            color: AppColors.darkBlue,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 20 / 14,
          ),
          items: _categoryOptions
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(growable: false),
          onChanged: onCategoryChanged,
          decoration: _inputDecoration(),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: onFilter,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Lọc',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.bodyText,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 16 / 12,
      ),
    );
  }
}

class _TicketTableCard extends StatelessWidget {
  const _TicketTableCard({required this.tickets, required this.onTicketTap});

  final List<MaintenanceTicketModel> tickets;
  final ValueChanged<MaintenanceTicketModel> onTicketTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const _TicketHeaderRow(),
          for (var i = 0; i < tickets.length; i++) ...[
            if (i > 0) const Divider(color: Color(0xFFD9D8DF), height: 1),
            _TicketRow(
              ticket: tickets[i],
              onTap: () => onTicketTap(tickets[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _TicketHeaderRow extends StatelessWidget {
  const _TicketHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 10, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 70, child: _HeaderText('Mã phiếu')),
          Expanded(flex: 2, child: _HeaderText('Loại & mô tả')),
          SizedBox(width: 74, child: _HeaderText('Ngày tạo')),
          SizedBox(width: 112, child: _HeaderText('Trạng thái')),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.bodyText,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        height: 14 / 10,
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.onTap});

  final MaintenanceTicketModel ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 10, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  ticket.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 16 / 12,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _categoryIcon(ticket.category),
                            color: AppColors.bodyText,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              ticket.category.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.bodyText,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                height: 16 / 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        ticket.description,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 18 / 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 74,
                child: Text(
                  _formatDate(ticket.createdDate),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 15 / 11,
                  ),
                ),
              ),
              SizedBox(width: 112, child: _StatusSummary(ticket: ticket)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.ticket});

  final MaintenanceTicketModel ticket;

  @override
  Widget build(BuildContext context) {
    final colors = ticket.requiresTenantPayment
        ? _billingStatusColors(ticket.billingStatus)
        : _statusColors(ticket.status);
    final secondaryText = ticket.requiresTenantPayment
        ? 'Đã hoàn tất xử lý · Cần thanh toán ${_formatCurrency(ticket.chargeAmount ?? 0)}đ'
        : ticket.billingStatusLabel.isNotEmpty &&
              ticket.status == TicketStatus.completed
        ? 'Đã hoàn tất xử lý · ${ticket.billingStatusLabel}'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(colors.icon, color: colors.foreground, size: 13),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  ticket.primaryStatusLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 14 / 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (secondaryText.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            secondaryText,
            maxLines: 3,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 12 / 9,
            ),
          ),
        ],
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.deepBlue),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilter, required this.onRetry});

  final bool hasActiveFilter;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.inbox_outlined,
      title: hasActiveFilter
          ? 'Không có phiếu sự cố phù hợp'
          : 'Chưa có phiếu sự cố',
      iconColor: AppColors.darkBlue,
      titleColor: AppColors.darkBlue,
      onRetry: onRetry,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.error_outline_rounded,
      title: 'Không tải được danh sách sự cố',
      onRetry: onRetry,
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.onRetry,
    this.iconColor = AppColors.deepBlue,
    this.titleColor = AppColors.inputText,
  });

  final IconData icon;
  final String title;
  final VoidCallback onRetry;
  final Color iconColor;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 54),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 20 / 15,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}

InputDecoration _inputDecoration({String? hintText, IconData? prefixIcon}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, color: AppColors.bodyText, size: 22),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: _fieldBorder,
    enabledBorder: _fieldBorder,
    focusedBorder: _fieldBorder.copyWith(
      borderSide: const BorderSide(color: AppColors.deepBlue),
    ),
  );
}

final OutlineInputBorder _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(8),
  borderSide: const BorderSide(color: AppColors.cardBorder),
);

IconData _categoryIcon(TicketCategory category) {
  return switch (category) {
    TicketCategory.equipment => Icons.inventory_2_outlined,
    TicketCategory.electricity => Icons.bolt_outlined,
    TicketCategory.water => Icons.water_drop_outlined,
    TicketCategory.airConditioner => Icons.ac_unit_rounded,
    TicketCategory.internet => Icons.wifi_rounded,
    TicketCategory.doorLock => Icons.lock_outline_rounded,
    TicketCategory.cleaningDrainage => Icons.cleaning_services_outlined,
    TicketCategory.other => Icons.more_horiz_rounded,
  };
}

_BadgeColors _statusColors(TicketStatus status) {
  return switch (status) {
    TicketStatus.completed => const _BadgeColors(
      background: Color(0xFFD6F7E1),
      foreground: Color(0xFF138A42),
      icon: Icons.check_circle_outline_rounded,
    ),
    TicketStatus.rejected => const _BadgeColors(
      background: Color(0xFFFFDAD7),
      foreground: Color(0xFFC8171F),
      icon: Icons.cancel_outlined,
    ),
    TicketStatus.accepted => const _BadgeColors(
      background: Color(0xFFE9E7E4),
      foreground: Color(0xFF55565E),
      icon: Icons.schedule_rounded,
    ),
    TicketStatus.pending => const _BadgeColors(
      background: Color(0xFFFFE9C7),
      foreground: Color(0xFFB45309),
      icon: Icons.hourglass_empty_rounded,
    ),
    TicketStatus.inProgress => const _BadgeColors(
      background: Color(0xFFDCEAFF),
      foreground: Color(0xFF1D4ED8),
      icon: Icons.build_circle_outlined,
    ),
    TicketStatus.waitingConfirmation => const _BadgeColors(
      background: Color(0xFFEDE3FF),
      foreground: Color(0xFF6D28D9),
      icon: Icons.rate_review_outlined,
    ),
    TicketStatus.cancelled => const _BadgeColors(
      background: Color(0xFFE7E9F0),
      foreground: Color(0xFF4B5563),
      icon: Icons.block_rounded,
    ),
  };
}

_BadgeColors _billingStatusColors(String status) {
  return switch (status.toUpperCase()) {
    'OVERDUE' => const _BadgeColors(
      background: Color(0xFFFFDAD7),
      foreground: Color(0xFFC8171F),
      icon: Icons.warning_amber_rounded,
    ),
    'PAID' => const _BadgeColors(
      background: Color(0xFFD6F7E1),
      foreground: Color(0xFF138A42),
      icon: Icons.check_circle_outline_rounded,
    ),
    _ => const _BadgeColors(
      background: Color(0xFFFFE9C7),
      foreground: Color(0xFFB45309),
      icon: Icons.payments_outlined,
    ),
  };
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatCurrency(num amount) {
  return amount.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
}

const _allOption = 'Tất cả';
const _statusOptions = [
  _allOption,
  'Chờ tiếp nhận',
  'Đã tiếp nhận',
  'Đang xử lý',
  'Chờ xác nhận',
  'Hoàn tất',
  'Từ chối',
  'Đã hủy',
];
const _categoryOptions = [
  _allOption,
  'Thiết bị trong phòng',
  'Điện',
  'Nước',
  'Điều hòa',
  'Wifi',
  'Cửa / khóa',
  'Vệ sinh / thoát nước',
  'Khác',
];
