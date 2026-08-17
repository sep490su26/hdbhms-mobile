import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/home/electricity_consumption_entry.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_list_state.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';

/// A chart-only point. Synthetic points are never added to invoice data or the
/// detail list: they only make missing eligible months visually explicit.
class ElectricityChartPoint {
  const ElectricityChartPoint({
    required this.month,
    required this.usage,
    required this.hasReading,
  });

  final DateTime month;
  final double usage;
  final bool hasReading;
}

class ElectricityChartAxis {
  const ElectricityChartAxis({required this.maximum, required this.ticks});

  final double maximum;
  final List<double> ticks;
}

/// Builds no more than six calendar months ending at the latest real reading.
/// The first month is never earlier than [occupancyStart], so a tenant never
/// sees chart filler for a period before moving in.
List<ElectricityChartPoint> buildElectricityChartPoints({
  required List<ElectricityConsumptionEntry> entries,
  required DateTime? occupancyStart,
}) {
  if (entries.isEmpty) return const [];

  final latest = entries
      .map((entry) => _monthOf(entry.referenceDate))
      .reduce((first, second) => first.isAfter(second) ? first : second);
  final moveInMonth = occupancyStart == null ? null : _monthOf(occupancyStart);
  var first = DateTime(latest.year, latest.month - 5);
  if (moveInMonth != null && first.isBefore(moveInMonth)) first = moveInMonth;

  final entriesByMonth = <DateTime, ElectricityConsumptionEntry>{};
  for (final entry in entries) {
    final month = _monthOf(entry.referenceDate);
    if (month.isBefore(first) || month.isAfter(latest)) continue;
    final existing = entriesByMonth[month];
    if (existing == null ||
        entry.referenceDate.isAfter(existing.referenceDate)) {
      entriesByMonth[month] = entry;
    }
  }

  final points = <ElectricityChartPoint>[];
  for (
    var month = first;
    !month.isAfter(latest);
    month = DateTime(month.year, month.month + 1)
  ) {
    final entry = entriesByMonth[month];
    points.add(
      ElectricityChartPoint(
        month: month,
        usage: entry?.usage ?? 0.0,
        hasReading: entry != null,
      ),
    );
  }
  return List.unmodifiable(points);
}

/// Produces a 0-based 1/2/5 × 10ⁿ axis. This avoids fractional visual ticks
/// while retaining each actual usage value as-is above its bar.
ElectricityChartAxis buildElectricityChartAxis(Iterable<double> usages) {
  final actualMaximum = usages.fold<double>(0, math.max);
  final step = _niceStep(math.max(10.0, actualMaximum / 3).toDouble());
  final maximum = math.max(30.0, step * 3).toDouble();
  return ElectricityChartAxis(
    maximum: maximum,
    ticks: List<double>.unmodifiable([0.0, step, step * 2, maximum]),
  );
}

double _niceStep(double value) {
  final exponent = math
      .pow(10, (math.log(value) / math.ln10).floor())
      .toDouble();
  final fraction = value / exponent;
  final niceFraction = fraction <= 1
      ? 1
      : fraction <= 2
      ? 2
      : fraction <= 5
      ? 5
      : 10;
  return math.max(10, niceFraction * exponent);
}

String formatElectricityChartMonth(DateTime month, {bool includeYear = false}) {
  final label = 'T${month.month}';
  return includeYear
      ? '$label/${(month.year % 100).toString().padLeft(2, '0')}'
      : label;
}

class ElectricityConsumptionHistoryScreen extends StatelessWidget {
  const ElectricityConsumptionHistoryScreen({
    super.key,
    required this.entries,
    required this.roomLabel,
    required this.occupancyStart,
    this.notificationService = const NotificationService(),
  });

