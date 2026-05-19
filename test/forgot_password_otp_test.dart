import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/screens/forgot_password_otp_screen.dart';
import 'package:hdbhms_mobile/screens/login_page.dart';
import 'package:hdbhms_mobile/services/forgot_password_service.dart';

class _FakeForgotPasswordService extends ForgotPasswordService {
  const _FakeForgotPasswordService();

  @override
  Future<void> sendForgotPasswordOtp(String email) async {}

  @override
  Future<ForgotPasswordVerifyResult> verifyForgotPasswordOtp({
    required String email,
    required String otp,
  }) async {
    if (otp == '123456') {
      return const ForgotPasswordVerifyResult(resetToken: 'test-token');
    }
    throw const ForgotPasswordException('Mã OTP không đúng hoặc đã hết hạn');
  }
}

void main() {
  testWidgets('login forgot password flow opens OTP screen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(forgotPasswordService: _FakeForgotPasswordService()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'tenant@example.com');
    await tester.tap(find.text('GỬI MÃ OTP'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Mã xác minh'), findsOneWidget);
    expect(find.text('tenant@example.com'), findsOneWidget);
  });

  testWidgets('OTP screen validates missing code', (tester) async {
    await _pumpOtpScreen(tester);

    await tester.tap(find.text('Xác minh'));
    await tester.pump();

    expect(find.text('Vui lòng nhập đủ mã OTP'), findsOneWidget);
  });

  testWidgets('OTP screen verifies valid code', (tester) async {
    await _pumpOtpScreen(tester);

    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('Xác minh'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.text('Xác minh OTP thành công'), findsOneWidget);
  });

  testWidgets('OTP screen shows error for invalid code', (tester) async {
    await _pumpOtpScreen(tester);

    await tester.enterText(find.byType(TextField).first, '111111');
    await tester.tap(find.text('Xác minh'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.text('Mã OTP không đúng hoặc đã hết hạn'), findsOneWidget);
  });

  testWidgets('OTP resend countdown enables resend after timer', (
    tester,
  ) async {
    await _pumpOtpScreen(tester, initialResendSeconds: 1);

    expect(find.text('Gửi lại OTP sau 1s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Gửi lại OTP'), findsOneWidget);
  });

  testWidgets('OTP back button returns to previous screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordOtpScreen(
                          email: 'tenant@example.com',
                          forgotPasswordService: _FakeForgotPasswordService(),
                          initialResendSeconds: 0,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open OTP'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Mã xác minh'), findsOneWidget);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Open OTP'), findsOneWidget);
  });
}

Future<void> _pumpOtpScreen(
  WidgetTester tester, {
  int initialResendSeconds = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ForgotPasswordOtpScreen(
        email: 'tenant@example.com',
        forgotPasswordService: const _FakeForgotPasswordService(),
        initialResendSeconds: initialResendSeconds,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
