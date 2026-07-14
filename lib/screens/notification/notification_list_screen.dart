// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../../models/notification/notification_model.dart';
import '../../services/notification/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_screen_shell.dart';
import '../../widgets/app_skeleton.dart';

/// Màn danh sách thông báo với filter Tất cả / Chưa đọc / Đã đọc.
class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final NotificationService _notificationService = const NotificationService();
  _NotifFilter _activeFilter = _NotifFilter.all;

  List<NotificationItem> _items = [];
  bool _isLoading = true;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _items = [];
      _hasMore = true;
    });

    try {
      final response = await _notificationService.getNotifications(
        limit: 20,
        after: 0,
      );
      setState(() {
        _items = response.items;
        _hasMore = response.hasMore;
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
      final lastId = _items.isNotEmpty ? int.tryParse(_items.last.id) ?? 0 : 0;
      final response = await _notificationService.getNotifications(
        limit: 20,
        after: lastId,
      );
      setState(() {
        _items.addAll(response.items);
        _hasMore = response.hasMore;
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

  int get _unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> _markAllRead() async {
    try {
      await _notificationService.markAllAsRead();
    } catch (_) {}

    setState(() {
      for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(isRead: true);
      }
    });
  }

  Future<void> _markRead(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1 && !_items[idx].isRead) {
      try {
        await _notificationService.markAsRead(id);
      } catch (_) {}

      setState(() {
        _items[idx] = _items[idx].copyWith(isRead: true);
      });
    }
  }

  void _openDetail(NotificationItem item) {
    _markRead(item.id);
    showDialog<void>(
      context: context,
      builder: (ctx) => _NotificationDetailDialog(item: item),
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

  Widget _buildHeader() {
    return Container(
      height: 54,
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
            child: Text(
              'Thông báo',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 20 / 16,
              ),
            ),
          ),
          if (_unreadCount > 0)
            Tooltip(
              message: 'Đánh dấu tất cả là đã đọc',
              child: TextButton.icon(
                onPressed: _markAllRead,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.deepBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                Icons.notifications_off_outlined,
                color: AppColors.deepBlue,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Không có thông báo',
              style: TextStyle(
                color: AppColors.inputText,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 20 / 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _activeFilter == _NotifFilter.all
                  ? 'Bạn chưa có thông báo nào.'
                  : _activeFilter == _NotifFilter.unread
                  ? 'Không có thông báo chưa đọc.'
                  : 'Không có thông báo đã đọc.',
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
          color: isActive
              ? AppColors.deepBlue.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? AppColors.deepBlue
                : AppColors.cardBorder.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? AppColors.deepBlue : AppColors.bodyText,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isActive ? AppColors.deepBlue : AppColors.bodyText,
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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: item.isRead
                  ? AppColors.cardBorder.withValues(alpha: 0.7)
                  : AppColors.deepBlue.withValues(alpha: 0.35),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Thanh màu bên trái (chưa đọc = deepBlue)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: item.isRead
                        ? Colors.transparent
                        : AppColors.deepBlue,
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
                        // Tiêu đề
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.inputText,
                            fontSize: 14,
                            fontWeight: item.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            height: 19 / 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Thời gian
                        Text(
                          _formatTime(item.createdAt),
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 15 / 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Nội dung preview
                        Text(
                          item.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 17 / 12,
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
        Icon(_icon, size: 13, color: AppColors.deepBlue),
        const SizedBox(width: 4),
        Text(
          type.label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.deepBlue,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            height: 14 / 10,
            letterSpacing: 0.5,
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
      return const Text(
        'Đã đọc',
        style: TextStyle(
          color: AppColors.bodyText,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 14 / 10,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.deepBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Chưa đọc',
        style: TextStyle(
          color: AppColors.deepBlue,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 14 / 10,
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
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dialog
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF1FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: AppColors.deepBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Chi tiết thông báo',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 20 / 15,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.bodyText,
                      size: 20,
                    ),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFEEECEE)),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tiêu đề thông báo
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.inputText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 21 / 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Thời gian
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: AppColors.bodyText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDetailTime(item.createdAt),
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 16 / 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFEEECEE),
                    ),
                    const SizedBox(height: 14),
                    // Nội dung đầy đủ
                    Text(
                      item.content,
                      style: const TextStyle(
                        color: AppColors.inputText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 20 / 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Nút đóng
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 20 / 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDetailTime(DateTime dt) {
    const days = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final dayName = days[dt.weekday - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$dayName, ${dt.day} tháng ${dt.month} ${dt.year} lúc $h:$m';
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
