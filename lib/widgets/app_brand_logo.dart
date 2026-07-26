import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

enum AppBrandLogoVariant { login, overview, splash }

/// Reusable property logo based on the apartment icon used across the app.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({super.key, this.variant = AppBrandLogoVariant.login});

  final AppBrandLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      AppBrandLogoVariant.login => const _LoginBrandLogo(),
      AppBrandLogoVariant.overview => const _OverviewBrandLogo(),
      AppBrandLogoVariant.splash => const _SplashBrandLogo(),
    };
  }
}

class _SplashBrandLogo extends StatelessWidget {
  const _SplashBrandLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.apartment_rounded,
        color: AppColors.primary,
        size: 56,
      ),
    );
  }
}

class _LoginBrandLogo extends StatelessWidget {
  const _LoginBrandLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 57,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.apartment_rounded,
        color: AppColors.primary,
        size: 31,
      ),
    );
  }
}

class _OverviewBrandLogo extends StatelessWidget {
  const _OverviewBrandLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.09,
            child: Container(
              width: 42,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              ),
            ),
          ),
          Container(
            width: 44,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFDBEAFE)],
              ),
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: Colors.white, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: AppColors.primary,
              size: 27,
            ),
          ),
          Positioned(
            right: 1,
            bottom: 2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22D3EE), Color(0xFF06B6D4)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.6),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
