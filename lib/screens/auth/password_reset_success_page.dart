import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/screens/auth/login_page.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';

class PasswordResetSuccessPage extends StatelessWidget {
  const PasswordResetSuccessPage({super.key});

  void _goToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: AppScreenShell(
            header: const AppTopBar(title: 'Khôi phục mật khẩu'),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        color: AppColors.successSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.successText,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Đặt lại mật khẩu thành công',
                      textAlign: TextAlign.center,
                      style: AppTypography.pageTitle,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Mật khẩu mới đã được lưu. Hãy đăng nhập lại để tiếp tục sử dụng ứng dụng.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: AppPrimaryGradientButton(
                        key: const Key('password-reset-success-login'),
                        height: 52,
                        borderRadius: AppColors.radiusMd,
                        onPressed: () => _goToLogin(context),
                        child: const Text('Đăng nhập'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
