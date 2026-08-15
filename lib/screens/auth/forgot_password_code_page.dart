import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/screens/auth/reset_password_page.dart';
import 'package:hdbhms_mobile/services/auth/forgot_password_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/auth_inline_message.dart';
import 'package:hdbhms_mobile/widgets/otp_input_boxes.dart';

class ForgotPasswordCodePage extends StatefulWidget {
  const ForgotPasswordCodePage({
    super.key,
    required this.identity,
    this.forgotPasswordService = const ForgotPasswordService(),
    this.initialResendSeconds = 60,
  });

  final String identity;
  final ForgotPasswordService forgotPasswordService;
  final int initialResendSeconds;

  @override
  State<ForgotPasswordCodePage> createState() => _ForgotPasswordCodePageState();
}

class _ForgotPasswordCodePageState extends State<ForgotPasswordCodePage> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  Timer? _cooldownTimer;
  Timer? _successMessageTimer;
  late int _secondsRemaining;
  bool _isResending = false;
  String? _codeError;
  String? _resendMessage;
  String? _resendError;

  String get _code => _controllers.map((controller) => controller.text).join();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    _secondsRemaining = widget.initialResendSeconds;
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _successMessageTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    if (_secondsRemaining <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  void _continueToReset() {
    final code = _code;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _codeError = 'Vui lòng nhập đủ 6 chữ số.');
      return;
    }

    setState(() => _codeError = null);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ResetPasswordPage(
          token: code,
          identity: widget.identity,
          forgotPasswordService: widget.forgotPasswordService,
        ),
      ),
    );
  }

  Future<void> _resendCode() async {
    if (_isResending || _secondsRemaining > 0) return;

    setState(() {
      _isResending = true;
      _resendMessage = null;
      _resendError = null;
      _codeError = null;
    });

    try {
      await widget.forgotPasswordService.requestResetPassword(widget.identity);
      if (!mounted) return;
      setState(() {
        _resendMessage = 'Đã gửi lại mã xác minh.';
        _secondsRemaining = 60;
      });
      _successMessageTimer?.cancel();
      if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
        _successMessageTimer = Timer(const Duration(milliseconds: 2800), () {
          if (mounted) setState(() => _resendMessage = null);
        });
      }
      _startCooldown();
    } on ForgotPasswordException catch (error) {
      if (mounted) setState(() => _resendError = error.message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String get _cooldownLabel {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: AppTopBar(
            title: 'Xác minh mã',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  key: Key('forgot-password-code-intro-icon'),
                  color: AppColors.primary,
                  size: 34,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Nhập mã xác minh',
                  style: AppTypography.pageTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: AppTypography.bodyLarge,
                    children: [
                      const TextSpan(
                        text: 'Mã gồm 6 chữ số đã được gửi cho tài khoản\n',
                      ),
                      TextSpan(
                        text: widget.identity,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.inputText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                        text: '.\nVui lòng kiểm tra thông tin đã đăng ký.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OtpInputBoxes(
                  controllers: _controllers,
                  focusNodes: _focusNodes,
                  onChanged: () {
                    if (_codeError != null) setState(() => _codeError = null);
                  },
                ),
                if (_codeError != null) ...[
                  const SizedBox(height: 10),
                  AuthInlineMessage(message: _codeError!),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryGradientButton(
                    key: const Key('forgot-password-code-continue'),
                    height: 52,
                    borderRadius: AppColors.radiusMd,
                    onPressed: _continueToReset,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Tiếp tục'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 19),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: [
                      const Text(
                        'Không nhận được mã?',
                        style: AppTypography.body,
                      ),
                      if (_secondsRemaining > 0)
                        Text(
                          'Gửi lại sau $_cooldownLabel',
                          style: AppTypography.body.copyWith(
                            color: AppColors.bodyText,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _isResending ? null : _resendCode,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size(
                              0,
                              AppColors.minimumTouchTarget,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: _isResending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Text('Gửi lại mã'),
                        ),
                    ],
                  ),
                ),
                if (_resendMessage != null || _resendError != null) ...[
                  const SizedBox(height: 10),
                  AuthInlineMessage(
                    message: _resendMessage ?? _resendError!,
                    kind: _resendMessage != null
                        ? AuthInlineMessageKind.success
                        : AuthInlineMessageKind.error,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
