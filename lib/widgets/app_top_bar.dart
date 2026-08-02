import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

/// Shared top bar for tenant-facing screens.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.leading,
    this.pageIcon,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? leading;
  final IconData? pageIcon;

  @override
  Widget build(BuildContext context) {
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
      child: IconTheme(
        data: const IconThemeData(
          color: AppColors.topBarIconColor,
          size: AppColors.topBarIconSize,
        ),
        child: Row(
          children: [
            if (leading != null)
              leading!
            else if (onBack != null)
              Semantics(
                button: true,
                label: 'Quay l\u1EA1i',
                child: IconButton(
                  onPressed: onBack,
                  constraints: const BoxConstraints.tightFor(
                    width: AppColors.minimumTouchTarget,
                    height: AppColors.minimumTouchTarget,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.topBarIconColor,
                  ),
                  tooltip: 'Quay lại',
                ),
              )
            else
              const SizedBox(width: 12),
            const SizedBox(width: 4),
            if (pageIcon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Icon(pageIcon, color: AppColors.deepBlue, size: 20),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(title, style: AppColors.topBarTitleStyle)),
            // ignore: use_null_aware_elements
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
