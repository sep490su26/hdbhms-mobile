import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';

class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.accentColor,
    this.onTap,
    this.enabled = true,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool enabled;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onTap != null;
    final effectiveAccent = isEnabled ? accentColor : AppColors.hintText;
    return Semantics(
      enabled: isEnabled,
      label: disabledReason == null ? label : '$label. $disabledReason',
      child: Material(
        color: isEnabled ? AppColors.surface : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                if (isEnabled)
                  BoxShadow(
                    color: AppColors.deepBlue.withValues(alpha: 0.045),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: effectiveAccent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Icon(icon, color: effectiveAccent, size: 20),
                    ),
                    const Spacer(),
                    if (isEnabled)
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: effectiveAccent.withValues(alpha: 0.72),
                        size: 18,
                      ),
                  ],
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isEnabled ? AppColors.inputText : AppColors.hintText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 17 / 13,
                  ),
                ),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: effectiveAccent.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppActionRowButton extends StatelessWidget {
  const AppActionRowButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlue.withValues(alpha: 0.045),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.bodyText,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
