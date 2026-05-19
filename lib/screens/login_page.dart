import 'package:flutter/material.dart';

import '../models/onboarding_state.dart';
import '../services/auth_service.dart';
import '../services/forgot_password_service.dart';
import '../services/home_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_text_field.dart';
import 'change_password_page.dart';
import 'forgot_password_page.dart';
import 'home_screen.dart';
import 'identity_verification_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.authService = const AuthService(),
    this.homeService = const HomeService(),
    this.forgotPasswordService = const ForgotPasswordService(),
  });

  final AuthService authService;
  final HomeService homeService;
  final ForgotPasswordService forgotPasswordService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _idController;
  late final TextEditingController _passwordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final id = _idController.text.trim();
    final password = _passwordController.text;

    if (id.isEmpty) {
      _showMessage('Vui lòng nhập số điện thoại');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Vui lòng nhập mật khẩu');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await widget.authService.login(
        phoneOrEmail: id,
        password: password,
      );

      if (!mounted) {
        return;
      }

      _goToNextStep(response.onboarding);
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToNextStep(OnboardingState onboarding) {
    final page = switch (onboarding.nextStep) {
      OnboardingState.changePassword => ChangePasswordPage(
        authService: widget.authService,
        homeService: widget.homeService,
        isRequired: true,
      ),
      OnboardingState.identityVerification => CompleteProfileUploadScreen(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight;
            final viewportWidth = constraints.maxWidth;
            final horizontalPadding = viewportWidth < 360 ? 12.0 : 16.0;
            final heroHeight = (viewportHeight * 0.35)
                .clamp(284.0, 309.0)
                .toDouble();
            final cardTop = heroHeight - 48;
            final cardHeight = (viewportHeight - cardTop - 90)
                .clamp(500.0, 513.0)
                .toDouble();

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewportHeight),
                child: Stack(
                  children: [
                    _HeroSection(height: heroHeight),
                    Padding(
                      padding: EdgeInsets.only(
                        left: horizontalPadding,
                        right: horizontalPadding,
                        top: cardTop,
                        bottom: 28,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: _LoginCard(
                            height: cardHeight,
                            idController: _idController,
                            passwordController: _passwordController,
                            isLoading: _isLoading,
                            onLogin: _handleLogin,
                            forgotPasswordService:
                                widget.forgotPasswordService,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.darkBlue),
          const _BuildingPlaceholder(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  AppColors.heroGradientStart.withValues(alpha: 0.78),
                  AppColors.darkBlue.withValues(alpha: 0.62),
                  AppColors.darkBlue.withValues(alpha: 0),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _LogoMark(),
                SizedBox(height: 16),
                Text(
                  'Nhà trọ Hải Đăng',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 28 / 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.height,
    required this.idController,
    required this.passwordController,
    required this.isLoading,
    required this.onLogin,
    required this.forgotPasswordService,
  });

  final double height;
  final TextEditingController idController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLogin;
  final ForgotPasswordService forgotPasswordService;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Greeting(),
          const SizedBox(height: 24),
          AuthTextField(
            label: 'Số điện thoại',
            hintText: 'Nhập số điện thoại',
            icon: Icons.phone_outlined,
            controller: idController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Mật khẩu',
            hintText: 'Nhập mật khẩu',
            icon: Icons.lock_outline,
            controller: passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ForgotPasswordPage(
                            forgotPasswordService: forgotPasswordService,
                          ),
                        ),
                      );
                    },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.deepBlue,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 16),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Quên mật khẩu?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 16 / 12,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: isLoading ? null : onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                disabledBackgroundColor: AppColors.darkBlue.withValues(
                  alpha: 0.72,
                ),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Đang đăng nhập...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 24 / 16,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Đăng nhập',
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

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đăng nhập',
          style: TextStyle(
            color: AppColors.deepBlue,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 32 / 26,
            letterSpacing: -0.52,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Nhập thông tin đăng nhập của bạn để truy cập\nvào tài khoản.',
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 24 / 13,
          ),
        ),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 57,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(
        Icons.apartment_rounded,
        color: AppColors.deepBlue,
        size: 31,
      ),
    );
  }
}

class _BuildingPlaceholder extends StatelessWidget {
  const _BuildingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.34,
      child: CustomPaint(painter: _BuildingPainter()),
    );
  }
}

class _BuildingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final building = Path()
      ..moveTo(size.width * 0.22, size.height * 0.02)
      ..lineTo(size.width * 0.72, size.height * -0.08)
      ..lineTo(size.width * 0.92, size.height * 0.9)
      ..lineTo(size.width * 0.08, size.height)
      ..close();

    canvas.drawPath(building, fill);
    canvas.drawPath(building, paint);

    for (var i = 0; i < 9; i++) {
      final x = size.width * (0.22 + i * 0.065);
      canvas.drawLine(
        Offset(x, size.height * 0.03),
        Offset(x + size.width * 0.08, size.height * 0.92),
        paint,
      );
    }

    for (var i = 0; i < 11; i++) {
      final y = size.height * (0.09 + i * 0.075);
      canvas.drawLine(
        Offset(size.width * 0.16, y),
        Offset(size.width * 0.9, y + size.height * 0.02),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
