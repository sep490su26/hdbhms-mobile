import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/utils/user_facing_error_message.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';

class RequestSectionHeader extends StatelessWidget {
  const RequestSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.description_outlined,
    this.accentColor = AppColors.primary,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppColors.space12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      border: Border.all(color: AppColors.cardBorder),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: .045),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        const SizedBox(width: AppColors.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.sectionTitle.copyWith(fontSize: 20),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppColors.space4),
                Text(
                  subtitle!,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class RequestFormSection extends StatelessWidget {
  const RequestFormSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.accentColor = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Color accentColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppColors.space16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: AppColors.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.cardTitle.copyWith(fontSize: 15),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppColors.space4),
                    Text(
                      subtitle!,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppColors.space8),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: AppColors.space16),
        child,
      ],
    ),
  );
}

class RequestNoticeCard extends StatelessWidget {
  const RequestNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accentColor = AppColors.actionCyan,
    this.surfaceColor = AppColors.infoSurface,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accentColor;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppColors.space12),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      border: Border.all(color: accentColor.withValues(alpha: .18)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Icon(icon, color: accentColor, size: 19),
        ),
        const SizedBox(width: AppColors.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppColors.space4),
              Text(
                message,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class RequestFieldLabel extends StatelessWidget {
  const RequestFieldLabel({
    super.key,
    required this.label,
    this.required = false,
  });

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: label,
      style: AppTypography.label,
      children: [
        if (required)
          TextSpan(
            text: ' *',
            style: AppTypography.label.copyWith(color: AppColors.danger),
          ),
      ],
    ),
  );
}

class RequestErrorBanner extends StatelessWidget {
  const RequestErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppColors.space12),
    decoration: BoxDecoration(
      color: AppColors.dangerSurface,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.dangerText,
          size: 18,
        ),
        const SizedBox(width: AppColors.space8),
        Expanded(
          child: Text(
            toUserFacingMessage(message),
            style: AppTypography.body.copyWith(color: AppColors.dangerText),
          ),
        ),
      ],
    ),
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
        Expanded(child: Text(label, style: AppTypography.metaLabel)),
        const SizedBox(width: AppColors.space16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            style: AppTypography.metaValue.copyWith(
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
    this.startDate,
    this.monthlyRent,
  });

  final String room;
  final String contractCode;
  final String expiry;
  final String? startDate;
  final String? monthlyRent;

  @override
  Widget build(BuildContext context) => RequestFormSection(
    icon: Icons.description_outlined,
    title: 'Hợp đồng hiện tại',
    accentColor: AppColors.actionBlue,
    child: LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: AppColors.space16,
        runSpacing: AppColors.space12,
        children:
            [
                  _SummaryMetric(label: 'Phòng hiện tại', value: room),
                  _SummaryMetric(label: 'Mã hợp đồng', value: contractCode),
                  if (startDate != null)
                    _SummaryMetric(label: 'Ngày bắt đầu', value: startDate!),
                  _SummaryMetric(label: 'Ngày hết hạn', value: expiry),
                  if (monthlyRent != null)
                    _SummaryMetric(label: 'Giá hiện tại', value: monthlyRent!),
                ]
                .map(
                  (metric) => SizedBox(
                    width: constraints.maxWidth >= 340
                        ? (constraints.maxWidth - AppColors.space16) / 2
                        : constraints.maxWidth,
                    child: metric,
                  ),
                )
                .toList(growable: false),
      ),
    ),
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTypography.metaLabel),
      const SizedBox(height: AppColors.space4),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.fade,
        style: AppTypography.metaValue,
      ),
    ],
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
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.cardBorder)),
    ),
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
            AppColors.space16,
            AppColors.space16,
            AppColors.space24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: child,
        ),
      ),
      action,
    ],
  );
}

Future<void> showRequestSuccessSheet(
  BuildContext context, {
  required String message,
  required VoidCallback onReturnToContract,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: AppColors.deepBlue.withValues(alpha: .48),
  builder: (dialogContext) => PopScope(
    canPop: false,
    child: RequestSuccessSheet(
      message: message,
      onViewRequests: () {
        Navigator.of(dialogContext, rootNavigator: true).pop();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TenantRequestScreen()),
        );
      },
      onReturnToContract: () {
        Navigator.of(dialogContext, rootNavigator: true).pop();
        onReturnToContract();
      },
    ),
  ),
);

