import 'package:flutter/material.dart';

import 'change_password_page.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController _emailController;

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
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ChangePasswordPage(),
                                  ),
                                );
                              },
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(
                                Icons.send_outlined,
                                color: Colors.white,
                                size: 19,
                              ),
                              label: const Text(
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
