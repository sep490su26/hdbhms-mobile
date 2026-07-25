import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/services/auth/forgot_password_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/auth_text_field.dart';
import 'package:hdbhms_mobile/screens/auth/reset_password_page.dart';

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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identityController;
  bool _isSending = false;
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    _identityController = TextEditingController();
  }

  @override
  void dispose() {
    _identityController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('Vui lòng hoàn thành trường bắt buộc');
      return;
    }
    final identity = _identityController.text.trim();
    if (identity.isEmpty) {
      _showMessage('Vui lòng nhập email hoặc số điện thoại');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await widget.forgotPasswordService.requestResetPassword(identity);
      if (!mounted) {
        return;
      }
      _showMessage(
        'Yêu cầu thành công! Vui lòng kiểm tra email hoặc tin nhắn.',
      );
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
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ForgotPasswordIntro(),
                          const SizedBox(height: 32),
                          Form(
                            key: _formKey,
                            child: AuthTextField(
                              label: 'Email hoặc số điện thoại',
                              hintText: 'Nhập thông tin của bạn',
                              icon: Icons.contact_mail_outlined,
                              controller: _identityController,
                              keyboardType: TextInputType.text,
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
                              required: true,
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Vui lòng nhập email hoặc số điện thoại'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: (_isSending || _emailSent)
                                  ? null
                                  : _sendOtp,
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
                                      _emailSent
                                          ? 'ĐÃ GỬI YÊU CẦU'
                                          : 'GỬI MÃ OTP',
                                      style: AppTypography.button,
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.05,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          if (_emailSent) ...[
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ResetPasswordPage(),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'NHẬP MÃ XÁC MINH',
                                  style: AppTypography.button.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            _SuccessMessage(
                              identity: _identityController.text.trim(),
                            ),
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
      color: AppColors.surface,
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
                color: AppColors.topBarIconColor,
                size: AppColors.topBarIconSize,
              ),
              tooltip: 'Quay lại',
            ),
          ),
          const Expanded(
            child: Text('Quên mật khẩu', style: AppColors.topBarTitleStyle),
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
            style: AppTypography.pageTitle,
          ),
          SizedBox(height: 8),
          Text(
            'Vui lòng nhập email hoặc số điện thoại đã\nđăng ký để nhận mã OTP xác minh.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _SuccessMessage extends StatelessWidget {
  const _SuccessMessage({required this.identity});

  final String identity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.primary,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Kiểm tra thông tin của bạn',
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: 8),
          Text(
            'Chúng tôi đã gửi mã đặt lại mật khẩu đến:',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.bodyText.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            identity,
            style: const TextStyle(
              color: AppColors.primary,
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
