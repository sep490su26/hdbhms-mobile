import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _ringOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleOffset;
  late final Animation<double> _tagsOpacity;
  late final Animation<double> _progress;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.18, curve: Curves.easeOut),
    );
    _logoScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.5, curve: Curves.elasticOut),
    );
    _ringOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.55, curve: Curves.easeOut),
    );
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.62, curve: Curves.easeOut),
    );
    _titleOffset = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.28, 0.65, curve: Curves.easeOutCubic),
          ),
        );
    _tagsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.8, curve: Curves.easeOut),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.06, 1, curve: Curves.easeInOutCubic),
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
      backgroundColor: const Color(0xFF030B1C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background layers
          const _RichBackground(),
          CustomPaint(
            painter: _DotGridPainter(
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          CustomPaint(painter: _ArcsPainter()),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── LOGO ──────────────────────────────────────
                  Semantics(
                    label: 'HDBHMS, hệ thống quản lý nhà trọ',
                    image: true,
                    child: FadeTransition(
                      opacity: _logoOpacity,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            final floatY =
                                math.sin(_controller.value * math.pi * 2) * 5;
                            return Transform.translate(
                              offset: Offset(0, floatY),
                              child: child,
                            );
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow ring
                              FadeTransition(
                                opacity: _ringOpacity,
                                child: _GlowRing(
                                  size: 200,
                                  color: const Color(0xFF38BDF8),
                                  alpha: 0.08,
                                ),
                              ),
                              // Mid glow ring
                              FadeTransition(
                                opacity: _ringOpacity,
                                child: _GlowRing(
                                  size: 158,
                                  color: const Color(0xFF60A5FA),
                                  alpha: 0.14,
                                ),
                              ),
                              // Inner glow ring
                              FadeTransition(
                                opacity: _ringOpacity,
                                child: _GlowRing(
                                  size: 120,
                                  color: const Color(0xFF93C5FD),
                                  alpha: 0.2,
                                ),
                              ),
                              // Logo card
                              const _BuildingLogo(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 38),

                  // ── TITLE ──────────────────────────────────────
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(
                      position: _titleOffset,
                      child: Column(
                        children: [
                          const Text(
                            'HDBHMS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Quản lý nhà trọ thông minh',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── FEATURE TAGS ───────────────────────────────
                  FadeTransition(
                    opacity: _tagsOpacity,
                    child: const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      children: [
                        _FeatureTag(label: 'Phòng trọ'),
                        _FeatureTag(label: 'Hóa đơn'),
                        _FeatureTag(label: 'Hợp đồng'),
                        _FeatureTag(label: 'Bảo trì'),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── PROGRESS ───────────────────────────────────
                  Semantics(
                    label: 'Đang khởi động ứng dụng',
                    child: Column(
                      children: [
                        // Progress track
                        Container(
                          width: 230,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.centerLeft,
                          child: AnimatedBuilder(
                            animation: _progress,
                            builder: (context, child) {
                              return FractionallySizedBox(
                                widthFactor: _progress.value,
                                child: child,
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFF22D3EE),
                                    Color(0xFFBAE6FD),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF38BDF8,
                                    ).withValues(alpha: 0.7),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Text(
                          'ĐANG KHỞI ĐỘNG',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.5,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'Hệ thống quản lý nhà trọ HDBHMS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Building Logo ─────────────────────────────────────────────────
class _BuildingLogo extends StatelessWidget {
  const _BuildingLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back tilted card
          Transform.rotate(
            angle: -0.1,
            child: Container(
              width: 88,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
          ),
          // Mid tilted card
          Transform.rotate(
            angle: 0.07,
            child: Container(
              width: 88,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
            ),
          ),
          // Main logo card
          Container(
            width: 90,
            height: 98,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFDBEAFE)],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.12),
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Color(0xFF1D4ED8),
              size: 54,
            ),
          ),
          // Accent badge
          Positioned(
            right: 10,
            bottom: 12,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22D3EE), Color(0xFF06B6D4)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22D3EE).withValues(alpha: 0.6),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Glow Ring ─────────────────────────────────────────────────────
class _GlowRing extends StatelessWidget {
  const _GlowRing({
    required this.size,
    required this.color,
    required this.alpha,
  });

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: alpha * 1.8),
          width: 1.2,
        ),
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
          stops: const [0.6, 1],
        ),
      ),
    );
  }
}

// ─── Feature Tag ───────────────────────────────────────────────────
class _FeatureTag extends StatelessWidget {
  const _FeatureTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─── Rich Background ───────────────────────────────────────────────
class _RichBackground extends StatelessWidget {
  const _RichBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF020917),
            Color(0xFF071640),
            Color(0xFF0C2878),
            Color(0xFF0758A8),
          ],
          stops: [0, 0.35, 0.7, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _GlowOrb(color: const Color(0xFF38BDF8), size: 280),
          ),
          Positioned(
            top: 160,
            left: -140,
            child: _GlowOrb(color: const Color(0xFF818CF8), size: 260),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: _GlowOrb(color: const Color(0xFF2563EB), size: 320),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: _GlowOrb(color: const Color(0xFF06B6D4), size: 200),
          ),
        ],
      ),
    );
  }
}

// ─── Glow Orb ──────────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

// ─── Dot Grid Painter ──────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (var x = 14.0; x < size.width; x += spacing) {
      for (var y = 14.0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─── Decorative Arcs Painter ───────────────────────────────────────
class _ArcsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Top-right corner arcs
    for (int i = 0; i < 4; i++) {
      paint.color = Colors.white.withValues(alpha: 0.04 - i * 0.008);
      final radius = 80.0 + i * 50;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width + 20, -20), radius: radius),
        math.pi * 0.55,
        math.pi * 0.6,
        false,
        paint,
      );
    }

    // Bottom-left corner arcs
    for (int i = 0; i < 3; i++) {
      paint.color = Colors.white.withValues(alpha: 0.035 - i * 0.008);
      final radius = 100.0 + i * 60;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(-30, size.height + 30), radius: radius),
        -math.pi * 0.45,
        math.pi * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcsPainter oldDelegate) => false;
}
