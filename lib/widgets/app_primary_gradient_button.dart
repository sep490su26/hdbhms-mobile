import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

/// Primary action shared by tenant-facing workflows.
class AppPrimaryGradientButton extends StatelessWidget {
  const AppPrimaryGradientButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.borderRadius = 16,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final radius = BorderRadius.circular(borderRadius);

    return Semantics(
      button: true,
      enabled: isEnabled,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: isEnabled
                ? null
                : AppColors.deepBlue.withValues(alpha: 0.46),
            gradient: isEnabled
                ? const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [AppColors.deepBlue, AppColors.primary],
                  )
                : null,
            borderRadius: radius,
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: Center(
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
