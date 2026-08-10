import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

enum AppListStateKind { empty, error }

/// Shared empty and error treatment for screens that render collections.
class AppListState extends StatelessWidget {
  const AppListState({
    super.key,
    required this.kind,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final AppListStateKind kind;
  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isError = kind == AppListStateKind.error;
    final accent = isError ? AppColors.dangerText : AppColors.deepBlue;
    final displayIcon = isError ? Icons.cloud_off_rounded : icon;

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
          _ListStateIllustration(icon: displayIcon, color: accent),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 22 / 16,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 19 / 13,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: Icon(isError ? Icons.refresh_rounded : Icons.tune_rounded),
              label: Text(actionLabel!),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListStateIllustration extends StatelessWidget {
  const _ListStateIllustration({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 172,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE8EAFC),
            ),
            child: SizedBox(width: 164, height: 164),
          ),
          const Positioned(top: 0, right: 18, child: _StateOrb(size: 48)),
          const Positioned(bottom: 2, left: 6, child: _StateOrb(size: 34)),
          Container(
            width: 202,
            height: 142,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12101F3A),
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
  const _StateOrb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFE0E3F5),
    ),
  );
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
