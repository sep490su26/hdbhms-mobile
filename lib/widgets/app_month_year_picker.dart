import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

/// A compact month/year-only filter. It deliberately never exposes a day.
Future<DateTime?> showAppMonthYearPicker({
  required BuildContext context,
  required DateTime? selectedMonth,
  required String title,
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
    builder: (_) =>
        _MonthYearPickerSheet(selectedMonth: selectedMonth, title: title),
  );
}

class _MonthYearPickerSheet extends StatefulWidget {
  const _MonthYearPickerSheet({
    required this.selectedMonth,
    required this.title,
  });

  final DateTime? selectedMonth;
  final String title;

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.selectedMonth?.year ?? DateTime.now().year;
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
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(DateTime(0)),
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text('Tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() => _year -= 1),
                tooltip: 'Năm trước',
                icon: const Icon(Icons.chevron_left_rounded),
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
                onPressed: () => setState(() => _year += 1),
                tooltip: 'Năm sau',
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: months.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
            ),
            itemBuilder: (context, index) {
              final month = index + 1;
              final selected =
                  widget.selectedMonth?.year == _year &&
                  widget.selectedMonth?.month == month;
              return Material(
                color: selected ? AppColors.primary : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                child: InkWell(
                  onTap: () =>
                      Navigator.of(context).pop(DateTime(_year, month)),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  child: Center(
                    child: Text(
                      months[index],
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.inputText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
