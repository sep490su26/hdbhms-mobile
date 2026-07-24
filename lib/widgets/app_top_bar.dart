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
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? leading;

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
      child: Row(
        children: [
          if (leading != null)
            leading!
          else if (onBack != null)
            IconButton(
              onPressed: onBack,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Quay lại',
            )
          else
            const SizedBox(width: 12),
          const SizedBox(width: 4),
          Expanded(child: Text(title, style: AppColors.topBarTitleStyle)),
          // ignore: use_null_aware_elements
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
