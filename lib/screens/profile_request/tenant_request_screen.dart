import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/change_request/change_request_model.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_request_model.dart';
import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/services/change_request/change_request_service.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';
import 'package:hdbhms_mobile/screens/room_transfer/room_transfer_detail_screen.dart';

/// Màn "Yêu cầu" – danh sách yêu cầu + filter theo loại
class TenantRequestScreen extends StatefulWidget {
  const TenantRequestScreen({
    super.key,
    this.changeRequestService = const ChangeRequestService(),
  });

  final ChangeRequestService changeRequestService;

  @override
  State<TenantRequestScreen> createState() => _TenantRequestScreenState();
}

class _TenantRequestScreenState extends State<TenantRequestScreen> {
  // null = Tất cả
  TenantRequestType? _filterType;

  final List<TenantRequest> _requests = [];

  // ChangeRequest objects keyed by their id, for navigating to detail screens
  final Map<int, ChangeRequest> _changeRequestMap = {};

  bool _loadingApi = false;

  @override
  void initState() {
    super.initState();
    _loadApiRequests();
  }

  /// Fetches change requests from the backend API and converts them to
  /// [TenantRequest] objects for display in the unified list.
  Future<void> _loadApiRequests() async {
    setState(() => _loadingApi = true);
    try {
      final apiRequests = await widget.changeRequestService.getMyRequests();
      if (!mounted) return;
      setState(() {
        // Index API requests for detail navigation
        for (final cr in apiRequests) {
          _changeRequestMap[cr.id] = cr;
        }
        // Convert and prepend API requests (newest first)
        final converted = apiRequests.map(_toTenantRequest).toList();
        _requests
          ..removeWhere((r) => r.id.startsWith('API-'))
          ..insertAll(0, converted);
        _loadingApi = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingApi = false);
    }
  }

  /// Maps a [ChangeRequest] to a [TenantRequest] for display.
  TenantRequest _toTenantRequest(ChangeRequest cr) {
    return TenantRequest(
      id: 'API-${cr.id}',
      type: _mapRequestType(cr.requestType),
      status: _mapRequestStatus(cr.status),
      note: cr.description.isNotEmpty ? cr.description : cr.title,
      createdAt: cr.createdAt ?? DateTime.now(),
    );
  }

  TenantRequestType _mapRequestType(ChangeRequestType type) {
    return switch (type) {
      ChangeRequestType.roomTransfer => TenantRequestType.changeRoom,
      ChangeRequestType.moveOut => TenantRequestType.terminateContract,
      ChangeRequestType.addCoOccupant => TenantRequestType.addRoommate,
      _ => TenantRequestType.renewContract, // fallback for unmapped types
    };
  }

  TenantRequestStatus _mapRequestStatus(ChangeRequestStatus status) {
    return switch (status) {
      ChangeRequestStatus.pending || ChangeRequestStatus.underReview =>
        TenantRequestStatus.pending,
      ChangeRequestStatus.processing => TenantRequestStatus.processing,
      ChangeRequestStatus.approved || ChangeRequestStatus.completed =>
        TenantRequestStatus.approved,
      ChangeRequestStatus.rejected || ChangeRequestStatus.cancelled =>
        TenantRequestStatus.rejected,
    };
  }

  List<TenantRequest> get _filtered {
    if (_filterType == null) return _requests;
    return _requests.where((r) => r.type == _filterType).toList();
  }

  void _openDetail(TenantRequest req) {
    final apiId = req.id.startsWith('API-')
        ? int.tryParse(req.id.substring(4))
        : null;
    final changeRequest = apiId != null ? _changeRequestMap[apiId] : null;

    if (changeRequest != null) {
      if (changeRequest.requestType == ChangeRequestType.roomTransfer) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                RoomTransferDetailScreen(changeRequest: changeRequest),
          ),
        ).then((refreshed) {
          if (refreshed == true) _loadApiRequests();
        });
        return;
      }

