import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

class AppTypography {
  const AppTypography._();

  static const topBarTitle = TextStyle(
    color: AppColors.darkBlue,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 22 / 17,
    letterSpacing: 0,
  );

  static const pageTitle = TextStyle(
    color: AppColors.darkBlue,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 36 / 28,
    letterSpacing: 0,
  );

  static const sectionTitle = TextStyle(
    color: AppColors.darkBlue,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 24 / 18,
    letterSpacing: 0,
  );

  static const cardTitle = TextStyle(
    color: AppColors.inputText,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 22 / 16,
  );

  static const bodyLarge = TextStyle(
    color: AppColors.bodyText,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static const body = TextStyle(
    color: AppColors.bodyText,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 21 / 14,
  );

  static const label = TextStyle(
    color: AppColors.inputText,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 18 / 13,
    letterSpacing: 0.1,
  );

  static const caption = TextStyle(
    color: AppColors.bodyText,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 17 / 12,
  );

  static const button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 20 / 15,
  );
}
