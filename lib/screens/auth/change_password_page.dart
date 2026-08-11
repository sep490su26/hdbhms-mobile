import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/onboarding_state.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/auth_text_field.dart';
import 'package:hdbhms_mobile/widgets/password_requirements.dart';
import 'package:hdbhms_mobile/screens/auth/identity_verification_page.dart';
import 'package:hdbhms_mobile/screens/tenant_overview/tenant_overview_screen.dart';

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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('Vui lòng kiểm tra các trường bắt buộc');
      return;
    }
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final validationMessage = _validate(newPassword, confirmPassword);

    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.authService.changePassword(
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (!mounted) {
        return;
      }

      if (!widget.isRequired) {
        Navigator.of(context).pop(true);
        return;
      }

      final onboarding = await widget.authService.fetchOnboarding();
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

  String? _validate(String newPassword, String confirmPassword) {
    if (newPassword.isEmpty) {
      return 'Vui lòng nhập mật khẩu mới';
    }
    if (newPassword.length < 8) {
      return 'Mật khẩu mới phải có ít nhất 8 ký tự';
    }
    if (!RegExp(r'\d').hasMatch(newPassword)) {
      return 'Mật khẩu mới phải có ít nhất một chữ số';
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
      OnboardingState.identityVerification => CompleteProfileUploadScreen(
        isRequired: true,
        authService: widget.authService,
        homeService: widget.homeService,
      ),
      _ => TenantOverviewScreen(
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
          child: AppScreenShell(
            header: AppTopBar(
              title: 'Đổi mật khẩu',
              onBack: widget.isRequired || _isLoading
                  ? null
                  : () => Navigator.of(context).maybePop(),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    key: Key('change-password-intro-icon'),
                    color: AppColors.primary,
                    size: 34,
                  ),
                  const SizedBox(height: 10),
                  const _ChangePasswordIntro(),
                  const SizedBox(height: 24),
                  _ChangePasswordFormCard(
                    formKey: _formKey,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    isLoading: _isLoading,
                    onSubmit: _handleChangePassword,
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

class _ChangePasswordIntro extends StatelessWidget {
  const _ChangePasswordIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Thiết lập mật khẩu mới',
          style: AppTypography.pageTitle,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Bạn cần đổi mật khẩu tạm trước khi tiếp tục sử dụng ứng dụng.',
          style: AppTypography.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ChangePasswordFormCard extends StatelessWidget {
  const _ChangePasswordFormCard({
    required this.formKey,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: 'Mật khẩu mới',
            hintText: 'Nhập mật khẩu mới',
            controller: passwordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            hintColor: AppColors.hintText,
            uppercaseLabel: false,
            required: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập mật khẩu mới';
              }
              if (value.length < 8) {
                return 'Mật khẩu mới phải có ít nhất 8 ký tự';
              }
              if (!RegExp(r'\d').hasMatch(value)) {
                return 'Mật khẩu mới phải có ít nhất một chữ số';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          PasswordRequirements(
            passwordController: passwordController,
            rules: [
              PasswordRequirementRule(
                label: 'Tối thiểu 8 ký tự',
                isMet: (password) => password.length >= 8,
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
            controller: confirmPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            hintColor: AppColors.hintText,
            uppercaseLabel: false,
            required: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng xác nhận mật khẩu mới';
              }
              return value != passwordController.text
                  ? 'Xác nhận mật khẩu không khớp'
                  : null;
            },
          ),
          const SizedBox(height: 28),
          AppPrimaryGradientButton(
            height: 52,
            borderRadius: AppColors.radiusMd,
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('ĐỔI MẬT KHẨU'),
          ),
        ],
      ),
    );
  }
}
