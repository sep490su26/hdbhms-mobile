import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

class AppTypography {
  const AppTypography._();

  static const fontFamily = 'PlusJakartaSans';

  static const topBarTitle = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.darkBlue,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 22 / 17,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const pageTitle = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.darkBlue,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 36 / 28,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const sectionTitle = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.darkBlue,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 24 / 18,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const cardTitle = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.inputText,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 22 / 16,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const bodyLarge = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.bodyText,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.bodyText,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 21 / 14,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const label = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.inputText,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 18 / 13,
    letterSpacing: 0.1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const caption = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.bodyText,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 17 / 12,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 20 / 15,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
