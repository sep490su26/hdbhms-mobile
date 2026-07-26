import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';

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
    final content = Padding(
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 44 : 72,
            height: compact ? 44 : 72,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: compact ? 24 : 36),
          ),
          SizedBox(height: compact ? 8 : 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: (compact ? AppTypography.label : AppTypography.cardTitle)
                .copyWith(fontWeight: FontWeight.w700),
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

    if (!scrollable) return compact ? content : Center(child: content);

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
