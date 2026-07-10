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
                      _EmptyState(onRetry: _applyFilter)
                    else
                      _TicketListCard(
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
            icon: const Icon(
              Icons.notifications_none_rounded,
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
              const SizedBox(height: 3),
              Text(
                ticketCount == null ? 'Đang tải...' : '$ticketCount phiếu',
                style: const TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 16 / 12,
                ),
              ),
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
          items: _statusOptions
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(growable: false),
          onChanged: onStatusChanged,
          decoration: _inputDecoration(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Loại sự cố'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedCategory,
          items: _categoryOptions
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(growable: false),
          onChanged: onCategoryChanged,
          decoration: _inputDecoration(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
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
                borderRadius: BorderRadius.circular(14),
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

class _TicketListCard extends StatelessWidget {
  const _TicketListCard({required this.tickets, required this.onTicketTap});

  final List<MaintenanceTicketModel> tickets;
  final ValueChanged<MaintenanceTicketModel> onTicketTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < tickets.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _TicketCard(
            ticket: tickets[index],
            onTap: () => onTicketTap(tickets[index]),
          ),
        ],
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final MaintenanceTicketModel ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final roomText = ticket.roomCode.trim().isEmpty
        ? 'Chưa có phòng'
        : 'Phòng ${ticket.roomCode.trim()}';

    return Semantics(
      button: true,
      label: 'Mở chi tiết phiếu ${ticket.code}',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
                  color: AppColors.deepBlue.withValues(alpha: 0.055),
                  blurRadius: 22,
                  offset: const Offset(0, 11),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primaryLight, Color(0xFFE5FAF6)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _categoryIcon(ticket.category),
                          color: AppColors.deepBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    ticket.code,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.deepBlue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      height: 17 / 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StatusBadge(status: ticket.status),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              ticket.category.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.bodyText,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: 16 / 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ticket.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.inputText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 20 / 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.meeting_room_outlined,
                        color: AppColors.bodyText,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          roomText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 16 / 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.bodyText,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(ticket.createdDate),
                        style: const TextStyle(
                          color: AppColors.bodyText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 16 / 12,
                        ),
                      ),
                    ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(status);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
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
                status.label,
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
  const _EmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.inbox_outlined,
      title: 'Không có phiếu sự cố phù hợp',
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
  });

  final IconData icon;
  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.deepBlue, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.inputText,
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

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
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
