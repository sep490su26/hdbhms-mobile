import 'dart:async';

import 'package:flutter/material.dart';

import '../services/forgot_password_service.dart';
import '../theme/app_colors.dart';
import '../widgets/otp_input_boxes.dart';

class ForgotPasswordOtpScreen extends StatefulWidget {
  const ForgotPasswordOtpScreen({
    super.key,
    required this.email,
    this.forgotPasswordService = const ForgotPasswordService(),
    this.initialResendSeconds = 60,
  });

  final String email;
  final ForgotPasswordService forgotPasswordService;
  final int initialResendSeconds;

  @override
  State<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _focusNodes;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;
  late int _resendSeconds;

  String get _otp =>
      _otpControllers.map((controller) => controller.text).join();

  @override
  void initState() {
    super.initState();
    _otpControllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    _resendSeconds = widget.initialResendSeconds;
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    if (_resendSeconds <= 0) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        setState(() {
          _resendSeconds = 0;
        });
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds -= 1;
      });
    });
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      _showMessage('Vui lòng nhập đủ mã OTP');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      await widget.forgotPasswordService.verifyForgotPasswordOtp(
        email: widget.email,
        otp: _otp,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Xác minh OTP thành công');
    } on ForgotPasswordException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0 || _isResending) {
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      await widget.forgotPasswordService.sendForgotPasswordOtp(widget.email);
      if (!mounted) {
        return;
      }
      _showMessage('Đã gửi lại mã OTP');
      setState(() {
        _resendSeconds = widget.initialResendSeconds;
      });
      _startCountdown();
    } on ForgotPasswordException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
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
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.deepBlue,
                  size: 26,
                ),
                tooltip: 'Quay lại',
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 76, 18, 34),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const _OtpIcon(),
                            const SizedBox(height: 22),
                            const Text(
                              'Mã xác minh',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.deepBlue,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 32 / 26,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Hệ thống đã gửi mã OTP đến email của bạn',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.bodyText,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 20 / 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.email,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.deepBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                height: 18 / 13,
                              ),
                            ),
                            const SizedBox(height: 28),
                            OtpInputBoxes(
                              controllers: _otpControllers,
                              focusNodes: _focusNodes,
                            ),
                            const SizedBox(height: 22),
                            _ResendText(
                              seconds: _resendSeconds,
                              isLoading: _isResending,
                              onResend: _resendOtp,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isVerifying ? null : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.deepBlue,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.deepBlue
                                      .withValues(alpha: 0.65),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isVerifying
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Xác minh',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _DotsIndicator(),
                    ],
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

class _OtpIcon extends StatelessWidget {
  const _OtpIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.deepBlue.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.verified_user_outlined,
        color: AppColors.deepBlue,
        size: 34,
      ),
    );
  }
}

class _ResendText extends StatelessWidget {
  const _ResendText({
    required this.seconds,
    required this.isLoading,
    required this.onResend,
  });

  final int seconds;
  final bool isLoading;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    if (seconds > 0) {
      return Text(
        'Gửi lại OTP sau ${seconds}s',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.bodyText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 18 / 13,
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Bạn chưa nhận được mã?',
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 18 / 13,
          ),
        ),
        TextButton(
          onPressed: isLoading ? null : onResend,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.deepBlue,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            isLoading ? 'Đang gửi...' : 'Gửi lại OTP',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 18 / 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(AppColors.deepBlue),
        const SizedBox(width: 8),
        _dot(AppColors.deepBlue.withValues(alpha: 0.28)),
        const SizedBox(width: 8),
        _dot(AppColors.deepBlue.withValues(alpha: 0.28)),
      ],
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
