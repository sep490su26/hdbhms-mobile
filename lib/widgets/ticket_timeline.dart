import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/ticket_status_badge.dart';

class TicketTimeline extends StatelessWidget {
  const TicketTimeline({
    super.key,
    required this.events,
    required this.currentStatus,
  });

  final List<TicketTimelineEvent> events;
  final TicketStatus currentStatus;

  @override
  Widget build(BuildContext context) {
    final sorted = [...events]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (sorted.isEmpty) {
      return const Text(
        'Chưa có tiến trình xử lý',
        style: TextStyle(
          color: AppColors.bodyText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < sorted.length; index++)
          _TimelineItem(
            event: sorted[index],
            isLast: index == sorted.length - 1,
            isCurrent: sorted[index].status == currentStatus.key,
          ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.event,
    required this.isLast,
    required this.isCurrent,
  });

  final TicketTimelineEvent event;
  final bool isLast;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final status = TicketStatus.fromBackend(event.status);
    final colors = ticketStatusColors(status);
    final markerColor = isCurrent ? colors.foreground : AppColors.deepBlue;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: markerColor,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 15),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.2,
                      color: const Color(0xFFDADAE2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      color: isCurrent ? colors.foreground : AppColors.deepBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 20 / 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    style: const TextStyle(
                      color: AppColors.bodyText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 19 / 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatDateTime(event.createdAt),
                    style: const TextStyle(
                      color: AppColors.hintText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}, '
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}
