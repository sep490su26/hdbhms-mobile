// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';

import '../../models/notification/notification_model.dart';
import '../../services/notification/notification_service.dart';
import '../../utils/display_formatters.dart';
import '../../widgets/app_screen_shell.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/app_list_state.dart';
import '../../widgets/app_top_bar.dart';

/// Màn danh sách thông báo với filter Tất cả / Chưa đọc / Đã đọc.
class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({
    super.key,
    this.notificationService = const NotificationService(),
  });

  final NotificationService notificationService;

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  late final NotificationService _notificationService;
  _NotifFilter _activeFilter = _NotifFilter.all;

  List<NotificationItem> _items = [];
  bool _isLoading = true;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _didChangeReadState = false;
  String _nextCursor = '0';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _notificationService = widget.notificationService;
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _items = [];
      _hasMore = true;
      _nextCursor = '0';
    });

    try {
      final response = await _notificationService.getNotifications(
        limit: 20,
        after: 0,
      );
      setState(() {
        _items = _sortNewestFirst(response.items);
        _hasMore = response.hasMore;
        _nextCursor = response.items.isNotEmpty ? response.items.last.id : '0';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _items = [];
        _hasMore = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _notificationService.getNotifications(
        limit: 20,
        after: int.tryParse(_nextCursor) ?? 0,
      );
      setState(() {
        _items = _sortNewestFirst([..._items, ...response.items]);
        _hasMore = response.hasMore;
        if (response.items.isNotEmpty) {
          _nextCursor = response.items.last.id;
        }
      });
    } catch (_) {
      // Ignore errors on load more
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  List<NotificationItem> get _filtered {
    return switch (_activeFilter) {
      _NotifFilter.all => _items,
      _NotifFilter.unread => _items.where((n) => !n.isRead).toList(),
      _NotifFilter.read => _items.where((n) => n.isRead).toList(),
    };
  }

  List<NotificationItem> _sortNewestFirst(
    Iterable<NotificationItem> notifications,
  ) {
    final sorted = notifications.toList();
    sorted.sort((a, b) {
      final byCreatedAt = b.createdAt.compareTo(a.createdAt);
      if (byCreatedAt != 0) return byCreatedAt;

      final aId = int.tryParse(a.id);
      final bId = int.tryParse(b.id);
      if (aId != null && bId != null) return bId.compareTo(aId);
      return b.id.compareTo(a.id);
    });
    return sorted;
  }

  int get _unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> _markAllRead() async {
    final hadUnread = _items.any((item) => !item.isRead);
    if (!hadUnread) return;

    final previousItems = List<NotificationItem>.from(_items);
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(isRead: true);
      }
    });

    try {
      await _notificationService.markAllAsRead();
      _didChangeReadState = true;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = previousItems;
      });
      _showReadError();
    }
  }

  Future<void> _markRead(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx == -1 || _items[idx].isRead) return;

    final previousItem = _items[idx];
    setState(() {
      _items[idx] = previousItem.copyWith(isRead: true);
    });

    try {
      await _notificationService.markAsRead(id);
      _didChangeReadState = true;
    } catch (_) {
      if (!mounted) return;
      final rollbackIdx = _items.indexWhere((n) => n.id == id);
      if (rollbackIdx != -1) {
        setState(() {
          _items[rollbackIdx] = previousItem;
        });
      }
      _showReadError();
    }
  }

  void _showReadError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không thể cập nhật trạng thái đã đọc.')),
    );
  }

  void _closeScreen() {
    Navigator.of(context).pop(_didChangeReadState);
  }

  void _openDetail(NotificationItem item) {
    final detailItem = item.isRead ? item : item.copyWith(isRead: true);
    if (!item.isRead) {
      unawaited(_markRead(item.id));
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => _NotificationDetailDialog(item: detailItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: _buildHeader(),
          child: Column(
            children: [
              _FilterBar(
                active: _activeFilter,
                unreadCount: _unreadCount,
                onChanged: (f) => setState(() => _activeFilter = f),
              ),
              Expanded(
                child: _isLoading
                    ? const _NotificationLoadingState()
                    : _errorMessage != null && _items.isEmpty
                    ? _ErrorState(
                        message: _errorMessage!,
                        onRetry: _fetchNotifications,
                      )
                    : filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: AppColors.deepBlue,
                        onRefresh: _fetchNotifications,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                          itemCount: filtered.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            if (i == filtered.length) {
                              _loadMore();
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: AppColors.deepBlue,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return _NotificationCard(
                              item: filtered[i],
                              onTap: () => _openDetail(filtered[i]),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLegacyHeader() {
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
            onPressed: _closeScreen,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text('Thông báo', style: AppColors.topBarTitleStyle),
          ),
          if (_unreadCount > 0)
            Tooltip(
              message: 'Đánh dấu tất cả là đã đọc',
              child: TextButton.icon(
                onPressed: _markAllRead,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.deepBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text(
                  'Đọc tất cả',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AppTopBar(
      title: 'Thông báo',
      onBack: _closeScreen,
      trailing: _unreadCount == 0
          ? null
          : IconButton(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Đánh dấu tất cả là đã đọc',
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppListState(
          kind: AppListStateKind.empty,
          title: 'Không có thông báo',
          description: _activeFilter == _NotifFilter.all
              ? 'Bạn chưa có thông báo nào.'
              : _activeFilter == _NotifFilter.unread
              ? 'Không có thông báo chưa đọc.'
              : 'Không có thông báo đã đọc.',
          icon: Icons.notifications_off_outlined,
        ),
      ),
    );
  }
}

class _NotificationLoadingState extends StatelessWidget {
  const _NotificationLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: const [
        AppSkeleton(width: double.infinity, height: 132, borderRadius: 10),
        SizedBox(height: 8),
        AppSkeleton(width: double.infinity, height: 132, borderRadius: 10),
        SizedBox(height: 8),
        AppSkeleton(width: double.infinity, height: 132, borderRadius: 10),
        SizedBox(height: 8),
        AppSkeleton(width: double.infinity, height: 132, borderRadius: 10),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter enum & bar
// ---------------------------------------------------------------------------

enum _NotifFilter { all, unread, read }

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.active,
    required this.unreadCount,
    required this.onChanged,
  });

  final _NotifFilter active;
  final int unreadCount;
  final ValueChanged<_NotifFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: _FilterChip(
              label: 'Tất cả',
              icon: Icons.list_rounded,
              isActive: active == _NotifFilter.all,
              onTap: () => onChanged(_NotifFilter.all),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChip(
              label: unreadCount > 0 ? 'Chưa đọc ($unreadCount)' : 'Chưa đọc',
              icon: Icons.mark_email_unread_outlined,
              isActive: active == _NotifFilter.unread,
              onTap: () => onChanged(_NotifFilter.unread),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChip(
              label: 'Đã đọc',
              icon: Icons.done_all_rounded,
              isActive: active == _NotifFilter.read,
              onTap: () => onChanged(_NotifFilter.read),
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
        height: 42,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppColors.deepBlue, AppColors.primary],
                )
              : null,
          color: isActive ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : AppColors.bodyText,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isActive ? Colors.white : AppColors.bodyText,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  height: 16 / 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification Card
// ---------------------------------------------------------------------------

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;
    return Material(
      color: isUnread ? AppColors.infoSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(
              color: isUnread
                  ? AppColors.primary.withValues(alpha: 0.22)
                  : AppColors.cardBorder.withValues(alpha: 0.7),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Thanh màu bên trái (chưa đọc = deepBlue)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: isUnread ? AppColors.primary : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge trạng thái + icon loại
                        Row(
                          children: [
                            _TypeBadge(type: item.type),
                            const Spacer(),
                            _StatusBadge(isRead: item.isRead),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isUnread) ...[
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                            ],
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.inputText,
                                  fontWeight: item.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Thời gian
                        Text(
                          _formatTime(item.createdAt),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.bodyText,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Nội dung preview
                        Text(
                          item.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.bodyText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.bodyText,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1)
      return 'Hôm qua ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final NotificationType type;

  IconData get _icon => switch (type) {
    NotificationType.invoice => Icons.receipt_long_outlined,
    NotificationType.contract => Icons.description_outlined,
    NotificationType.maintenance => Icons.build_outlined,
    NotificationType.general => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          type.label,
          style: AppTypography.caption.copyWith(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    if (isRead) {
      return Text(
        'Đã đọc',
        style: AppTypography.caption.copyWith(
          color: AppColors.bodyText,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        'Chưa đọc',
        style: AppTypography.caption.copyWith(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification Detail Dialog
// ---------------------------------------------------------------------------

class _NotificationDetailDialog extends StatelessWidget {
  const _NotificationDetailDialog({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.76,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 58,
                padding: const EdgeInsets.only(left: 20, right: 8),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Chi tiết thông báo',
                        style: AppTypography.cardTitle,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Đóng',
                      constraints: const BoxConstraints.tightFor(
                        width: AppColors.minimumTouchTarget,
                        height: AppColors.minimumTouchTarget,
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
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TypeBadge(type: item.type),
                          const SizedBox(width: 8),
                          _StatusBadge(isRead: item.isRead),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        item.title,
                        style: AppTypography.cardTitle.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _formatDetailTime(item.createdAt),
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusMd,
                          ),
                        ),
                        child: Text(
                          item.content,
                          style: AppTypography.body.copyWith(
                            color: AppColors.inputText,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDetailTime(DateTime dt) {
    return formatDateTimeVN(dt).replaceFirst(' ', ' • ');
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: AppListState(
        kind: AppListStateKind.error,
        title: 'Không tải được thông báo',
        description: message,
        actionLabel: 'Thử lại',
        actionIcon: Icons.refresh_rounded,
        onAction: onRetry,
      ),
    ),
  );
}
