import 'package:flutter/material.dart';

import 'forgot_password_page.dart';
import 'home_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _idController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: 'resident@complex.com');
    _passwordController = TextEditingController(text: 'password123');
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
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
  });

  final double height;
  final TextEditingController idController;
  final TextEditingController passwordController;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
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
          const _Greeting(),
          const SizedBox(height: 24),
          AuthTextField(
            label: 'ID',
            hintText: 'resident@complex.com',
            icon: Icons.mail_outline,
            controller: idController,
            keyboardType: TextInputType.emailAddress,
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
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordPage(),
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
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
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
