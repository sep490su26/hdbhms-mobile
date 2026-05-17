import 'package:flutter/material.dart';

import '../models/onboarding_state.dart';
import '../services/auth_service.dart';
import '../services/home_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_text_field.dart';
import 'home_screen.dart';
import 'identity_verification_page.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({
    super.key,
    this.authService = const AuthService(),
    this.homeService = const HomeService(),
    this.isRequired = false,
  });

  final AuthService authService;
  final HomeService homeService;
  final bool isRequired;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  late final TextEditingController _oldPasswordController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _oldPasswordController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final validationMessage = _validate(
      oldPassword,
      newPassword,
      confirmPassword,
    );

    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final onboarding = await widget.authService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (!mounted) {
        return;
      }

      _goToNextStep(onboarding);
    } on AuthException catch (error) {
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

  String? _validate(
    String oldPassword,
    String newPassword,
    String confirmPassword,
  ) {
    if (oldPassword.isEmpty) {
      return 'Vui lòng nhập mật khẩu cũ';
    }
    if (newPassword.isEmpty) {
      return 'Vui lòng nhập mật khẩu mới';
    }
    if (newPassword.length < 8) {
      return 'Mật khẩu mới phải có ít nhất 8 ký tự';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(newPassword) ||
        !RegExp(r'\d').hasMatch(newPassword)) {
      return 'Mật khẩu mới phải có chữ và số';
    }
    if (confirmPassword.isEmpty) {
      return 'Vui lòng xác nhận mật khẩu mới';
    }
    if (newPassword != confirmPassword) {
      return 'Xác nhận mật khẩu không khớp';
    }
    return null;
  }

  void _goToNextStep(OnboardingState onboarding) {
    final page = switch (onboarding.nextStep) {
      OnboardingState.identityVerification => IdentityVerificationPage(
        isRequired: true,
        authService: widget.authService,
        homeService: widget.homeService,
      ),
      _ => HomeScreen(
        authService: widget.authService,
        homeService: widget.homeService,
      ),
    };

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => page));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isRequired && !_isLoading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChangePasswordHeader(
                canGoBack: !widget.isRequired && !_isLoading,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 448),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ChangePasswordIntro(),
                            const SizedBox(height: 32),
                            _ChangePasswordFormCard(
                              oldPasswordController: _oldPasswordController,
                              passwordController: _passwordController,
                              confirmPasswordController:
                                  _confirmPasswordController,
                              isLoading: _isLoading,
                              onSubmit: _handleChangePassword,
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
      ),
    );
  }
}

class _ChangePasswordHeader extends StatelessWidget {
  const _ChangePasswordHeader({required this.canGoBack});

  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 16, 136, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              onPressed: canGoBack
                  ? () => Navigator.of(context).maybePop()
                  : null,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.deepBlue,
                size: 22,
              ),
              tooltip: 'Quay lại',
            ),
          ),
          const Text(
            'Đổi mật khẩu',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 28 / 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordIntro extends StatelessWidget {
  const _ChangePasswordIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thiết lập mật khẩu mới',
          style: TextStyle(
            color: AppColors.inputText,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 32 / 26,
            letterSpacing: -0.52,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Bạn cần đổi mật khẩu tạm trước khi tiếp tục sử dụng ứng dụng.',
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 24 / 16,
          ),
        ),
      ],
    );
  }
}

class _ChangePasswordFormCard extends StatelessWidget {
  const _ChangePasswordFormCard({
    required this.oldPasswordController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController oldPasswordController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 25, 25, 41),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthTextField(
            label: 'Mật khẩu cũ',
            hintText: 'Nhập mật khẩu tạm hiện tại',
            controller: oldPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            hintColor: AppColors.hintText,
            contentPadding: const EdgeInsets.fromLTRB(17, 18, 48, 18),
            uppercaseLabel: false,
          ),
          const SizedBox(height: 24),
          AuthTextField(
            label: 'Mật khẩu mới',
            hintText: 'Nhập mật khẩu mới',
            controller: passwordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            hintColor: AppColors.hintText,
            contentPadding: const EdgeInsets.fromLTRB(17, 18, 48, 18),
            uppercaseLabel: false,
          ),
          const SizedBox(height: 24),
          AuthTextField(
            label: 'Xác nhận mật khẩu',
            hintText: 'Nhập lại mật khẩu mới',
            controller: confirmPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            hintColor: AppColors.hintText,
            contentPadding: const EdgeInsets.fromLTRB(17, 18, 48, 18),
            uppercaseLabel: false,
          ),
          const SizedBox(height: 24),
          const _PasswordRequirements(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'ĐỔI MẬT KHẨU',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 28 / 20,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.requirementBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yêu cầu mật khẩu:',
            style: TextStyle(
              color: AppColors.inputText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 16 / 12,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 8),
          _RequirementItem(text: 'Tối thiểu 8 ký tự'),
          SizedBox(height: 8),
          _RequirementItem(text: 'Có ít nhất một chữ cái'),
          SizedBox(height: 8),
          _RequirementItem(text: 'Có ít nhất một chữ số'),
        ],
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  const _RequirementItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.circle_outlined,
          color: AppColors.cardBorder,
          size: 15,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 20 / 14,
            ),
          ),
        ),
      ],
    );
  }
}
