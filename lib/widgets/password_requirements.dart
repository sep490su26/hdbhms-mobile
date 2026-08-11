import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';

class PasswordRequirementRule {
  const PasswordRequirementRule({required this.label, required this.isMet});

  final String label;
  final bool Function(String password) isMet;
}

/// Live password guidance that mirrors the validator supplied by each flow.
class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({
    super.key,
    required this.passwordController,
    required this.rules,
    this.title = 'Yêu cầu mật khẩu',
  });

  final TextEditingController passwordController;
  final List<PasswordRequirementRule> rules;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: passwordController,
      builder: (context, value, child) {
        final password = value.text;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.requirementBackground,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.label),
              const SizedBox(height: 8),
              for (var index = 0; index < rules.length; index++) ...[
                _PasswordRequirementItem(
                  label: rules[index].label,
                  isMet: rules[index].isMet(password),
                ),
                if (index != rules.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PasswordRequirementItem extends StatelessWidget {
  const _PasswordRequirementItem({required this.label, required this.isMet});

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet ? AppColors.successText : AppColors.bodyText;
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
