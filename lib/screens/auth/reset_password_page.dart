import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/services/auth/forgot_password_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/auth_text_field.dart';
import 'package:hdbhms_mobile/screens/auth/login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.token, // Received from magic link
    this.forgotPasswordService = const ForgotPasswordService(),
  });

  final String? token;
  final ForgotPasswordService forgotPasswordService;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tokenController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize token from the widget parameter (if provided via deep link)
    _tokenController = TextEditingController(text: widget.token);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('Vui lòng kiểm tra các trường bắt buộc');
      return;
    }
    final token = _tokenController.text.trim();
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (token.isEmpty) {
      _showMessage('Mã xác minh không hợp lệ hoặc đã hết hạn');
      return;
    }

    final validationMessage = _validate(newPassword, confirmPassword);
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.forgotPasswordService.resetPassword(
        token: token,
        newPassword: newPassword,
      );

      if (!mounted) return;

      _showMessage('Đặt lại mật khẩu thành công! Vui lòng đăng nhập lại.');

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      });
    } on ForgotPasswordException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validate(String newPassword, String confirmPassword) {
    if (newPassword.isEmpty) return 'Vui lòng nhập mật khẩu mới';
    if (newPassword.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
    if (!RegExp(r'[a-zA-Z]').hasMatch(newPassword)) {
      return 'Mật khẩu phải có ít nhất một chữ cái';
    }
    if (!RegExp(r'\d').hasMatch(newPassword)) {
      return 'Mật khẩu phải có ít nhất một chữ số';
    }
    if (confirmPassword.isEmpty) return 'Vui lòng xác nhận mật khẩu';
    if (newPassword != confirmPassword) return 'Mật khẩu xác nhận không khớp';
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đặt lại mật khẩu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppColors.radiusLg),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Thiết lập mật khẩu mới',
                    style: AppTypography.pageTitle,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vui lòng nhập mật khẩu mới của bạn bên dưới để hoàn tất quá trình khôi phục.',
                    style: AppTypography.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  // Hide the token field if it's already provided, else show it for manual entry
                  if (widget.token == null || widget.token!.isEmpty) ...[
                    AuthTextField(
                      label: 'Mã xác minh',
                      hintText: 'Dán mã xác minh từ email',
                      controller: _tokenController,
                      icon: Icons.key_outlined,
                      required: true,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập mã xác minh'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  AuthTextField(
                    label: 'Mật khẩu mới',
                    hintText: 'Ít nhất 8 ký tự',
                    controller: _passwordController,
                    obscureText: true,
                    icon: Icons.lock_outline,
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
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleResetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusLg,
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'ĐẶT LẠI MẬT KHẨU',
                              style: AppTypography.button,
                            ),
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
