import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/screens/auth/change_password_page.dart';
import 'package:hdbhms_mobile/screens/auth/forgot_password_code_page.dart';
import 'package:hdbhms_mobile/screens/auth/forgot_password_page.dart';
import 'package:hdbhms_mobile/screens/auth/password_reset_success_page.dart';
import 'package:hdbhms_mobile/screens/auth/reset_password_page.dart';
import 'package:hdbhms_mobile/services/auth/forgot_password_service.dart';
import 'package:hdbhms_mobile/widgets/auth_inline_message.dart';

class _FakeForgotPasswordService extends ForgotPasswordService {
  _FakeForgotPasswordService({this.resetError});

  final ForgotPasswordException? resetError;
  int requestCount = 0;
  String? lastIdentity;
  String? lastToken;
  String? lastPassword;

  @override
  Future<void> requestResetPassword(String email) async {
    requestCount++;
    lastIdentity = email;
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    lastToken = token;
    lastPassword = newPassword;
    if (resetError != null) throw resetError!;
  }
}

void main() {
  testWidgets(
    'forgot password sends request then opens the separate code page',
    (tester) async {
      final service = _FakeForgotPasswordService();

      await tester.pumpWidget(
        MaterialApp(home: ForgotPasswordPage(forgotPasswordService: service)),
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'tenant@test.com',
      );
      await tester.tap(find.byKey(const Key('forgot-password-send-code')));
      await tester.pumpAndSettle();

      expect(service.lastIdentity, 'tenant@test.com');
      expect(find.text('Nhập mã xác minh'), findsOneWidget);
    },
  );

  testWidgets(
    'code page accepts six digits locally before opening password form',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordCodePage(
            identity: 'tenant@test.com',
            initialResendSeconds: 0,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump();
      await tester.tap(find.byKey(const Key('forgot-password-code-continue')));
      await tester.pumpAndSettle();

      expect(find.text('Thiết lập mật khẩu mới'), findsOneWidget);
      expect(find.text('Mã xác minh'), findsNothing);
    },
  );

  testWidgets('code page resends through the existing reset-request service', (
    tester,
  ) async {
    final service = _FakeForgotPasswordService();

    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordCodePage(
          identity: 'tenant@test.com',
          forgotPasswordService: service,
          initialResendSeconds: 0,
        ),
      ),
    );

    await tester.tap(find.text('Gửi lại mã'));
    await tester.pump();

    expect(service.requestCount, 1);
    expect(find.text('Đã gửi lại mã xác minh.'), findsOneWidget);
    expect(find.byType(AuthInlineMessage), findsOneWidget);
  });

  testWidgets(
    'password reset success replaces the form with a dedicated state',
    (tester) async {
      final service = _FakeForgotPasswordService();

      await tester.pumpWidget(
        MaterialApp(
          home: ResetPasswordPage(
            token: '123456',
            forgotPasswordService: service,
          ),
        ),
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Password1');
      await tester.enterText(fields.at(1), 'Password1');
      final submit = find.byKey(const Key('reset-password-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(service.lastToken, '123456');
      expect(find.byType(PasswordResetSuccessPage), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
    },
  );

  testWidgets('expired token returns the normal OTP flow to its code page', (
    tester,
  ) async {
    final service = _FakeForgotPasswordService(
      resetError: const ForgotPasswordException('Token expired'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordCodePage(
          identity: 'tenant@test.com',
          forgotPasswordService: service,
          initialResendSeconds: 0,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.byKey(const Key('forgot-password-code-continue')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Password1');
    await tester.enterText(fields.at(1), 'Password1');
    final submit = find.byKey(const Key('reset-password-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.text('Mã xác minh không hợp lệ hoặc đã hết hạn.'),
      findsOneWidget,
    );
    expect(find.text('Nhập mã khác'), findsOneWidget);
    await tester.tap(find.text('Nhập mã khác'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordCodePage), findsOneWidget);
    expect(find.text('Nhập mã xác minh'), findsOneWidget);
  });

  testWidgets(
    'deep-link token errors direct the tenant to request a new code',
    (tester) async {
      final service = _FakeForgotPasswordService(
        resetError: const ForgotPasswordException('Token expired'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ResetPasswordPage(
            token: '123456',
            forgotPasswordService: service,
          ),
        ),
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Password1');
      await tester.enterText(fields.at(1), 'Password1');
      final submit = find.byKey(const Key('reset-password-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Yêu cầu mã mới'), findsOneWidget);
      await tester.tap(find.text('Yêu cầu mã mới'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordPage), findsOneWidget);
    },
  );

  testWidgets('password requirements update from the reset validator policy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ResetPasswordPage(token: '123456')),
    );

    expect(find.text('Tối thiểu 8 ký tự'), findsOneWidget);
    expect(find.text('Có ít nhất một chữ cái'), findsOneWidget);
    expect(find.text('Có ít nhất một chữ số'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, 'Password1');
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
  });

  testWidgets('code entry stays overflow-free across supported mobile sizes', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;

    for (final size in const [
      Size(320, 640),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordCodePage(
            identity: 'tenant@test.com',
            initialResendSeconds: 0,
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'viewport $size');
    }
  });

  testWidgets('auth form layouts stay overflow-free across supported sizes', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;

    for (final size in const [
      Size(320, 640),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
    ]) {
      tester.view.physicalSize = size;
      for (final page in const <Widget>[
        ForgotPasswordPage(),
        ResetPasswordPage(token: '123456'),
        ChangePasswordPage(),
      ]) {
        await tester.pumpWidget(MaterialApp(home: page));
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} at $size',
        );
      }
    }
  });
}