Future<void> showAppAnimatedSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String primaryLabel,
  required VoidCallback onPrimary,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: AppColors.deepBlue.withValues(alpha: .48),
  builder: (dialogContext) => PopScope(
    canPop: false,
    child: AppAnimatedSuccessDialog(
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      onPrimary: () {
        Navigator.of(dialogContext, rootNavigator: true).pop();
        onPrimary();
      },
    ),
  ),
);

/// Shared terminal-success language used by request forms and onboarding.
///
/// It deliberately starts immediately when reduced motion is enabled, and only
/// triggers one haptic impact for the lifetime of an opened dialog.
class AppAnimatedSuccessDialog extends StatefulWidget {
  const AppAnimatedSuccessDialog({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  State<AppAnimatedSuccessDialog> createState() =>
      _AppAnimatedSuccessDialogState();
}

class _AppAnimatedSuccessDialogState extends State<AppAnimatedSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    _controller.duration = reducedMotion
        ? const Duration(milliseconds: 1)
        : const Duration(milliseconds: 720);
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
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 22),
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 356),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepBlue.withValues(alpha: .2),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final titleProgress = CurvedAnimation(
              parent: _controller,
              curve: const Interval(.40, .74, curve: Curves.easeOut),
            );
            final actionProgress = CurvedAnimation(
              parent: _controller,
              curve: const Interval(.64, 1, curve: Curves.easeOut),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0, .44, curve: Curves.easeOutBack),
                  ),
                  child: AnimatedSuccessMark(progress: _controller.value),
                ),
                const SizedBox(height: AppColors.space16),
                FadeTransition(
                  opacity: titleProgress,
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: AppTypography.sectionTitle.copyWith(fontSize: 20),
                  ),
                ),
                const SizedBox(height: AppColors.space8),
                FadeTransition(
                  opacity: titleProgress,
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppColors.space24),
                FadeTransition(
                  opacity: actionProgress,
                  child: SizedBox(
                    width: double.infinity,
                    child: AppPrimaryGradientButton(
                      height: 50,
                      onPressed: widget.onPrimary,
                      child: Text(widget.primaryLabel),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

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
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 22),
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 356),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepBlue.withValues(alpha: .2),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _circleScale,
                child: FadeTransition(
                  opacity: _circleScale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedSuccessMark(progress: _controller.value),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppColors.space16),
              FadeTransition(
                opacity: _titleOpacity,
                child: SlideTransition(
                  position: _titleOffset,
                  child: Text(
                    'Gửi yêu cầu thành công',
                    textAlign: TextAlign.center,
                    style: AppTypography.sectionTitle.copyWith(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(height: AppColors.space8),
              FadeTransition(
                opacity: _detailOpacity,
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppColors.space12),
              FadeTransition(
                opacity: _detailOpacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  ),
                  child: Text(
                    'Chờ quản lý xét duyệt',
                    style: AppTypography.metaLabel.copyWith(
                      color: AppColors.successText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppColors.space24),
              FadeTransition(
                opacity: _actionsOpacity,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: AppPrimaryGradientButton(
                        height: 52,
                        onPressed: widget.onViewRequests,
                        child: const Text('Xem các yêu cầu'),
                      ),
                    ),
                    const SizedBox(height: AppColors.space8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
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
    ),
  );
}

class AnimatedSuccessMark extends StatelessWidget {
  const AnimatedSuccessMark({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      _SuccessRing(progress: progress, multiplier: 1.45),
      _SuccessRing(progress: progress, multiplier: 1.82),
      Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.successSurface,
          shape: BoxShape.circle,
        ),
        child: CustomPaint(
          painter: _TickPainter(((progress - .18) / .54).clamp(0, 1)),
        ),
      ),
    ],
  );
}

class _SuccessRing extends StatelessWidget {
  const _SuccessRing({required this.progress, required this.multiplier});

  final double progress;
  final double multiplier;

  @override
  Widget build(BuildContext context) {
    final value = Curves.easeOut.transform((progress / .62).clamp(0, 1));
    return Opacity(
      opacity: (1 - value) * .42,
      child: Container(
        width: 64 * (1 + (multiplier - 1) * value),
        height: 64 * (1 + (multiplier - 1) * value),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.success.withValues(alpha: .55)),
        ),
      ),
    );
  }
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
