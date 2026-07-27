import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
import 'package:hdbhms_mobile/widgets/section_card.dart';

class RequestSectionHeader extends StatelessWidget {
  const RequestSectionHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppTypography.sectionTitle),
      if (subtitle != null) ...[
        const SizedBox(height: AppColors.space4),
        Text(subtitle!, style: AppTypography.body),
      ],
    ],
  );
}

class RequestReadOnlyRow extends StatelessWidget {
  const RequestReadOnlyRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppColors.space4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppTypography.body)),
        const SizedBox(width: AppColors.space16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTypography.label.copyWith(
              color: valueColor ?? AppColors.inputText,
            ),
          ),
        ),
      ],
    ),
  );
}

class RequestContractSummaryCard extends StatelessWidget {
  const RequestContractSummaryCard({
    super.key,
    required this.room,
    required this.contractCode,
    required this.expiry,
    this.monthlyRent,
  });

  final String room;
  final String contractCode;
  final String expiry;
  final String? monthlyRent;

  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.all(AppColors.space16),
    child: Column(
      children: [
        RequestReadOnlyRow(label: 'Phòng hiện tại', value: room),
        const Divider(),
        RequestReadOnlyRow(label: 'Mã hợp đồng', value: contractCode),
        const Divider(),
        RequestReadOnlyRow(label: 'Ngày hết hạn', value: expiry),
        if (monthlyRent != null) ...[
          const Divider(),
          RequestReadOnlyRow(label: 'Giá hiện tại', value: monthlyRent!),
        ],
      ],
    ),
  );
}

class StickyRequestAction extends StatelessWidget {
  const StickyRequestAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surface,
    padding: EdgeInsets.fromLTRB(
      AppColors.space16,
      AppColors.space12,
      AppColors.space16,
      AppColors.space12 + MediaQuery.paddingOf(context).bottom,
    ),
    child: AppPrimaryGradientButton(
      height: 52,
      onPressed: isLoading ? null : onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppColors.space8),
          ],
          Text(
            isLoading ? 'Đang gửi yêu cầu...' : label,
            style: AppTypography.button.copyWith(color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

class RequestFormScaffold extends StatelessWidget {
  const RequestFormScaffold({
    super.key,
    required this.child,
    required this.action,
  });

  final Widget child;
  final Widget action;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppColors.space16,
            AppColors.space24,
            AppColors.space16,
            AppColors.space24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: child,
        ),
      ),
      const Divider(height: 1),
      action,
    ],
  );
}

Future<void> showRequestSuccessSheet(
  BuildContext context, {
  required String message,
  required VoidCallback onReturnToContract,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => RequestSuccessSheet(
    message: message,
    onViewRequests: () {
      Navigator.of(context).pop();
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const TenantRequestScreen()));
    },
    onReturnToContract: () {
      Navigator.of(context).pop();
      onReturnToContract();
    },
  ),
);

class RequestSuccessSheet extends StatefulWidget {
  const RequestSuccessSheet({
    super.key,
    required this.message,
    required this.onViewRequests,
    required this.onReturnToContract,
  });

  final String message;
  final VoidCallback onViewRequests;
  final VoidCallback onReturnToContract;

  @override
  State<RequestSuccessSheet> createState() => _RequestSuccessSheetState();
}

class _RequestSuccessSheetState extends State<RequestSuccessSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _circleScale;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleOffset;
  late final Animation<double> _detailOpacity;
  late final Animation<double> _actionsOpacity;

  @override
  void initState() {
    super.initState();
    final reducedMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _controller = AnimationController(
      vsync: this,
      duration: reducedMotion
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 900),
    );
    _circleScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .42, curve: Curves.easeOutBack),
    );
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.48, .76, curve: Curves.easeOut),
    );
    _titleOffset = Tween<Offset>(begin: const Offset(0, .18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(.48, .78, curve: Curves.easeOutCubic),
          ),
        );
    _detailOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.62, .88, curve: Curves.easeOut),
    );
    _actionsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.72, 1, curve: Curves.easeOut),
    );
    _controller.forward();
    if (!reducedMotion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) HapticFeedback.lightImpact();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppColors.radiusLg),
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
              ),
            ),
            const SizedBox(height: AppColors.space24),
            ScaleTransition(
              scale: _circleScale,
              child: FadeTransition(
                opacity: _circleScale,
                child: _SuccessTick(progress: _tickProgress),
              ),
            ),
            const SizedBox(height: AppColors.space16),
            FadeTransition(
              opacity: _titleOpacity,
              child: SlideTransition(
                position: _titleOffset,
                child: Text(
                  'Đã gửi yêu cầu',
                  style: AppTypography.sectionTitle,
                ),
              ),
            ),
            const SizedBox(height: AppColors.space8),
            FadeTransition(
              opacity: _detailOpacity,
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
            ),
            const SizedBox(height: AppColors.space24),
            FadeTransition(
              opacity: _actionsOpacity,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onViewRequests,
                      child: const Text('Xem các yêu cầu'),
                    ),
                  ),
                  const SizedBox(height: AppColors.space8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: widget.onReturnToContract,
                      child: const Text('Quay lại hợp đồng'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  double get _tickProgress => ((_controller.value - .18) / .54).clamp(0, 1);
}

class _SuccessTick extends StatelessWidget {
  const _SuccessTick({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: const BoxDecoration(
      color: AppColors.successSurface,
      shape: BoxShape.circle,
    ),
    child: CustomPaint(painter: _TickPainter(progress)),
  );
}

class _TickPainter extends CustomPainter {
  const _TickPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final first = Offset(size.width * .28, size.height * .52);
    final middle = Offset(size.width * .45, size.height * .68);
    final last = Offset(size.width * .75, size.height * .34);
    final fullLength = (middle - first).distance + (last - middle).distance;
    final path = Path()..moveTo(first.dx, first.dy);
    final drawLength = fullLength * progress;
    final firstLength = (middle - first).distance;
    if (drawLength <= firstLength) {
      final point = Offset.lerp(first, middle, drawLength / firstLength)!;
      path.lineTo(point.dx, point.dy);
    } else {
      path.lineTo(middle.dx, middle.dy);
      final point = Offset.lerp(
        middle,
        last,
        (drawLength - firstLength) / (fullLength - firstLength),
      )!;
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.successText
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