  final List<ElectricityConsumptionEntry> entries;
  final String roomLabel;
  final DateTime? occupancyStart;
  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    final detailEntries = [...entries]
      ..sort(
        (first, second) => second.referenceDate.compareTo(first.referenceDate),
      );
    final chartPoints = buildElectricityChartPoints(
      entries: detailEntries,
      occupancyStart: occupancyStart,
    );
    return Scaffold(
      body: SafeArea(
        child: AppScreenShell(
          header: AppTopBar(
            title: 'Lịch sử tiêu thụ điện',
            onBack: () => Navigator.of(context).pop(),
            trailing: IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationListScreen(),
                ),
              ),
              constraints: const BoxConstraints.tightFor(
                width: AppColors.minimumTouchTarget,
                height: AppColors.minimumTouchTarget,
              ),
              icon: AppNotificationBell(
                notificationService: notificationService,
              ),
              tooltip: 'Thông báo',
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _ContextCard(
                roomLabel: roomLabel,
                occupancyStart: occupancyStart,
              ),
              if (detailEntries.isEmpty) ...[
                const SizedBox(height: 16),
                const AppListState(
                  kind: AppListStateKind.empty,
                  icon: Icons.bolt_outlined,
                  title: 'Chưa có dữ liệu tiêu thụ điện',
                  description:
                      'Dữ liệu sẽ hiển thị sau khi có kỳ ghi điện thuộc thời gian bạn ở.',
                ),
              ] else ...[
                const SizedBox(height: 16),
                _ElectricityHero(entries: detailEntries),
                const SizedBox(height: 16),
                _ElectricityChartCard(points: chartPoints),
                const SizedBox(height: 20),
                Text('Các kỳ ghi điện', style: AppTypography.sectionTitle),
                const SizedBox(height: 10),
                ...detailEntries.map(
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
              color: AppColors.primarySurface,
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

class _ElectricityHero extends StatelessWidget {
  const _ElectricityHero({required this.entries});

  final List<ElectricityConsumptionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final latest = entries.first;
    final previous = entries.length > 1 ? entries[1] : null;
    final difference = latest.usage != null && previous?.usage != null
        ? latest.usage! - previous!.usage!
        : null;
    final trend = difference == null
        ? null
        : difference > 0
        ? 'Tăng ${_compactValue(difference)} kWh so với kỳ trước'
        : difference < 0
        ? 'Giảm ${_compactValue(difference.abs())} kWh so với kỳ trước'
        : 'Ổn định so với kỳ trước';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: .96),
            AppColors.actionCyan.withValues(alpha: .82),
          ],
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            latest.periodLabel,
            style: AppTypography.metaLabel.copyWith(
              color: Colors.white.withValues(alpha: .84),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${latest.usage == null ? '--' : _compactValue(latest.usage!)} kWh',
            style: AppTypography.sectionTitle.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 6),
            Text(
              trend,
              style: AppTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: .88),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ElectricityChartCard extends StatelessWidget {
  const _ElectricityChartCard({required this.points});

  final List<ElectricityChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final axis = buildElectricityChartAxis(points.map((point) => point.usage));
    final years = points.map((point) => point.month.year).toSet();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Biểu đồ tiêu thụ điện',
                  style: AppTypography.cardTitle,
                ),
              ),
              Text('Đơn vị: kWh', style: AppTypography.metaLabel),
            ],
          ),
          const SizedBox(height: 3),
          Text('6 tháng gần nhất', style: AppTypography.caption),
          const SizedBox(height: 14),
          SizedBox(
            height: 218,
            width: double.infinity,
            child: _ElectricityChart(points: points, axis: axis, years: years),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              'Tháng',
              style: AppTypography.caption.copyWith(fontSize: 10),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tháng chưa có kỳ ghi nhận được hiển thị ở mức 0 trên biểu đồ.',
            style: AppTypography.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ElectricityChart extends StatelessWidget {
  const _ElectricityChart({
    required this.points,
    required this.axis,
    required this.years,
  });

  final List<ElectricityChartPoint> points;
  final ElectricityChartAxis axis;
  final Set<int> years;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => CustomPaint(
        painter: _ElectricityChartPainter(points: points, axis: axis),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(35, 8, 4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < points.length; index++)
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      formatElectricityChartMonth(
                        points[index].month,
                        includeYear:
                            years.length > 1 &&
                            (index == 0 || points[index].month.month == 1),
                      ),
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElectricityChartPainter extends CustomPainter {
  const _ElectricityChartPainter({required this.points, required this.axis});

  final List<ElectricityChartPoint> points;
  final ElectricityChartAxis axis;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 35.0;
    const top = 14.0;
    const bottom = 28.0;
    final chartHeight = math.max(0.0, size.height - top - bottom);
    final chartWidth = math.max(0.0, size.width - left - 4);
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    final gridPaint = Paint()
      ..color = AppColors.cardBorder
      ..strokeWidth = 1;
    for (var index = 0; index < axis.ticks.length; index++) {
      final y = top + chartHeight * index / (axis.ticks.length - 1);
      _drawDashedLine(
        canvas,
        Offset(left, y),
        Offset(left + chartWidth, y),
        gridPaint,
      );
      labelPainter.text = TextSpan(
        text: _compactValue(axis.ticks[axis.ticks.length - index - 1]),
        style: AppTypography.caption.copyWith(fontSize: 9),
      );
      labelPainter.layout(maxWidth: left - 3);
      labelPainter.paint(canvas, Offset(left - labelPainter.width - 4, y - 7));
    }
    if (points.isEmpty || chartWidth <= 0) return;

    final slot = chartWidth / points.length;
    final barWidth = math.min(28.0, math.max(10.0, slot * .52));
    final linePath = Path();
    final markerCenters = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final height = chartHeight * (point.usage / axis.maximum).clamp(0, 1);
      final x = left + slot * index + (slot - barWidth) / 2;
      final topY = top + chartHeight - height;
      if (height > 0) {
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, topY, barWidth, height),
          topLeft: const Radius.circular(7),
          topRight: const Radius.circular(7),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: .95),
                AppColors.actionCyan.withValues(alpha: .62),
              ],
            ).createShader(rect.outerRect),
        );
      }
      final center = Offset(x + barWidth / 2, topY);
      markerCenters.add(center);
      if (index == 0) {
        linePath.moveTo(center.dx, center.dy);
      } else {
        linePath.lineTo(center.dx, center.dy);
      }
      if (point.hasReading && point.usage > 0) {
        labelPainter.text = TextSpan(
          text: _compactValue(point.usage),
          style: AppTypography.caption.copyWith(
            color: AppColors.darkBlue,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        );
        labelPainter.layout(maxWidth: slot);
        labelPainter.paint(
          canvas,
          Offset(center.dx - labelPainter.width / 2, math.max(0, topY - 17)),
        );
      }
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.25
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var index = 0; index < markerCenters.length; index++) {
      final center = markerCenters[index];
      final point = points[index];
      canvas.drawCircle(center, 3.4, Paint()..color = AppColors.primary);
      canvas.drawCircle(center, 1.45, Paint()..color = Colors.white);
      if (!point.hasReading) {
        canvas.drawCircle(center, 3.8, Paint()..color = AppColors.cardBorder);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ElectricityChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.axis.maximum != axis.maximum;
}

void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
  const dash = 4.0;
  const gap = 4.0;
  for (var x = from.dx; x < to.dx; x += dash + gap) {
    canvas.drawLine(
      Offset(x, from.dy),
      Offset(math.min(x + dash, to.dx), to.dy),
      paint,
    );
  }
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

DateTime _monthOf(DateTime value) => DateTime(value.year, value.month);

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
