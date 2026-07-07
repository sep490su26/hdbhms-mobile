import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/models/contract/contract_list_item_model.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/screens/contract/lease_contract_screen.dart';
import 'package:hdbhms_mobile/screens/auth/login_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';

class LeaseContractListScreen extends StatefulWidget {
  const LeaseContractListScreen({
    super.key,
    this.contractService = const LeaseContractService(),
    this.embeddedMode = false,
  });

  final LeaseContractService contractService;

  /// Khi true: không hiển thị header riêng, không có bottom bar (dùng trong ContractHubScreen).
  final bool embeddedMode;

  @override
  State<LeaseContractListScreen> createState() =>
      _LeaseContractListScreenState();
}

class _LeaseContractListScreenState extends State<LeaseContractListScreen> {
  late Future<List<ContractListItem>> _listFuture;

  // Filter state
  String? _selectedStatus;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _listFuture = _fetch();
  }

  Future<List<ContractListItem>> _fetch() {
    return widget.contractService.getMyContracts(
      status: _selectedStatus,
      signedFrom: _selectedDateRange?.start,
      signedTo: _selectedDateRange?.end,
    );
  }

  void _retry() {
    setState(() {
      _listFuture = _fetch();
    });
  }

  Future<void> _refresh() async {
    final future = _fetch();
    setState(() {
      _listFuture = future;
    });
    await future;
  }

  void _onFiltersChanged() {
    setState(() {
      _listFuture = _fetch();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedDateRange = null;
      _listFuture = _fetch();
    });
  }

  bool get _hasActiveFilters =>
      _selectedStatus != null || _selectedDateRange != null;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      _selectedDateRange = picked;
      _onFiltersChanged();
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

  Widget _buildListContent() {
    return Column(
      children: [
        _FilterBar(
          selectedStatus: _selectedStatus,
          selectedDateRange: _selectedDateRange,
          hasActiveFilters: _hasActiveFilters,
          onStatusChanged: (v) {
            _selectedStatus = v;
            _onFiltersChanged();
          },
          onPickDateRange: _pickDateRange,
          onClearFilters: _clearFilters,
          statusOptions: _leaseStatusOptions,
        ),
        Expanded(
          child: FutureBuilder<List<ContractListItem>>(
            future: _listFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.deepBlue),
                );
              }

              if (snapshot.hasError) {
                return _ErrorState(
                  message: _errorMessage(snapshot.error),
                  onRetry: _retry,
                );
              }

              final list = snapshot.data;
              if (list == null || list.isEmpty) {
                return _EmptyState(onRetry: _retry);
              }

              final filtered = list;

              if (filtered.isEmpty) {
                return _EmptyFilterState(onClear: _clearFilters);
              }

              return RefreshIndicator(
                color: AppColors.deepBlue,
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _ContractCard(
                      item: filtered[index],
                      onTap: () => _openDetail(filtered[index]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embeddedMode) {
      // Chế độ nhúng: chỉ render nội dung, không có Scaffold
      return _buildListContent();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: _buildHeader(),
          child: _buildListContent(),
        ),
      ),
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.profile,
        onBillsTap: () {},
        onHomeTap: () => Navigator.of(context).pop(),
        onSupportTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MaintenanceTicketListScreen(),
            ),
          );
        },
        onProfileTap: () {
          Navigator.of(context).pushReplacement(
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
            child: Text(
              'Danh sách hợp đồng thuê',
              style: AppColors.topBarTitleStyle,
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(ContractListItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LeaseContractScreen(contractId: item.id),
      ),
    );
  }

  String _errorMessage(Object? error) {
    if (error is LeaseContractException) return error.message;
    return 'Không tải được danh sách hợp đồng';
  }
}

// ── Filter Bar ──

