import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';

enum AuthInlineMessageKind { error, success, info }

/// Compact contextual feedback for the staged authentication flows.
class AuthInlineMessage extends StatelessWidget {
  const AuthInlineMessage({
    super.key,
    required this.message,
    this.kind = AuthInlineMessageKind.error,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AuthInlineMessageKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  Color get _color => switch (kind) {
    AuthInlineMessageKind.error => AppColors.dangerText,
    AuthInlineMessageKind.success => AppColors.successText,
    AuthInlineMessageKind.info => AppColors.primary,
  };

  IconData get _icon => switch (kind) {
    AuthInlineMessageKind.error => Icons.error_outline_rounded,
    AuthInlineMessageKind.success => Icons.check_circle_outline_rounded,
    AuthInlineMessageKind.info => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_icon, color: _color, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              Text(
                message,
                style: AppTypography.caption.copyWith(color: _color),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: _color,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel!,
                    style: AppTypography.caption.copyWith(
                      color: _color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
