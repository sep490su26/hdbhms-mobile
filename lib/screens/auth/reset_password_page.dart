import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/screens/auth/forgot_password_page.dart';
import 'package:hdbhms_mobile/screens/auth/password_reset_success_page.dart';
import 'package:hdbhms_mobile/services/auth/forgot_password_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/auth_text_field.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.token,
    this.forgotPasswordService = const ForgotPasswordService(),
  });

  final String? token;
  final ForgotPasswordService forgotPasswordService;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _isLoading = false;
  String? _submissionError;
  bool _isInvalidToken = false;

  bool get _hasToken => widget.token?.trim().isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    if (!_hasToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
        );
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = widget.token?.trim();
    if (token == null || token.isEmpty) return;

    setState(() {
      _isLoading = true;
      _submissionError = null;
      _isInvalidToken = false;
    });

    try {
      await widget.forgotPasswordService.resetPassword(
        token: token,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const PasswordResetSuccessPage(),
        ),
        (route) => false,
      );
    } on ForgotPasswordException catch (error) {
      if (!mounted) return;
      final message = error.message;
      final normalized = message.toLowerCase();
      final isInvalidToken =
          normalized.contains('token') ||
          normalized.contains('mã') ||
          normalized.contains('ma ') ||
          normalized.contains('hết hạn') ||
          normalized.contains('expired');
      setState(() {
        _submissionError = isInvalidToken
            ? 'Mã xác minh không hợp lệ hoặc đã hết hạn. Vui lòng nhập lại mã.'
            : message;
        _isInvalidToken = isInvalidToken;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _enterCodeAgain() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasToken) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.deepBlue),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: AppTopBar(
            title: 'Đặt lại mật khẩu',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.deepBlue,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Thiết lập mật khẩu mới',
                    style: AppTypography.pageTitle,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mật khẩu cần có ít nhất 8 ký tự, gồm chữ cái và chữ số.',
                    style: AppTypography.bodyLarge,
                  ),
                  if (_submissionError != null) ...[
                    const SizedBox(height: 20),
                    _ResetErrorCard(
                      message: _submissionError!,
                      showRetryCode: _isInvalidToken,
                      onRetryCode: _enterCodeAgain,
                    ),
                  ],
                  const SizedBox(height: 28),
                  AuthTextField(
                    label: 'Mật khẩu mới',
                    hintText: 'Ít nhất 8 ký tự',
                    controller: _passwordController,
                    obscureText: true,
                    icon: Icons.lock_outline,
                    uppercaseLabel: false,
                    required: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu mới';
                      }
                      if (value.length < 8) {
                        return 'Mật khẩu phải có ít nhất 8 ký tự';
                      }
                      if (!RegExp(r'[a-zA-Z]').hasMatch(value) ||
                          !RegExp(r'\d').hasMatch(value)) {
                        return 'Mật khẩu cần có chữ cái và chữ số';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    label: 'Xác nhận mật khẩu',
                    hintText: 'Nhập lại mật khẩu mới',
                    controller: _confirmPasswordController,
                    obscureText: true,
                    icon: Icons.lock_reset_outlined,
                    textInputAction: TextInputAction.done,
                    uppercaseLabel: false,
                    required: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng xác nhận mật khẩu';
                      }
                      return value != _passwordController.text
                          ? 'Mật khẩu xác nhận không khớp'
                          : null;
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryGradientButton(
                      key: const Key('reset-password-submit'),
                      height: 52,
                      borderRadius: AppColors.radiusMd,
                      onPressed: _isLoading ? null : _handleResetPassword,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Đặt lại mật khẩu'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetErrorCard extends StatelessWidget {
  const _ResetErrorCard({
    required this.message,
    required this.showRetryCode,
    required this.onRetryCode,
  });

  final String message;
  final bool showRetryCode;
  final VoidCallback onRetryCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.body.copyWith(
                    color: AppColors.dangerText,
                  ),
                ),
              ),
            ],
          ),
          if (showRetryCode) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetryCode,
              icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
              label: const Text('Nhập lại mã'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.dangerText,
                minimumSize: const Size(0, AppColors.minimumTouchTarget),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