const _leaseStatusOptions = <String, String>{
  'ACTIVE': 'Đang hiệu lực',
  'EXPIRING_SOON': 'Sắp hết hạn',
  'EXPIRED': 'Đã hết hạn',
  'TERMINATED': 'Đã chấm dứt',
  'DRAFT': 'Bản nháp',
  'PENDING_SIGNATURE': 'Chờ ký',
};

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedStatus,
    required this.selectedDateRange,
    required this.hasActiveFilters,
    required this.onStatusChanged,
    required this.onPickDateRange,
    required this.onClearFilters,
    required this.statusOptions,
  });

  final String? selectedStatus;
  final DateTimeRange? selectedDateRange;
  final bool hasActiveFilters;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearFilters;
  final Map<String, String> statusOptions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterChip(
              icon: Icons.calendar_month_outlined,
              label: selectedDateRange != null
                  ? '${_fmtShort(selectedDateRange!.start)} - ${_fmtShort(selectedDateRange!.end)}'
                  : 'Ngày ký HĐ',
              isActive: selectedDateRange != null,
              onTap: onPickDateRange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatusDropdown(
              selectedStatus: selectedStatus,
              statusOptions: statusOptions,
              onChanged: onStatusChanged,
            ),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClearFilters,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD8D5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFB00020),
                  size: 18,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEFF1FF) : const Color(0xFFF5F4F8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.deepBlue.withValues(alpha: 0.5)
                : AppColors.cardBorder.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.deepBlue : AppColors.bodyText,
              size: 15,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? AppColors.deepBlue : AppColors.bodyText,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
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

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.selectedStatus,
    required this.statusOptions,
    required this.onChanged,
  });

  final String? selectedStatus;
  final Map<String, String> statusOptions;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isActive = selectedStatus != null;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFEFF1FF) : const Color(0xFFF5F4F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? AppColors.deepBlue.withValues(alpha: 0.5)
              : AppColors.cardBorder.withValues(alpha: 0.6),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedStatus,
          isExpanded: true,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isActive ? AppColors.deepBlue : AppColors.bodyText,
            size: 18,
          ),
          hint: Row(
            children: [
              Icon(
                Icons.filter_list_rounded,
                color: AppColors.bodyText,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                'Trạng thái',
                style: TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 14 / 11,
                ),
              ),
            ],
          ),
          selectedItemBuilder: (context) {
            return [
              for (final entry in statusOptions.entries)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 14 / 11,
                    ),
                  ),
                ),
            ];
          },
          items: statusOptions.entries.map((entry) {
            return DropdownMenuItem<String?>(
              value: entry.key,
              child: Text(
                entry.value,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Cards ──

class _ContractCard extends StatelessWidget {
  const _ContractCard({required this.item, required this.onTap});

  final ContractListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF1FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.deepBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.contractCode.isEmpty
                          ? 'Hợp đồng #${item.id}'
                          : item.contractCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inputText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 18 / 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: _InfoChip(
                            icon: Icons.meeting_room_outlined,
                            text: item.roomCode.isEmpty ? '--' : item.roomCode,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: _InfoChip(
                            icon: Icons.calendar_today_outlined,
                            text: item.signedAt != null
                                ? _formatDate(item.signedAt!)
                                : '--',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: item.status),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.bodyText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.bodyText, size: 13),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 16 / 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bgColor, textColor) = _statusStyle(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 13 / 10,
        ),
      ),
    );
  }
}

// ── State widgets ──

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.deepBlue,
      onRefresh: () async => onRetry(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          const Icon(
            Icons.description_outlined,
            color: AppColors.deepBlue,
            size: 46,
          ),
          const SizedBox(height: 14),
          const Text(
            'Bạn chưa có hợp đồng thuê nào',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inputText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 20 / 15,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.filter_list_off_rounded,
              color: AppColors.deepBlue,
              size: 42,
            ),
            const SizedBox(height: 14),
            const Text(
              'Không có hợp đồng phù hợp với bộ lọc',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inputText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Xóa bộ lọc'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.deepBlue,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.inputText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _fmtShort(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

(String, Color, Color) _statusStyle(String status) {
  return switch (status.trim().toUpperCase()) {
    'ACTIVE' => (
      'Đang hiệu lực',
      const Color(0xFFD4F8DE),
      const Color(0xFF159447),
    ),
    'EXPIRING_SOON' => (
      'Sắp hết hạn',
      const Color(0xFFFFF3CD),
      const Color(0xFF856404),
    ),
    'EXPIRED' => (
      'Đã hết hạn',
      const Color(0xFFFFD8D5),
      const Color(0xFFB00020),
    ),
    'TERMINATED' => (
      'Đã chấm dứt',
      const Color(0xFFE7E9F0),
      AppColors.bodyText,
    ),
    'DRAFT' => ('Bản nháp', const Color(0xFFE7E9F0), AppColors.bodyText),
    'PENDING_SIGNATURE' => (
      'Chờ ký',
      const Color(0xFFFFF3CD),
      const Color(0xFF856404),
    ),
    _ => (_displayStatus(status), const Color(0xFFE7E9F0), AppColors.bodyText),
  };
}

String _displayStatus(String status) {
  final trimmed = status.trim();
  if (trimmed.isEmpty) return 'Chưa cập nhật';
  return trimmed.replaceAll('_', ' ');
}
