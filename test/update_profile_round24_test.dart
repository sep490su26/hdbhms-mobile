import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdbhms_mobile/models/profile_request/tenant_profile_model.dart';
import 'package:hdbhms_mobile/screens/profile_request/update_profile_screen.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';

class _RecordingTenantProfileService extends TenantProfileService {
  _RecordingTenantProfileService(this.response);

  final TenantProfileResponse response;
  int updateCalls = 0;

  @override
  Future<TenantProfileResponse> updateMyProfile({
    required String phone,
    required String email,
    required List<Map<String, dynamic>> emergencyContacts,
    required List<Map<String, dynamic>> vehicles,
  }) async {
    updateCalls += 1;
    return response;
  }
}

class _SilentNotificationService extends NotificationService {
  const _SilentNotificationService();

  @override
  Future<int> getUnreadCount({int? roomId, String? roomCode}) async => 0;
}

TenantProfileResponse _profile({bool withIdentityDocument = true}) {
  return TenantProfileResponse.fromJson({
    'tenantProfileId': 24,
    'status': 'ACTIVE',
    'person': {
      'fullName': 'Nguyễn Văn A',
      'phone': '0901234567',
      'email': 'tenant@example.com',
      'permanentAddress': '12 Nguyễn Trãi, Hà Nội',
    },
    if (withIdentityDocument)
      'identityDocument': {
        'docType': 'CCCD',
        'docNumber': '079123456789',
        'issuedDate': '2024-04-01',
        'issuedPlace': 'Cục Cảnh sát quản lý hành chính',
      },
    'vehicles': <Object?>[],
    'emergencyContacts': <Object?>[],
  });
}

Finder _field(String key) => find.byKey(ValueKey(key));

Future<void> _pumpProfile(
  WidgetTester tester, {
  required _RecordingTenantProfileService service,
  bool withIdentityDocument = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: UpdateProfileScreen(
        profile: _profile(withIdentityDocument: withIdentityDocument),
        profileService: service,
        notificationService: const _SilentNotificationService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('update-profile-save'));
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  group('Round 24 update profile metadata', () {
    testWidgets(
      'prefills identity and residence metadata without email duplication',
      (tester) async {
        final service = _RecordingTenantProfileService(_profile());
        await _pumpProfile(tester, service: service);

        expect(
          tester
              .widget<TextFormField>(_field('update-profile-permanent-address'))
              .controller!
              .text,
          '12 Nguyễn Trãi, Hà Nội',
        );
        expect(
          tester
              .widget<TextFormField>(_field('update-profile-doc-number'))
              .controller!
              .text,
          '079123456789',
        );
        expect(
          tester
              .widget<TextFormField>(_field('update-profile-issued-date'))
              .controller!
              .text,
          '01/04/2024',
        );
        expect(
          tester
              .widget<TextFormField>(_field('update-profile-issued-place'))
              .controller!
              .text,
          'Cục Cảnh sát quản lý hành chính',
        );
        expect(_field('update-profile-email'), findsOneWidget);
        expect(find.text('EMAIL'), findsOneWidget);
        expect(find.text('CCCD mặt trước'), findsNothing);
        expect(find.text('CCCD mặt sau'), findsNothing);
      },
    );

    testWidgets(
      'renders empty identity fields when identity document is absent',
      (tester) async {
        final service = _RecordingTenantProfileService(_profile());
        await _pumpProfile(
          tester,
          service: service,
          withIdentityDocument: false,
        );

        expect(
          tester
              .widget<TextFormField>(_field('update-profile-doc-number'))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<TextFormField>(_field('update-profile-issued-date'))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<TextFormField>(_field('update-profile-issued-place'))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<TextFormField>(_field('update-profile-permanent-address'))
              .controller!
              .text,
          '12 Nguyễn Trãi, Hà Nội',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'keeps supported-only saving available when legacy identity is absent',
      (tester) async {
        final service = _RecordingTenantProfileService(_profile());
        await _pumpProfile(
          tester,
          service: service,
          withIdentityDocument: false,
        );

        await tester.enterText(
          _field('update-profile-email'),
          'new@example.com',
        );
        await _tapSave(tester);

        expect(service.updateCalls, 1);
      },
    );

    testWidgets('shows inline metadata and email validation errors', (
      tester,
    ) async {
      final service = _RecordingTenantProfileService(_profile());
      await _pumpProfile(tester, service: service);

      await tester.enterText(_field('update-profile-permanent-address'), '');
      await tester.enterText(_field('update-profile-doc-number'), '123');
      await tester.enterText(_field('update-profile-issued-place'), '');
      await tester.enterText(_field('update-profile-email'), 'invalid-email');
      await _tapSave(tester);

      expect(find.text('Vui lòng nhập địa chỉ thường trú'), findsOneWidget);
      expect(find.text('Số CCCD phải gồm đúng 12 chữ số'), findsOneWidget);
      expect(find.text('Vui lòng nhập nơi cấp'), findsOneWidget);
      expect(find.text('Địa chỉ email không đúng định dạng'), findsOneWidget);
      expect(service.updateCalls, 0);
    });

    testWidgets('does not call PUT when unsupported metadata changes', (
      tester,
    ) async {
      final service = _RecordingTenantProfileService(_profile());
      await _pumpProfile(tester, service: service);

      await tester.enterText(
        _field('update-profile-permanent-address'),
        '99 Lê Lợi, Đà Nẵng',
      );
      await _tapSave(tester);

      expect(service.updateCalls, 0);
      expect(
        find.text(
          'Các thay đổi về địa chỉ và CCCD chưa thể lưu vì hệ thống chưa hỗ trợ cập nhật các trường này.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cập nhật hồ sơ thành công'), findsNothing);
    });

    testWidgets('keeps existing PUT flow for supported-only changes', (
      tester,
    ) async {
      final service = _RecordingTenantProfileService(_profile());
      await _pumpProfile(tester, service: service);

      await tester.enterText(_field('update-profile-email'), 'new@example.com');
      await _tapSave(tester);

      expect(service.updateCalls, 1);
    });

    testWidgets('metadata form stays responsive at target phone sizes', (
      tester,
    ) async {
      for (final size in const [
        Size(320, 640),
        Size(360, 800),
        Size(390, 844),
        Size(430, 932),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(const SizedBox.shrink());
        final service = _RecordingTenantProfileService(_profile());
        await _pumpProfile(tester, service: service);
        expect(_field('update-profile-permanent-address'), findsOneWidget);
        expect(_field('update-profile-issued-place'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });
}
