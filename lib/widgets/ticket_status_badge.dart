import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

class TicketStatusBadge extends StatelessWidget {
  const TicketStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final TicketStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = ticketStatusColors(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 14,
        vertical: compact ? 5 : 9,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.foreground,
          fontSize: compact ? 11 : 13,
          fontWeight: FontWeight.w800,
          height: 16 / 13,
        ),
      ),
    );
  }
}

class TicketStatusColors {
  const TicketStatusColors({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}

TicketStatusColors ticketStatusColors(TicketStatus status) {
  return switch (status) {
    TicketStatus.pending => const TicketStatusColors(
      background: Color(0xFFFFE9C7),
      foreground: Color(0xFFB45309),
      icon: Icons.hourglass_empty_rounded,
    ),
    TicketStatus.accepted => const TicketStatusColors(
      background: Color(0xFFE9E7E4),
      foreground: Color(0xFF55565E),
      icon: Icons.schedule_rounded,
    ),
    TicketStatus.inProgress => const TicketStatusColors(
      background: Color(0xFFE4E7F5),
      foreground: AppColors.deepBlue,
      icon: Icons.build_circle_outlined,
    ),
    TicketStatus.waitingConfirmation => const TicketStatusColors(
      background: Color(0xFFEDE3FF),
      foreground: Color(0xFF6D28D9),
      icon: Icons.rate_review_outlined,
    ),
    TicketStatus.completed => const TicketStatusColors(
      background: Color(0xFFD6F7E1),
      foreground: Color(0xFF138A42),
      icon: Icons.check_circle_outline_rounded,
    ),
    TicketStatus.rejected => const TicketStatusColors(
      background: Color(0xFFFFDAD7),
      foreground: Color(0xFFC8171F),
      icon: Icons.cancel_outlined,
    ),
    TicketStatus.cancelled => const TicketStatusColors(
      background: Color(0xFFE7E9F0),
      foreground: Color(0xFF4B5563),
      icon: Icons.block_rounded,
    ),
  };
}