      showDialog<void>(
        context: context,
        builder: (_) => _ApiRequestDetailDialog(changeRequest: changeRequest),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => _RequestDetailDialog(request: req),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.requests,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onBillsTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const BillSelectionPage()),
          );
        },
        onSupportTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const MaintenanceTicketListScreen(),
            ),
          );
        },
        onRequestsTap: () {},
        onProfileTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const TenantProfileScreen(),
            ),
          );
        },
      ),
      body: SafeArea(
        child: AppScreenShell(
          header: _buildHeader(),
          child: RefreshIndicator(
            color: AppColors.deepBlue,
            onRefresh: _loadApiRequests,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 96),
              children: [
                // ── Tiêu đề danh sách ─────────────────────
                Row(
                  children: [
                    _sectionTitle('Danh sách yêu cầu'),
                    const Spacer(),
                    _RequestCountBadge(count: filtered.length),
                  ],
                ),
                const SizedBox(height: 18),

                // ── Filter chips ───────────────────────────────────
                _FilterBar(
                  active: _filterType,
                  onChanged: (t) => setState(() => _filterType = t),
                ),
                const SizedBox(height: 20),

                // ── List items ────────────────────────────────────
                if (_loadingApi && _requests.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: AppColors.deepBlue,
                      ),
                    ),
                  )
                else if (filtered.isEmpty)
                  _buildEmpty()
                else
                  ...filtered.map((req) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RequestCard(
                          request: req,
                          onTap: () => _openDetail(req),
                        ),
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF1FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                color: AppColors.deepBlue,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Chưa có yêu cầu nào',
              style: TextStyle(
                color: AppColors.inputText,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 20 / 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _filterType == null
                  ? 'Bạn chưa tạo yêu cầu nào.'
                  : 'Không có yêu cầu phù hợp với bộ lọc hiện tại.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 18 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
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
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text('Yêu cầu', style: AppColors.topBarTitleStyle),
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

  Widget _sectionTitle(String text) {
    return Text(text, style: AppTypography.sectionTitle);
  }
}

class _RequestCountBadge extends StatelessWidget {
  const _RequestCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 11, 7),
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 18 / 15,
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            'yêu cầu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 15 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.active, required this.onChanged});

  final TenantRequestType? active;
  final ValueChanged<TenantRequestType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _FilterChip(
            label: 'Tất cả',
            isActive: active == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          ...TenantRequestType.values.map(
            (t) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: t.label,
                isActive: active == t,
                onTap: () => onChanged(t),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.deepBlue : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? AppColors.deepBlue
                : AppColors.cardBorder.withValues(alpha: 0.9),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.bodyText,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            height: 16 / 12,
          ),
        ),
      ),
    );
  }
}

// ── Request card ─────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final TenantRequest request;
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
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type tag
                    _TypeTag(type: request.type),
                    const SizedBox(height: 6),
                    // Title
                    Text(
                      request.type.fullLabel,
                      style: const TextStyle(
                        color: AppColors.inputText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 19 / 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Time
                    Text(
                      _formatTime(request.createdAt),
                      style: const TextStyle(
                        color: AppColors.bodyText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 15 / 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Note preview
                    Text(
                      request.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.bodyText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 16 / 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: request.status),
                  const SizedBox(height: 8),
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

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $h:$m';
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.type});

  final TenantRequestType type;

  IconData get _icon => switch (type) {
    TenantRequestType.renewContract => Icons.autorenew_rounded,
    TenantRequestType.terminateContract => Icons.cancel_outlined,
    TenantRequestType.changeRoom => Icons.swap_horiz_rounded,
    TenantRequestType.addRoommate => Icons.person_add_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon, size: 12, color: AppColors.deepBlue),
        const SizedBox(width: 4),
        Text(
          type.label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.deepBlue,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            height: 14 / 10,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TenantRequestStatus status;

  Color get _bg => switch (status) {
    TenantRequestStatus.pending => const Color(0xFFFFF7ED),
    TenantRequestStatus.processing => const Color(0xFFEFF1FF),
    TenantRequestStatus.approved => const Color(0xFFD4F8DE),
    TenantRequestStatus.rejected => const Color(0xFFFFE4E4),
  };

  Color get _fg => switch (status) {
    TenantRequestStatus.pending => const Color(0xFFD97706),
    TenantRequestStatus.processing => AppColors.deepBlue,
    TenantRequestStatus.approved => const Color(0xFF16A34A),
    TenantRequestStatus.rejected => const Color(0xFFDC2626),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 14 / 10,
        ),
      ),
    );
  }
}

// ── Request detail dialog ─────────────────────────────────────────────────────
class _RequestDetailDialog extends StatelessWidget {
  const _RequestDetailDialog({required this.request});

  final TenantRequest request;

  IconData get _icon => switch (request.type) {
    TenantRequestType.renewContract => Icons.autorenew_rounded,
    TenantRequestType.terminateContract => Icons.cancel_outlined,
    TenantRequestType.changeRoom => Icons.swap_horiz_rounded,
    TenantRequestType.addRoommate => Icons.person_add_outlined,
  };

