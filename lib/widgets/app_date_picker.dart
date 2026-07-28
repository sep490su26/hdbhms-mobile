import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_theme.dart';

/// Centralises the date picker behaviour so every date flow uses Vietnamese
/// labels and inherits the app's light or dark date-picker theme.
class AppDatePicker {
  AppDatePicker._();

  static const locale = Locale('vi', 'VN');

  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  }) {
    return showDatePicker(
      context: context,
      locale: locale,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialEntryMode: initialEntryMode,
      builder: _lightPickerTheme,
    );
  }

  static Future<DateTimeRange?> showRange({
    required BuildContext context,
    required DateTime firstDate,
    required DateTime lastDate,
    DateTimeRange? initialDateRange,
  }) {
    return showDateRangePicker(
      context: context,
      locale: locale,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialDateRange,
      builder: _lightPickerTheme,
    );
  }

  static Widget _lightPickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: AppTheme.lightTheme,
      child: child ?? const SizedBox.shrink(),
    );
  }
}
