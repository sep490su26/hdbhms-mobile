import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_brand_logo.dart';

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _splashDuration = Duration(milliseconds: 1800);

  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoEntranceScale;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleOffset;
  late final Animation<double> _progress;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _splashDuration);
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.18, curve: Curves.easeOut),
    );
    _logoEntranceScale = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.28, curve: Curves.easeOutCubic),
      ),
    );
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.42, curve: Curves.easeOut),
    );
    _titleOffset = Tween<Offset>(begin: const Offset(0, 0.16), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.18, 0.45, curve: Curves.easeOutCubic),
          ),
        );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 1, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationStarted) return;
    _animationStarted = true;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  Semantics(
                    label: 'HDBHMS, hệ thống quản lý nhà trọ',
                    image: true,
                    child: FadeTransition(
                      opacity: _logoOpacity,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final breath =
                              1 +
                              0.04 * math.sin(_controller.value * math.pi * 2);
                          return Transform.scale(
                            scale: _logoEntranceScale.value * breath,
                            child: child,
                          );
                        },
                        child: const AppBrandLogo(
                          variant: AppBrandLogoVariant.splash,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(
                      position: _titleOffset,
                      child: Text(
                        'HDBHMS',
                        textAlign: TextAlign.center,
                        style: AppTypography.pageTitle.copyWith(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  Semantics(
                    label: 'Đang khởi động ứng dụng',
                    child: SizedBox(
                      width: 224,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppColors.radiusPill,
                        ),
                        child: AnimatedBuilder(
                          animation: _progress,
                          builder: (context, child) => LinearProgressIndicator(
                            value: _progress.value,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
