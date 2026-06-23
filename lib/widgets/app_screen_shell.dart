import 'package:flutter/material.dart';

/// Keeps the mobile top bar full-width while constraining only page content.
class AppScreenShell extends StatelessWidget {
  const AppScreenShell({
    super.key,
    required this.header,
    required this.child,
    this.maxContentWidth = 448,
  });

  final Widget header;
  final Widget child;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(width: double.infinity, child: header),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ],
    );
  }
}
