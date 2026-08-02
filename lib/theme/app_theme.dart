import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';

class AppTheme {
  const AppTheme._();

  static const primaryColor = AppColors.darkBlue;

  static ThemeData get lightTheme {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: AppColors.inputText,
      tertiary: AppColors.accentWarm,
      onTertiary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.inputText,
      surfaceContainerHighest: AppColors.surfaceMuted,
      error: AppColors.danger,
      onError: Colors.white,
      outline: AppColors.cardBorder,
      outlineVariant: AppColors.border,
      shadow: Color(0x1A10233F),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTypography.fontFamily,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        headlineSmall: AppTypography.pageTitle,
        titleLarge: AppTypography.sectionTitle,
        titleMedium: AppTypography.cardTitle,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.body,
        labelLarge: AppTypography.button,
      ).apply(fontFamily: AppTypography.fontFamily),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.topBarIconColor,
        toolbarHeight: AppColors.topBarHeight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryLight,
          disabledForegroundColor: AppColors.bodyText,
          minimumSize: const Size(48, 52),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: AppColors.cardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.hintText,
        ),
        labelStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.bodyText,
          fontWeight: FontWeight.w600,
        ),
        errorStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.danger,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inputText,
        contentTextStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      datePickerTheme: _datePickerTheme(),
    );
  }

  /// A safe dark baseline for system dark mode. Individual screens can adopt
  /// theme surfaces progressively without rendering white or unreadable UI.
  static ThemeData get darkTheme {
    const scheme = ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.deepBlue,
      secondary: AppColors.accent,
      onSecondary: AppColors.deepBlue,
      surface: AppColors.deepBlue,
      onSurface: Colors.white,
      surfaceContainerHighest: AppColors.darkBlue,
      error: AppColors.accentWarm,
      onError: Colors.white,
      outline: AppColors.bodyText,
      outlineVariant: AppColors.darkBlue,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.heroGradientStart,
      fontFamily: AppTypography.fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepBlue,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.deepBlue,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          side: const BorderSide(color: AppColors.darkBlue),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.deepBlue,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkBlue,
        hintStyle: const TextStyle(color: AppColors.hintText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.bodyText),
        ),
      ),
      datePickerTheme: _datePickerTheme(),
    );
  }

  static DatePickerThemeData _datePickerTheme() {
    const surface = AppColors.surface;
    const onSurface = AppColors.inputText;
    const muted = AppColors.bodyText;
    const outline = AppColors.cardBorder;

    return DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.surface,
      headerForegroundColor: AppColors.deepBlue,
      weekdayStyle: TextStyle(
        color: muted,
        fontFamily: AppTypography.fontFamily,
        fontWeight: FontWeight.w700,
      ),
      dayStyle: TextStyle(
        color: onSurface,
        fontFamily: AppTypography.fontFamily,
        fontWeight: FontWeight.w600,
      ),
      yearStyle: TextStyle(
        color: onSurface,
        fontFamily: AppTypography.fontFamily,
        fontWeight: FontWeight.w700,
      ),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.primary;
      }),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return muted;
        if (states.contains(WidgetState.selected)) return Colors.white;
        return onSurface;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.transparent;
      }),
      rangeSelectionBackgroundColor: AppColors.primary.withValues(alpha: 0.2),
      rangeSelectionOverlayColor:
          const WidgetStatePropertyAll(Colors.transparent),
      dividerColor: outline,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        side: BorderSide(color: outline),
      ),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.deepBlue,
        textStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontWeight: FontWeight.w800,
        ),
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
