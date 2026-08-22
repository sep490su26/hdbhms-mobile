import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

/// Bell glyph with a non-blocking unread counter for use inside top-bar buttons.
class AppNotificationBell extends StatefulWidget {
  const AppNotificationBell({
    super.key,
    this.color = AppColors.topBarIconColor,
    this.size = 24,
    this.initialUnreadCount,
    this.refreshInitialUnreadCount = false,
    this.roomId,
    this.roomCode = '',
    this.notificationService = const NotificationService(),
  });

  final Color color;
  final double size;
  final int? initialUnreadCount;
  final bool refreshInitialUnreadCount;
  final int? roomId;
  final String roomCode;
  final NotificationService notificationService;

  @override
  State<AppNotificationBell> createState() => _AppNotificationBellState();
}

class _AppNotificationBellState extends State<AppNotificationBell> {
  int _unreadCount = 0;
  StreamSubscription<void>? _readSubscription;

  @override
  void initState() {
    super.initState();
    _unreadCount = _hasRoomScope ? 0 : widget.initialUnreadCount ?? 0;
    if (_hasRoomScope ||
        widget.initialUnreadCount == null ||
        widget.refreshInitialUnreadCount) {
      _loadUnreadCount();
    }
    _readSubscription = NotificationService.readEvents.listen((_) {
      if (mounted &&
          (_hasRoomScope ||
              widget.initialUnreadCount == null ||
              widget.refreshInitialUnreadCount)) {
        _loadUnreadCount();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AppNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scopeChanged =
        widget.roomId != oldWidget.roomId ||
        widget.roomCode.trim() != oldWidget.roomCode.trim();
    if (scopeChanged) {
      setState(
        () => _unreadCount = _hasRoomScope ? 0 : widget.initialUnreadCount ?? 0,
      );
      _loadUnreadCount();
      return;
    }
    if (widget.initialUnreadCount != null &&
        widget.initialUnreadCount != oldWidget.initialUnreadCount) {
      setState(() => _unreadCount = widget.initialUnreadCount!);
      if (widget.refreshInitialUnreadCount) _loadUnreadCount();
    }
  }

  @override
  void dispose() {
    _readSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final unreadCount = await widget.notificationService.getUnreadCount(
        roomId: widget.roomId,
        roomCode: widget.roomCode,
      );
      if (mounted) setState(() => _unreadCount = unreadCount);
    } catch (_) {
      // The bell stays usable when the count cannot be refreshed.
    }
  }

  bool get _hasRoomScope =>
      (widget.roomId != null && widget.roomId! > 0) ||
      widget.roomCode.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final label = _unreadCount > 99 ? '99+' : '$_unreadCount';
    return Semantics(
      label: _unreadCount > 0
          ? 'Thông báo, $_unreadCount chưa đọc'
          : 'Thông báo',
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            color: widget.color,
            size: widget.size,
          ),
          if (_unreadCount > 0)
            Positioned(
              top: -2,
              right: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
