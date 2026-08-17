import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';

enum AppListStateKind { empty, error }

enum AppListStateActionStyle { primary, secondary }

/// Shared empty and error treatment for screens that render collections.
class AppListState extends StatelessWidget {
  const AppListState({
    super.key,
    required this.kind,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.actionIcon,
    this.actionStyle,
    this.onAction,
  });

  final AppListStateKind kind;
  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final IconData? actionIcon;
  final AppListStateActionStyle? actionStyle;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isError = kind == AppListStateKind.error;
    final accent = isError ? AppColors.dangerText : AppColors.primary;
    final displayIcon = isError ? Icons.cloud_off_rounded : icon;
    final illustrationSurface = isError
        ? AppColors.dangerSurface
        : AppColors.infoSurface;
    final secondarySurface = isError
        ? AppColors.dangerSurface.withValues(alpha: 0.6)
        : AppColors.primaryLight.withValues(alpha: 0.75);
    final resolvedActionStyle =
        actionStyle ??
        (isError
            ? AppListStateActionStyle.primary
            : AppListStateActionStyle.secondary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ListStateIllustration(
            icon: displayIcon,
            color: accent,
            background: illustrationSurface,
            secondaryBackground: secondarySurface,
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.cardTitle.copyWith(color: AppColors.darkBlue),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 18),
            _ListStateAction(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction!,
              style: resolvedActionStyle,
            ),
          ],
        ],
      ),
    );
  }
}

class _ListStateIllustration extends StatelessWidget {
  const _ListStateIllustration({
    required this.icon,
    required this.color,
    required this.background,
    required this.secondaryBackground,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final Color secondaryBackground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 172,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
            ),
            child: SizedBox(width: 164, height: 164),
          ),
          Positioned(
            top: 0,
            right: 18,
            child: _StateOrb(size: 48, color: secondaryBackground),
          ),
          Positioned(
            bottom: 2,
            left: 6,
            child: _StateOrb(size: 34, color: secondaryBackground),
          ),
          Container(
            width: 202,
            height: 142,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBlue.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3),
                  ),
                  child: Icon(icon, color: color, size: 29),
                ),
                const SizedBox(height: 15),
                const _StateLine(width: 70),
                const SizedBox(height: 7),
                const _StateLine(width: 102),
                const SizedBox(height: 7),
                const _StateLine(width: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateOrb extends StatelessWidget {
  const _StateOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _ListStateAction extends StatelessWidget {
  const _ListStateAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.style,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final AppListStateActionStyle style;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(label, style: AppTypography.button);
    final hasIcon = icon != null;
    if (style == AppListStateActionStyle.primary) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, AppColors.minimumTouchTarget),
          elevation: 0,
        ),
        child: hasIcon
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon!, size: 18),
                  const SizedBox(width: 7),
                  labelWidget,
                ],
              )
            : labelWidget,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, AppColors.minimumTouchTarget),
        side: const BorderSide(color: AppColors.primary),
      ),
      child: hasIcon
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon!, size: 18),
                const SizedBox(width: 7),
                labelWidget,
              ],
            )
          : labelWidget,
    );
  }
}

class _StateLine extends StatelessWidget {
  const _StateLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 6,
    decoration: BoxDecoration(
      color: AppColors.cardBorder,
      borderRadius: BorderRadius.circular(AppColors.radiusPill),
    ),
  );
}
