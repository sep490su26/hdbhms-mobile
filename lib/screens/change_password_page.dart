import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/auth_text_field.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ChangePasswordHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ChangePasswordIntro(),
                          const SizedBox(height: 32),
                          _ChangePasswordFormCard(
                            passwordController: _passwordController,
                            confirmPasswordController:
                                _confirmPasswordController,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordHeader extends StatelessWidget {
  const _ChangePasswordHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 16, 136, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.deepBlue,
                size: 22,
              ),
              tooltip: 'Quay lại',
            ),
          ),
          const Text(
            'Đổi mật khẩu',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 28 / 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordIntro extends StatelessWidget {
  const _ChangePasswordIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thiết lập mật khẩu mới',
          style: TextStyle(
            color: AppColors.inputText,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 32 / 26,
            letterSpacing: -0.52,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Mật khẩu mới của bạn phải khác với mật khẩu\nđã sử dụng trước đó.',
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 24 / 16,
          ),
        ),
      ],
    );
  }
}

class _ChangePasswordFormCard extends StatelessWidget {
  const _ChangePasswordFormCard({
    required this.passwordController,
    required this.confirmPasswordController,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 25, 25, 41),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthTextField(
            label: 'Mật khẩu mới',
            hintText: 'Nhập mật khẩu mới',
            controller: passwordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            hintColor: AppColors.hintText,
            contentPadding: const EdgeInsets.fromLTRB(17, 18, 48, 18),
            uppercaseLabel: false,
          ),
          const SizedBox(height: 24),
          AuthTextField(
            label: 'Xác nhận mật khẩu',
            hintText: 'Nhập lại mật khẩu',
            controller: confirmPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            hintColor: AppColors.hintText,
            contentPadding: const EdgeInsets.fromLTRB(17, 18, 48, 18),
            uppercaseLabel: false,
          ),
          const SizedBox(height: 24),
          const _PasswordRequirements(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'ĐỔI MẬT KHẨU',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 28 / 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.requirementBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yêu cầu mật khẩu:',
            style: TextStyle(
              color: AppColors.inputText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 16 / 12,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 8),
          _RequirementItem(
            text: 'Tối thiểu 8 ký tự',
            isComplete: true,
            textColor: AppColors.inputText,
          ),
          SizedBox(height: 8),
          _RequirementItem(text: 'Ít nhất một chữ cái in hoa'),
          SizedBox(height: 8),
          _RequirementItem(text: 'Ít nhất một số hoặc ký tự đặc biệt'),
        ],
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  const _RequirementItem({
    required this.text,
    this.isComplete = false,
    this.textColor = AppColors.bodyText,
  });

  final String text;
  final bool isComplete;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isComplete ? Icons.check_circle : Icons.circle_outlined,
          color: isComplete ? AppColors.deepBlue : AppColors.cardBorder,
          size: 15,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 20 / 14,
            ),
          ),
        ),
      ],
    );
  }
}
