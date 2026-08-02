import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/services/home/current_room_service.dart';
import 'package:hdbhms_mobile/services/maintenance/maintenance_ticket_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/utils/room_scope.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
import 'package:hdbhms_mobile/widgets/app_list_state.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/create_maintenance_ticket_screen.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_detail_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';

class MaintenanceTicketListScreen extends StatefulWidget {
  const MaintenanceTicketListScreen({
    super.key,
    this.ticketService = const MaintenanceTicketService(),
    this.currentRoomService = const CurrentRoomService(),
    this.roomId,
    this.roomCode = '',
    this.notificationInitialUnreadCount,
  });

  final MaintenanceTicketService ticketService;
  final CurrentRoomService currentRoomService;
  final int? roomId;
  final String roomCode;
  final int? notificationInitialUnreadCount;

  @override
  State<MaintenanceTicketListScreen> createState() =>
      _MaintenanceTicketListScreenState();
}

class _MaintenanceTicketListScreenState
    extends State<MaintenanceTicketListScreen> {
  late Future<List<MaintenanceTicketModel>> _ticketsFuture;
  late final TextEditingController _keywordController;
  RoomScope _roomScope = const RoomScope();
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

  Future<List<MaintenanceTicketModel>> _loadTickets() async {
    _roomScope = await resolveRoomScope(
      roomId: widget.roomId,
      roomCode: widget.roomCode,
      currentRoomService: widget.currentRoomService,
    );
    if (!_roomScope.hasRoom) return const [];
    return widget.ticketService.getTickets(
      keyword: _keywordController.text,
      status: _selectedStatus,
      category: _selectedCategory,
      roomId: _roomScope.roomId,
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
        builder: (context) => CreateMaintenanceTicketScreen(
          ticketService: widget.ticketService,
          currentRoomService: widget.currentRoomService,
          roomId: _activeRoomId,
          roomCode: _activeRoomCode,
          notificationInitialUnreadCount: widget.notificationInitialUnreadCount,
        ),
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
          notificationInitialUnreadCount: widget.notificationInitialUnreadCount,
        ),
      ),
    );
    if (mounted) {
      _refresh();
    }
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
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                            onCreateTicket: _openCreateTicket,
                          )
                        else
                          _TicketTableCard(
                            tickets: tickets,
                            onTicketTap: _openTicketDetail,
                          ),
                      ],
                    ),
                  ),
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
            MaterialPageRoute(
              builder: (context) => BillSelectionPage(
                roomId: _activeRoomId,
                roomCode: _activeRoomCode,
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
              roomId: _activeRoomId,
              roomCode: _activeRoomCode,
            ),
          ),
        ),
      ),
    );
  }

  int? get _activeRoomId => _roomScope.roomId ?? widget.roomId;

  String get _activeRoomCode =>
      _roomScope.roomCode.isNotEmpty ? _roomScope.roomCode : widget.roomCode;

  Widget _buildHeader() {
    return AppTopBar(
      title: 'Báo cáo sự cố',
      pageIcon: Icons.build_circle_outlined,
      trailing: IconButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const NotificationListScreen(),
          ),
        ),
        icon: AppNotificationBell(
          initialUnreadCount: widget.notificationInitialUnreadCount,
        ),
        tooltip: 'Thông báo',
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
        AppPrimaryGradientButton(
          onPressed: onCreateTicket,
          height: 44,
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 19, color: Colors.white),
              SizedBox(width: 7),
              Text(
                'Tạo phiếu sự cố',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ],
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
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Wrap(
        spacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            isLoading
                ? Icons.hourglass_empty_rounded
                : Icons.confirmation_number_outlined,
            color: AppColors.darkBlue,
            size: 14,
          ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Tìm kiếm ticket'),
          const SizedBox(height: 6),
          TextField(
            controller: keywordController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onFilter(),
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 18 / 13,
            ),
            decoration: _inputDecoration(
              hintText: 'Nhập mã phiếu, tiêu đề hoặc mô tả',
              prefixIcon: Icons.search_rounded,
            ),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Trạng thái'),
          const SizedBox(height: 6),
          _TicketFilterPicker(
            key: const ValueKey('ticket-status-filter'),
            label: 'Trạng thái',
            value: selectedStatus,
            options: _statusOptions,
            icon: Icons.flag_outlined,
            onChanged: onStatusChanged,
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Loại sự cố'),
          const SizedBox(height: 6),
          _TicketFilterPicker(
            key: const ValueKey('ticket-category-filter'),
            label: 'Loại sự cố',
            value: selectedCategory,
            options: _categoryOptions,
            icon: Icons.category_outlined,
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryGradientButton(
              onPressed: onFilter,
              child: const Text(
                'Lọc',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketFilterPicker extends StatelessWidget {
  const _TicketFilterPicker({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  Future<void> _selectOption(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _TicketFilterSheet(
        title: label,
        options: options,
        activeOption: value,
      ),
    );

    if (selected != null && selected != value) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = value != _allOption;
    final selectedIcon = _ticketFilterOptionIcon(label, value) ?? icon;
    return Semantics(
      button: true,
      label: '$label: $value',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: InkWell(
          onTap: () => _selectOption(context),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Ink(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: hasSelection ? AppColors.primaryLight : AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(
                color: hasSelection
                    ? AppColors.primary.withValues(alpha: 0.38)
                    : AppColors.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selectedIcon,
                  size: 19,
                  color: hasSelection ? AppColors.deepBlue : AppColors.bodyText,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
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
    );
  }
}

class _TicketFilterSheet extends StatelessWidget {
  const _TicketFilterSheet({
    required this.title,
    required this.options,
    required this.activeOption,
  });

  final String title;
  final List<String> options;
  final String activeOption;
  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    final preferredHeight = 128.0 + (options.length * 48.0);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: preferredHeight > maxHeight ? maxHeight : preferredHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.deepBlue,
                        borderRadius: BorderRadius.circular(
                          AppColors.radiusPill,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Chọn $title',
                    style: const TextStyle(
                      color: AppColors.inputText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Chạm vào một lựa chọn để áp dụng cho bộ lọc.',
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
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return _TicketFilterOption(
                    label: option,
                    icon:
                        _ticketFilterOptionIcon(title, option) ??
                        Icons.tune_rounded,
                    isSelected: option == activeOption,
                    onTap: () => Navigator.of(context).pop(option),
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

class _TicketFilterOption extends StatelessWidget {
  const _TicketFilterOption({
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
    return Column(
      children: [
        for (final ticket in tickets) ...[
          _TicketRow(ticket: ticket, onTap: () => onTicketTap(ticket)),
          if (ticket != tickets.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ignore: unused_element
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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.85),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
                        Text(
                          ticket.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.deepBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            height: 15 / 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ticket.category.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.inputText,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 18 / 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 106, child: _StatusSummary(ticket: ticket)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 18 / 13,
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.bodyText,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(ticket.createdDate),
                    style: const TextStyle(
                      color: AppColors.bodyText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 15 / 11,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.bodyText,
                    size: 20,
                  ),
                ],
              ),
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
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
  const _EmptyState({
    required this.hasActiveFilter,
    required this.onRetry,
    required this.onCreateTicket,
  });

  final bool hasActiveFilter;
  final VoidCallback onRetry;
  final VoidCallback onCreateTicket;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const _NoMaintenanceTicketsIllustration(),
          const SizedBox(height: 18),
          Text(
            hasActiveFilter
                ? 'Không có phiếu sự cố phù hợp'
                : 'Chưa có phiếu sự cố',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 22 / 16,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasActiveFilter
                ? 'Thử thay đổi từ khóa, trạng thái hoặc danh mục để xem các phiếu khác.'
                : 'Khi bạn gửi yêu cầu sửa chữa, phiếu sự cố sẽ hiển thị tại đây.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 19 / 13,
            ),
          ),
          const SizedBox(height: 18),
          if (hasActiveFilter)
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tải lại'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepBlue,
                minimumSize: const Size(0, 44),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          else
            AppPrimaryGradientButton(
              onPressed: onCreateTicket,
              height: 44,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 7),
                  Text('Tạo phiếu sự cố'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoMaintenanceTicketsIllustration extends StatelessWidget {
  const _NoMaintenanceTicketsIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 172,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 164,
            height: 164,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE8EAFC),
            ),
          ),
          Positioned(
            top: 0,
            right: 18,
            child: const _IllustrationOrb(size: 48),
          ),
          Positioned(
            bottom: 2,
            left: 6,
            child: const _IllustrationOrb(size: 34),
          ),
          Container(
            width: 202,
            height: 142,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12101F3A),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.deepBlue, width: 3),
                  ),
                  child: const Icon(
                    Icons.build_rounded,
                    color: AppColors.deepBlue,
                    size: 29,
                  ),
                ),
                const SizedBox(height: 15),
                const _IllustrationLine(width: 70),
                const SizedBox(height: 7),
                const _IllustrationLine(width: 102),
                const SizedBox(height: 7),
                const _IllustrationLine(width: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IllustrationOrb extends StatelessWidget {
  const _IllustrationOrb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFE0E3F5),
    ),
  );
}

class _IllustrationLine extends StatelessWidget {
  const _IllustrationLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 6,
    decoration: BoxDecoration(
      color: AppColors.cardBorder,
      borderRadius: BorderRadius.circular(AppColors.radiusPill),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      title: 'Không tải được danh sách sự cố',
      onRetry: onRetry,
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppListState(
    kind: AppListStateKind.error,
    title: title,
    description: 'Kiểm tra kết nối mạng rồi thử tải lại danh sách.',
    actionLabel: 'Thử lại',
    onAction: onRetry,
  );
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
    hintStyle: const TextStyle(
      color: AppColors.bodyText,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
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
  borderRadius: BorderRadius.circular(AppColors.radiusSm),
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

IconData? _ticketFilterOptionIcon(String filterLabel, String option) {
  if (filterLabel == 'Trạng thái') {
    return switch (option) {
      _allOption => Icons.list_rounded,
      'Chờ tiếp nhận' => Icons.hourglass_empty_rounded,
      'Đã tiếp nhận' => Icons.inbox_rounded,
      'Đang xử lý' => Icons.build_circle_outlined,
      'Chờ xác nhận' => Icons.rate_review_outlined,
      'Hoàn tất' => Icons.check_circle_outline_rounded,
      'Từ chối' => Icons.cancel_outlined,
      'Đã hủy' => Icons.block_rounded,
      _ => null,
    };
  }

  if (filterLabel == 'Loại sự cố') {
    return switch (option) {
      _allOption => Icons.category_outlined,
      'Thiết bị trong phòng' => Icons.inventory_2_outlined,
      'Điện' => Icons.bolt_outlined,
      'Nước' => Icons.water_drop_outlined,
      'Điều hòa' => Icons.ac_unit_rounded,
      'Wifi' => Icons.wifi_rounded,
      'Cửa / khóa' => Icons.lock_outline_rounded,
      'Vệ sinh / thoát nước' => Icons.cleaning_services_outlined,
      'Khác' => Icons.more_horiz_rounded,
      _ => null,
    };
  }

  return null;
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
