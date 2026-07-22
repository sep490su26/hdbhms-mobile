import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const darkBlue = Color(0xFF12345C);
  static const deepBlue = Color(0xFF0B1F3A);
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFFE0F2FE);
  static const accent = Color(0xFF14B8A6);
  static const accentWarm = Color(0xFFFF6B6B);
  static const accentLime = Color(0xFFA3E635);
  static const accentViolet = Color(0xFF8B5CF6);
  static const actionBlue = Color(0xFF2563EB);
  static const actionViolet = Color(0xFF7C3AED);
  static const actionOrange = Color(0xFFF97316);
  static const actionEmerald = Color(0xFF059669);
  static const actionRose = Color(0xFFE11D48);
  static const actionCyan = Color(0xFF0891B2);
  static const background = Color(0xFFF6FAF9);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF1F7F6);
  static const inputFill = Color(0xFFF4F8FA);
  static const bodyText = Color(0xFF5B6678);
  static const inputText = Color(0xFF101828);
  static const hintText = Color(0xFF8A94A6);
  static const border = Color(0xFFDDE7EA);
  static const cardBorder = Color(0xFFE3EAEE);
  static const requirementBackground = Color(0xFFF0F7F4);
  static const heroGradientStart = Color(0xFF061827);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF061827),
      Color(0xFF0B1F3A),
      Color(0xFF12345C),
      Color(0xFF2563EB),
    ],
    stops: [0, 0.34, 0.7, 1],
  );

  static const topBarHeight = 60.0;
  static const topBarIconSize = 24.0;
  static const topBarIconColor = deepBlue;
  static const topBarTitleStyle = TextStyle(
    fontFamily: 'BeVietnamPro',
    color: darkBlue,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 22 / 17,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
