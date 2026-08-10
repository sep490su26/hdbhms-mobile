import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_list_state.dart';

/// Consistent empty, filtered-empty, and retry states used across tenant flows.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.scrollable = false,
    this.onRefresh,
    this.iconColor = AppColors.deepBlue,
    this.topSpacing = 80,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool scrollable;
  final Future<void> Function()? onRefresh;
  final Color iconColor;
  final double topSpacing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      final state = AppListState(
        kind: AppListStateKind.empty,
        title: title,
        description:
            description ?? 'Nội dung sẽ xuất hiện tại đây khi có dữ liệu.',
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
      );

      if (!scrollable) {
        return Center(
          child: Padding(padding: const EdgeInsets.all(24), child: state),
        );
      }

      return RefreshIndicator(
        color: AppColors.deepBlue,
        onRefresh: onRefresh ?? () async => onAction?.call(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: topSpacing),
            Padding(padding: const EdgeInsets.all(24), child: state),
          ],
        ),
      );
    }

    final content = Padding(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.label.copyWith(fontWeight: FontWeight.w700),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
          ],
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );

    if (!scrollable) return content;

    return RefreshIndicator(
      color: AppColors.deepBlue,
      onRefresh: onRefresh ?? () async => onAction?.call(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: topSpacing),
          content,
        ],
      ),
    );
  }
}
