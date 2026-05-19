import 'package:flutter/material.dart';

import '../services/forgot_password_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_text_field.dart';
import 'forgot_password_otp_screen.dart';

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
      await widget.forgotPasswordService.sendForgotPasswordOtp(email);
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ForgotPasswordOtpScreen(
            email: email,
            forgotPasswordService: widget.forgotPasswordService,
          ),
        ),
      );
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
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton.icon(
                              onPressed: _isSending ? null : _sendOtp,
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
                                  : const Text(
                                      'GỬI MÃ OTP',
                                      style: TextStyle(
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
          SizedBox(height: 8),
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
