import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/screens/auth/forgot_password_code_page.dart';
import 'package:hdbhms_mobile/services/auth/forgot_password_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/auth_inline_message.dart';
import 'package:hdbhms_mobile/widgets/auth_text_field.dart';

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
  String? _requestError;

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

  Future<void> _sendResetRequest() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final identity = _identityController.text.trim();
    if (identity.isEmpty) return;

    setState(() {
      _isSending = true;
      _requestError = null;
    });

    try {
      await widget.forgotPasswordService.requestResetPassword(identity);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ForgotPasswordCodePage(
            identity: identity,
            forgotPasswordService: widget.forgotPasswordService,
          ),
        ),
      );
    } on ForgotPasswordException catch (error) {
      if (mounted) setState(() => _requestError = error.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: AppTopBar(
            title: 'Quên mật khẩu',
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
                    Icons.lock_reset_outlined,
                    key: Key('forgot-password-intro-icon'),
                    color: AppColors.primary,
                    size: 34,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Khôi phục mật khẩu',
                    style: AppTypography.pageTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nhập email hoặc số điện thoại đã đăng ký. Chúng tôi sẽ gửi mã xác minh để bạn tiếp tục.',
                    style: AppTypography.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  AuthTextField(
                    label: 'Email hoặc số điện thoại',
                    hintText: 'Nhập thông tin đã đăng ký',
                    icon: Icons.contact_mail_outlined,
                    controller: _identityController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    hintColor: AppColors.hintText,
                    uppercaseLabel: false,
                    required: true,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Vui lòng nhập email hoặc số điện thoại'
                        : null,
                  ),
                  if (_requestError != null) ...[
                    const SizedBox(height: 12),
                    AuthInlineMessage(message: _requestError!),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryGradientButton(
                      key: const Key('forgot-password-send-code'),
                      height: 52,
                      borderRadius: AppColors.radiusMd,
                      onPressed: _isSending ? null : _sendResetRequest,
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Gửi mã xác minh'),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 19),
                                ],
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
    );
  }
}
