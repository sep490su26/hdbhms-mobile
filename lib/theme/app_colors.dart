import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const darkBlue = Color(0xFF173B6C);
  static const deepBlue = Color(0xFF102A56);
  static const primary = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFFDBEAFE);
  static const accent = Color(0xFF22D3EE);
  static const background = Color(0xFFF4F7FB);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF8FAFC);
  static const inputFill = Color(0xFFF8FAFC);
  static const bodyText = Color(0xFF52627A);
  static const inputText = Color(0xFF10233F);
  static const hintText = Color(0xFF7C8BA1);
  static const border = Color(0xFFDDE5EF);
  static const cardBorder = Color(0xFFDCE5F0);
  static const requirementBackground = Color(0xFFF1F5F9);
  static const heroGradientStart = Color(0xFF071426);
  static const success = Color(0xFF0F9F6E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF020917),
      Color(0xFF0B1F4D),
      Color(0xFF173B6C),
      Color(0xFF1D4ED8),
    ],
    stops: [0, 0.34, 0.7, 1],
  );

  static const topBarHeight = 60.0;
  static const topBarIconSize = 24.0;
  static const topBarIconColor = deepBlue;
  static const topBarTitleStyle = TextStyle(
    color: darkBlue,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 22 / 17,
    letterSpacing: -0.2,
  );
}
