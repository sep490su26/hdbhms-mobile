import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

/// Chip lọc đồng bộ style với màn hóa đơn.
/// Active: gradient deepBlue → primary, text trắng, bóng nhẹ.
/// Inactive: surface trắng, border cardBorder, text bodyText.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  /// Icon hiển thị bên trái label (tuỳ chọn).
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final chip = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
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
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: expanded
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : AppColors.bodyText,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.bodyText,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: chip) : chip;
  }
}
