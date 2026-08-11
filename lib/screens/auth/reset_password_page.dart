import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/screens/auth/forgot_password_code_page.dart';
import 'package:hdbhms_mobile/screens/auth/forgot_password_page.dart';
import 'package:hdbhms_mobile/screens/auth/password_reset_success_page.dart';
import 'package:hdbhms_mobile/services/auth/forgot_password_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/auth_inline_message.dart';
import 'package:hdbhms_mobile/widgets/auth_text_field.dart';
import 'package:hdbhms_mobile/widgets/password_requirements.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.token,
    this.identity,
    this.forgotPasswordService = const ForgotPasswordService(),
  });

  final String? token;
  final String? identity;
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
  bool get _hasIdentity => widget.identity?.trim().isNotEmpty ?? false;

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
            ? 'Mã xác minh không hợp lệ hoặc đã hết hạn.'
            : message;
        _isInvalidToken = isInvalidToken;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _recoverInvalidToken() {
    if (_hasIdentity) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ForgotPasswordCodePage(
            identity: widget.identity!,
            forgotPasswordService: widget.forgotPasswordService,
          ),
        ),
      );
      return;
    }
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    key: Key('reset-password-intro-icon'),
                    color: AppColors.primary,
                    size: 34,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Thiết lập mật khẩu mới',
                    style: AppTypography.pageTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mật khẩu cần có ít nhất 8 ký tự, gồm chữ cái và chữ số.',
                    style: AppTypography.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (_submissionError != null) ...[
                    const SizedBox(height: 16),
                    AuthInlineMessage(
                      message: _submissionError!,
                      actionLabel: _isInvalidToken
                          ? (_hasIdentity ? 'Nhập mã khác' : 'Yêu cầu mã mới')
                          : null,
                      onAction: _isInvalidToken ? _recoverInvalidToken : null,
                    ),
                  ],
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 12),
                  PasswordRequirements(
                    passwordController: _passwordController,
                    rules: [
                      PasswordRequirementRule(
                        label: 'Tối thiểu 8 ký tự',
                        isMet: (password) => password.length >= 8,
                      ),
                      PasswordRequirementRule(
                        label: 'Có ít nhất một chữ cái',
                        isMet: (password) =>
                            RegExp(r'[a-zA-Z]').hasMatch(password),
                      ),
                      PasswordRequirementRule(
                        label: 'Có ít nhất một chữ số',
                        isMet: (password) => RegExp(r'\d').hasMatch(password),
                      ),
                    ],
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
