import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

/// A compact month/year-only filter. It deliberately never exposes a day.
Future<DateTime?> showAppMonthYearPicker({
  required BuildContext context,
  required DateTime? selectedMonth,
  required String title,
  DateTime? firstMonth,
  DateTime? lastMonth,
}) {
  return showModalBottomSheet<DateTime?>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppColors.radiusLg),
      ),
    ),
    builder: (_) => _MonthYearPickerSheet(
      selectedMonth: selectedMonth,
      title: title,
      firstMonth: firstMonth,
      lastMonth: lastMonth,
    ),
  );
}

class _MonthYearPickerSheet extends StatefulWidget {
  const _MonthYearPickerSheet({
    required this.selectedMonth,
    required this.title,
    this.firstMonth,
    this.lastMonth,
  });

  final DateTime? selectedMonth;
  final String title;
  final DateTime? firstMonth;
  final DateTime? lastMonth;

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  late int _year;
  DateTime? _pendingMonth;

  DateTime get _firstMonth {
    final month = widget.firstMonth;
    return month == null ? DateTime(2000, 1) : DateTime(month.year, month.month);
  }

  DateTime get _lastMonth {
    final now = DateTime.now();
    final month = widget.lastMonth;
    final result = month == null
        ? DateTime(now.year, now.month)
        : DateTime(month.year, month.month);
    return result.isBefore(_firstMonth) ? _firstMonth : result;
  }

  @override
  void initState() {
    super.initState();
    final selected = widget.selectedMonth;
    final initial = selected == null
        ? _lastMonth
        : DateTime(selected.year, selected.month);
    _year = initial.isBefore(_firstMonth)
        ? _firstMonth.year
        : initial.isAfter(_lastMonth)
        ? _lastMonth.year
        : initial.year;
    _pendingMonth = widget.selectedMonth;
  }

  @override
  Widget build(BuildContext context) {
    const months = <String>[
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: AppColors.inputText,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chọn từ ${_formatMonth(_firstMonth)} đến ${_formatMonth(_lastMonth)}',
                      style: const TextStyle(
                        color: AppColors.bodyText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              IconButton(
                onPressed: _year > _firstMonth.year
                    ? () => setState(() => _year -= 1)
                    : null,
                tooltip: 'Năm trước',
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.deepBlue,
                ),
              ),
              Text(
                'Năm $_year',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepBlue,
                ),
              ),
              IconButton(
                onPressed: _year < _lastMonth.year
                    ? () => setState(() => _year += 1)
                    : null,
                tooltip: 'Năm sau',
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.deepBlue,
                ),
              ),
            ],
          ),
          ),
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'CHỌN THÁNG',
              style: TextStyle(
                color: AppColors.bodyText,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: months.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.65,
            ),
            itemBuilder: (context, index) {
              final month = index + 1;
              final selected =
                  _pendingMonth?.year == _year &&
                  _pendingMonth?.month == month;
              final candidate = DateTime(_year, month);
              final isAvailable =
                  !candidate.isBefore(_firstMonth) &&
                  !candidate.isAfter(_lastMonth);
              return Material(
                color: selected
                    ? AppColors.primary
                    : isAvailable
                    ? AppColors.surfaceMuted
                    : AppColors.surfaceMuted.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                child: InkWell(
                  onTap: isAvailable
                      ? () => setState(() => _pendingMonth = candidate)
                      : null,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  child: Center(
                    child: Text(
                      months[index],
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : isAvailable
                            ? AppColors.inputText
                            : AppColors.hintText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(DateTime(0)),
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  label: const Text('Tất cả'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepBlue,
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: AppColors.cardBorder),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pendingMonth == null
                      ? null
                      : () => Navigator.of(context).pop(_pendingMonth),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Áp dụng'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMonth(DateTime value) =>
      'tháng ${value.month.toString().padLeft(2, '0')}/${value.year}';
}
