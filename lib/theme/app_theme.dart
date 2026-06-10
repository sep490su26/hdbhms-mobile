import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static const primaryColor = AppColors.darkBlue;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.topBarIconColor,
        toolbarHeight: AppColors.topBarHeight,
        iconTheme: IconThemeData(
          color: AppColors.topBarIconColor,
          size: AppColors.topBarIconSize,
        ),
        actionsIconTheme: IconThemeData(
          color: AppColors.topBarIconColor,
          size: AppColors.topBarIconSize,
        ),
        titleTextStyle: AppColors.topBarTitleStyle,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
