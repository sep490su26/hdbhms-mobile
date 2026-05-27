import 'package:flutter/material.dart';

import '../services/forgot_password_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.forgotPasswordService = const ForgotPasswordService(),
  });

  final ForgotPasswordService forgotPasswordService;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController _emailController;
  bool _isSending = false;
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Vui lòng nhập email');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await widget.forgotPasswordService.requestResetPassword(email);
      if (!mounted) {
        return;
      }
      _showMessage('Đã gửi liên kết đặt lại mật khẩu! Vui lòng kiểm tra email.');
      setState(() {
        _emailSent = true;
      });
    } on ForgotPasswordException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
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
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ForgotPasswordHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 159),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ForgotPasswordIntro(),
                          const SizedBox(height: 32),
                          AuthTextField(
                            label: 'Email',
                            hintText: 'Nhập thông tin của bạn',
                            icon: Icons.contact_mail_outlined,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            hintColor: AppColors.hintText,
                            contentPadding: const EdgeInsets.fromLTRB(
                              49,
                              19,
                              17,
                              19,
                            ),
                            prefixIconSize: 24,
                            enabled: !_emailSent,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton.icon(
                              onPressed: (_isSending || _emailSent) ? null : _sendOtp,
                              iconAlignment: IconAlignment.end,
                              icon: _isSending
                                  ? const SizedBox.shrink()
                                  : const Icon(
                                      Icons.send_outlined,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                              label: _isSending
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _emailSent ? 'ĐÃ GỬI LIÊN KẾT' : 'GỬI MÃ OTP',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        height: 28 / 20,
                                      ),
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.darkBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.05,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          if (_emailSent) ...[
                            const SizedBox(height: 32),
                            _SuccessMessage(email: _emailController.text.trim()),
                          ],
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

class _ForgotPasswordHeader extends StatelessWidget {
  const _ForgotPasswordHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 16, 56, 16),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.inputText,
                size: 22,
              ),
              tooltip: 'Quay lại',
            ),
          ),
          const Expanded(
            child: Text(
              'QUÊN MẬT KHẨU',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 16 / 12,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForgotPasswordIntro extends StatelessWidget {
  const _ForgotPasswordIntro();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          Text(
            'Quên mật khẩu?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 32 / 26,
              letterSpacing: -0.52,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng nhập email đã\nđăng ký để nhận mã OTP xác minh.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 24 / 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessMessage extends StatelessWidget {
  const _SuccessMessage({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.deepBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.deepBlue.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.deepBlue,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Kiểm tra email của bạn',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chúng tôi đã gửi một liên kết đặt lại mật khẩu đến email:',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.bodyText.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Vui lòng nhấn vào liên kết trong email để tiếp tục.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
