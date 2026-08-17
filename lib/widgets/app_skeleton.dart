import 'package:flutter/material.dart';

/// A small reusable shimmer surface that keeps content dimensions stable.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final alignment = Alignment(-1 + (_controller.value * 2), 0);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: alignment,
              end: Alignment(alignment.x + 1.2, 0),
              colors: const [
                Color(0xFFE8EDF3),
                Color(0xFFF7F9FB),
                Color(0xFFE8EDF3),
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
        );
      },
    );
  }
}