  Color get _accentColor => switch (request.type) {
    TenantRequestType.renewContract => AppColors.deepBlue,
    TenantRequestType.terminateContract => const Color(0xFFDC2626),
    TenantRequestType.changeRoom => const Color(0xFF0284C7),
    TenantRequestType.addRoommate => const Color(0xFF16A34A),
  };

  Color get _accentBg => switch (request.type) {
    TenantRequestType.renewContract => const Color(0xFFEFF1FF),
    TenantRequestType.terminateContract => const Color(0xFFFFF0F0),
    TenantRequestType.changeRoom => const Color(0xFFEFF8FF),
    TenantRequestType.addRoommate => const Color(0xFFF0FFF4),
  };

  Color get _statusColor => switch (request.status) {
    TenantRequestStatus.pending => const Color(0xFFD97706),
    TenantRequestStatus.processing => AppColors.deepBlue,
    TenantRequestStatus.approved => const Color(0xFF16A34A),
    TenantRequestStatus.rejected => const Color(0xFFDC2626),
  };

  String get _detailTitle => switch (request.type) {
    TenantRequestType.renewContract => 'Thông tin gia hạn',
    TenantRequestType.terminateContract => 'Thông tin thanh lý',
    TenantRequestType.changeRoom => 'Thông tin chuyển phòng',
    TenantRequestType.addRoommate => 'Thông tin người ở cùng',
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _accentBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(_icon, color: _accentColor, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chi tiết yêu cầu',
                          style: TextStyle(
                            color: AppColors.deepBlue,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          request.type.fullLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.bodyText,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Divider(height: 1, color: Color(0xFFEEECEE)),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypeTag(type: request.type),
                        const Spacer(),
                        _StatusBadge(status: request.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _DetailSection(
                      title: 'Tổng quan',
                      children: [
                        _DetailRow(label: 'Mã yêu cầu', value: request.id),
                        _DetailRow(
                          label: 'Ngày tạo',
                          value: _formatTime(request.createdAt),
                        ),
                        _DetailRow(
                          label: 'Trạng thái',
                          value: request.status.label,
                          valueColor: _statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DetailSection(
                      title: _detailTitle,
                      children: _buildTypeDetails(),
                    ),
                    const SizedBox(height: 12),
                    _DetailSection(
                      title: 'Nội dung / ghi chú',
                      children: [
                        Text(
                          request.note,
                          style: const TextStyle(
                            color: AppColors.inputText,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 20 / 13.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $h:$m';
  }

  List<Widget> _buildTypeDetails() {
    final d = request.details;

    return switch (request.type) {
      TenantRequestType.renewContract => [
        _DetailRow(
          label: 'Mã hợp đồng',
          value: d['Mã hợp đồng'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Thời gian gia hạn',
          value: d['Thời gian gia hạn'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Ngày bắt đầu dự kiến',
          value: d['Ngày bắt đầu dự kiến'] ?? 'Chưa có thông tin',
        ),
      ],
      TenantRequestType.terminateContract => [
        _DetailRow(
          label: 'Mã hợp đồng',
          value: d['Mã hợp đồng'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Ngày hết hạn',
          value: d['Ngày hết hạn'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Ngày trả phòng dự kiến',
          value: d['Ngày trả phòng dự kiến'] ?? 'Chưa có thông tin',
          valueColor: const Color(0xFFDC2626),
        ),
      ],
      TenantRequestType.changeRoom => [
        _DetailRow(
          label: 'Phòng hiện tại',
          value: d['Phòng hiện tại'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Phòng mong muốn',
          value: d['Phòng mong muốn'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Tầng/khu vực',
          value: d['Tầng/khu vực'] ?? 'Chưa có thông tin',
        ),
      ],
      TenantRequestType.addRoommate => [
        _DetailRow(
          label: 'Họ và tên',
          value: d['Họ và tên'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(
          label: 'Số điện thoại',
          value: d['Số điện thoại'] ?? 'Chưa có thông tin',
        ),
        _DetailRow(label: 'Email', value: d['Email'] ?? 'Chưa có thông tin'),
        _DetailRow(
          label: 'Ngày bắt đầu ở',
          value: d['Ngày bắt đầu ở'] ?? 'Chưa có thông tin',
        ),
      ],
    };
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 17 / 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? AppColors.inputText,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 18 / 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── API Request detail dialog ─────────────────────────────────────────────────────
class _ApiRequestDetailDialog extends StatefulWidget {
  const _ApiRequestDetailDialog({required this.changeRequest});

  final ChangeRequest changeRequest;

  @override
  State<_ApiRequestDetailDialog> createState() => _ApiRequestDetailDialogState();
}

class _ApiRequestDetailDialogState extends State<_ApiRequestDetailDialog> {
  RoomTransferRequest? _roomTransferRequest;
  bool _loadingTransfer = false;

  @override
  void initState() {
    super.initState();
    if (widget.changeRequest.requestType == ChangeRequestType.roomTransfer) {
      _loadRoomTransferData();
    }
  }

  Future<void> _loadRoomTransferData() async {
    final p = widget.changeRequest.requestPayload;
    if (p == null) return;

    try {
      final payload = jsonDecode(p) as Map<String, dynamic>;
      final transferCode = payload['transferRequestCode'] as String?;
      if (transferCode != null && transferCode.isNotEmpty) {
        setState(() => _loadingTransfer = true);
        final service = const RoomTransferService();
        final transfer = await service.getTransferRequestByCode(transferCode);
        if (mounted) {
          setState(() {
            _roomTransferRequest = transfer;
            _loadingTransfer = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingTransfer = false);
      }
    }
  }

  IconData get _icon => switch (widget.changeRequest.requestType) {
    ChangeRequestType.roomTransfer => Icons.swap_horiz_rounded,
    ChangeRequestType.moveOut => Icons.cancel_outlined,
    ChangeRequestType.depositRefundRequest => Icons.account_balance_wallet_outlined,
    ChangeRequestType.addCoOccupant => Icons.person_add_outlined,
    ChangeRequestType.complaint => Icons.report_problem_outlined,
    ChangeRequestType.meterReadingCorrection => Icons.speed_outlined,
    ChangeRequestType.invoiceAdjustment => Icons.receipt_long_outlined,
    ChangeRequestType.rentPriceAdjustment => Icons.attach_money_outlined,
  };

  Color get _accentColor => switch (widget.changeRequest.requestType) {
    ChangeRequestType.roomTransfer => const Color(0xFF0284C7),
    ChangeRequestType.moveOut => const Color(0xFFDC2626),
    ChangeRequestType.depositRefundRequest => const Color(0xFF16A34A),
    ChangeRequestType.addCoOccupant => const Color(0xFF16A34A),
    ChangeRequestType.complaint => const Color(0xFFEA580C),
    ChangeRequestType.meterReadingCorrection => AppColors.deepBlue,
    ChangeRequestType.invoiceAdjustment => const Color(0xFF7C3AED),
    ChangeRequestType.rentPriceAdjustment => const Color(0xFF0891B2),
  };

  Color get _accentBg => switch (widget.changeRequest.requestType) {
    ChangeRequestType.roomTransfer => const Color(0xFFEFF8FF),
    ChangeRequestType.moveOut => const Color(0xFFFFF0F0),
    ChangeRequestType.depositRefundRequest => const Color(0xFFF0FFF4),
    ChangeRequestType.addCoOccupant => const Color(0xFFF0FFF4),
    ChangeRequestType.complaint => const Color(0xFFFFF7ED),
    ChangeRequestType.meterReadingCorrection => const Color(0xFFEFF1FF),
    ChangeRequestType.invoiceAdjustment => const Color(0xFFF3E8FF),
    ChangeRequestType.rentPriceAdjustment => const Color(0xFFE0F2FE),
  };

  Color get _statusColor => switch (widget.changeRequest.status) {
    ChangeRequestStatus.pending => const Color(0xFFD97706),
    ChangeRequestStatus.underReview => const Color(0xFF0284C7),
    ChangeRequestStatus.approved => const Color(0xFF16A34A),
    ChangeRequestStatus.rejected => const Color(0xFFDC2626),
    ChangeRequestStatus.processing => AppColors.deepBlue,
    ChangeRequestStatus.completed => const Color(0xFF16A34A),
    ChangeRequestStatus.cancelled => const Color(0xFF9CA3AF),
  };

  Map<String, dynamic> get _payload {
    if (widget.changeRequest.requestPayload == null) return {};
    try {
      return jsonDecode(widget.changeRequest.requestPayload!) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 48),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _accentBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(_icon, color: _accentColor, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chi tiết yêu cầu',
                          style: TextStyle(
                            color: AppColors.deepBlue,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.changeRequest.requestType.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.bodyText,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Divider(height: 1, color: Color(0xFFEEECEE)),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailSection(
                      title: 'Tổng quan',
                      children: [
                        _DetailRow(label: 'Mã yêu cầu', value: widget.changeRequest.requestCode),
                        _DetailRow(
                          label: 'Ngày tạo',
                          value: _formatTime(widget.changeRequest.createdAt),
                        ),
                        _DetailRow(
                          label: 'Trạng thái',
                          value: widget.changeRequest.status.label,
                          valueColor: _statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingTransfer)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: AppColors.deepBlue),
                        ),
                      )
                    else
                      _DetailSection(
                        title: 'Chi tiết',
                        children: _buildTypeDetails(),
                      ),
                    if (widget.changeRequest.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailSection(
                        title: 'Nội dung / ghi chú',
                        children: [
                          Text(
                            widget.changeRequest.description,
                            style: const TextStyle(
                              color: AppColors.inputText,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              height: 20 / 13.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.changeRequest.resolutionNote != null && widget.changeRequest.resolutionNote!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailSection(
                        title: 'Ghi chú giải quyết',
                        children: [
                          Text(
                            widget.changeRequest.resolutionNote!,
                            style: const TextStyle(
                              color: AppColors.inputText,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              height: 20 / 13.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Chưa có thông tin';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $h:$m';
  }

  List<Widget> _buildTypeDetails() {
    // If room transfer data is available, use it
    if (widget.changeRequest.requestType == ChangeRequestType.roomTransfer && _roomTransferRequest != null) {
      final tr = _roomTransferRequest!;
      return [
        _DetailRow(label: 'Phòng hiện tại', value: tr.oldRoomName ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Phòng đích', value: tr.targetRoomName ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Ngày chuyển dự kiến', value: _formatDate(tr.requestedTransferDate)),
        if (tr.reason != null && tr.reason!.isNotEmpty)
          _DetailRow(label: 'Lý do', value: tr.reason!),
      ];
    }

    // Fallback to payload
    final p = _payload;

    return switch (widget.changeRequest.requestType) {
      ChangeRequestType.roomTransfer => [
        _DetailRow(label: 'Phòng hiện tại', value: p['currentRoom']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Phòng đích', value: p['targetRoom']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Ngày chuyển dự kiến', value: p['requestedTransferDate']?.toString() ?? 'Chưa có thông tin'),
      ],
      ChangeRequestType.moveOut => [
        _DetailRow(label: 'Phòng', value: p['room']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Ngày trả phòng dự kiến', value: p['requestedMoveOutDate']?.toString() ?? 'Chưa có thông tin'),
      ],
      ChangeRequestType.depositRefundRequest => [
        _DetailRow(label: 'Phòng', value: p['room']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Số tiền cọc', value: p['depositAmount']?.toString() ?? 'Chưa có thông tin'),
      ],
      ChangeRequestType.addCoOccupant => [
        _DetailRow(label: 'Họ tên', value: p['fullName']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Số điện thoại', value: p['phoneNumber']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Ngày bắt đầu ở', value: p['moveInDate']?.toString() ?? 'Chưa có thông tin'),
      ],
      ChangeRequestType.complaint => [
        _DetailRow(label: 'Danh mục', value: p['category']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Mức độ ưu tiên', value: p['priority']?.toString() ?? 'Chưa có thông tin'),
      ],
      ChangeRequestType.meterReadingCorrection => [
        _DetailRow(label: 'Loại đồng hồ', value: p['meterType']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Số cũ', value: p['oldValue']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Số mới', value: p['newValue']?.toString() ?? 'Chưa có thông tin'),
      ],
      ChangeRequestType.invoiceAdjustment => [
        _DetailRow(label: 'Mã hóa đơn', value: p['invoiceCode']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Số tiền điều chỉnh', value: p['adjustmentAmount']?.toString() ?? 'Chưa có thông tin'),
      ],
      ChangeRequestType.rentPriceAdjustment => [
        _DetailRow(label: 'Phòng', value: p['room']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Giá cũ', value: p['oldPrice']?.toString() ?? 'Chưa có thông tin'),
        _DetailRow(label: 'Giá mới', value: p['newPrice']?.toString() ?? 'Chưa có thông tin'),
      ],
    };
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Chưa có thông tin';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
