import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/home/electricity_consumption_entry.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_list_state.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';

class ElectricityConsumptionHistoryScreen extends StatelessWidget {
  const ElectricityConsumptionHistoryScreen({
    super.key,
    required this.entries,
    required this.roomLabel,
    required this.occupancyStart,
  });

  final List<ElectricityConsumptionEntry> entries;
  final String roomLabel;
  final DateTime? occupancyStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppScreenShell(
          header: AppTopBar(
            title: 'Lịch sử tiêu thụ điện',
            onBack: () => Navigator.of(context).pop(),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _ContextCard(
                roomLabel: roomLabel,
                occupancyStart: occupancyStart,
              ),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                const AppListState(
                  kind: AppListStateKind.empty,
                  icon: Icons.bolt_outlined,
                  title: 'Chưa có dữ liệu tiêu thụ điện',
                  description:
                      'Dữ liệu sẽ hiển thị sau khi có kỳ ghi điện thuộc thời gian bạn ở.',
                )
              else ...[
                _ElectricityChartCard(entries: entries),
                const SizedBox(height: 20),
                Text('Các kỳ ghi điện', style: AppTypography.sectionTitle),
                const SizedBox(height: 10),
                ...entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ElectricityDetailCard(entry: entry),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.roomLabel, required this.occupancyStart});

  final String roomLabel;
  final DateTime? occupancyStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: const Icon(
              Icons.meeting_room_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roomLabel, style: AppTypography.cardTitle),
                const SizedBox(height: 2),
                Text(
                  occupancyStart == null
                      ? 'Dữ liệu theo hợp đồng đang chọn'
                      : 'Từ ${_formatDate(occupancyStart!)}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ElectricityChartCard extends StatelessWidget {
  const _ElectricityChartCard({required this.entries});

  final List<ElectricityConsumptionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final chartEntries = entries
        .take(6)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thống kê tiêu thụ', style: AppTypography.cardTitle),
          const SizedBox(height: 3),
          Text('6 kỳ gần nhất', style: AppTypography.caption),
          const SizedBox(height: 14),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _ElectricityBarChartPainter(chartEntries),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 4, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: chartEntries
                      .map(
                        (entry) =>
                            Expanded(child: _ChartPeriodLabel(entry: entry)),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPeriodLabel extends StatelessWidget {
  const _ChartPeriodLabel({required this.entry});

  final ElectricityConsumptionEntry entry;

  @override
  Widget build(BuildContext context) {
    final period = entry.periodKey.length >= 7
        ? entry.periodKey.substring(5, 7)
        : entry.periodLabel;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 168),
        child: Text(
          period,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(fontSize: 10),
        ),
      ),
    );
  }
}

class _ElectricityBarChartPainter extends CustomPainter {
  const _ElectricityBarChartPainter(this.entries);

  final List<ElectricityConsumptionEntry> entries;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0;
    const top = 8.0;
    const bottom = 28.0;
    final chartHeight = math.max(0.0, size.height - top - bottom);
    final chartWidth = math.max(0.0, size.width - left - 4);
    final gridPaint = Paint()
      ..color = AppColors.cardBorder
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final maxUsage = entries
        .map((entry) => entry.usage ?? 0)
        .fold<double>(0, math.max);
    final axisMax = maxUsage <= 0 ? 1.0 : maxUsage;

    for (var index = 0; index <= 3; index++) {
      final y = top + chartHeight * index / 3;
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);
      textPainter.text = TextSpan(
        text: _compactValue(axisMax * (3 - index) / 3),
        style: AppTypography.caption.copyWith(fontSize: 9),
      );
      textPainter.layout(maxWidth: left - 3);
      textPainter.paint(canvas, Offset(left - textPainter.width - 4, y - 7));
    }

    if (entries.isEmpty) return;
    final slot = chartWidth / entries.length;
    final barWidth = math.min(28.0, slot * 0.54);
    final barPaint = Paint()..color = AppColors.primary;
    for (var index = 0; index < entries.length; index++) {
      final usage = entries[index].usage ?? 0;
      final height = axisMax <= 0 ? 0.0 : chartHeight * usage / axisMax;
      final x = left + slot * index + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, top + chartHeight - height, barWidth, height),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ElectricityBarChartPainter oldDelegate) =>
      oldDelegate.entries != entries;
}

class _ElectricityDetailCard extends StatelessWidget {
  const _ElectricityDetailCard({required this.entry});

  final ElectricityConsumptionEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.periodLabel, style: AppTypography.cardTitle),
          const SizedBox(height: 12),
          _DetailRow('Tiêu thụ', _usageText(entry.usage)),
          _DetailRow(
            'Chỉ số',
            '${_readingText(entry.previousReading)} → ${_readingText(entry.currentReading)}',
          ),
          _DetailRow('Đơn giá', '${_formatAmount(entry.unitPrice)} đ/kWh'),
          _DetailRow('Thành tiền', '${_formatAmount(entry.amount)} đ'),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppTypography.metaLabel)),
        Text(value, style: AppTypography.metaValue),
      ],
    ),
  );
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatAmount(num value) {
  final raw = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    final reverseIndex = raw.length - index;
    buffer.write(raw[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write('.');
  }
  return buffer.toString();
}

String _usageText(double? value) =>
    value == null ? '--' : '${_compactValue(value)} kWh';

String _readingText(double? value) =>
    value == null ? '--' : _compactValue(value);

String _compactValue(num value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
