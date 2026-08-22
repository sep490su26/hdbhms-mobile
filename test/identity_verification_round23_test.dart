import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hdbhms_mobile/models/auth/identity_image_file.dart';
import 'package:hdbhms_mobile/models/maintenance/file_metadata_model.dart';
import 'package:hdbhms_mobile/screens/auth/identity_verification_page.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/auth/identity_service.dart';
import 'package:hdbhms_mobile/services/file_upload_service.dart';
import 'package:hdbhms_mobile/utils/identity_profile_validators.dart'
    show
        formatIdentityIssuedDate,
        validateIdentityDocumentNumber,
        validateIdentityIssuedDate,
        validateIdentityIssuedPlace,
        validatePermanentAddress,
        validateProfileEmail;

class _ImmediateIdentityFiles implements FileUploadService {
  const _ImmediateIdentityFiles();

  @override
  Future<IdentityImageFile> pickIdentityImage({
    required String label,
    required IdentityImageSource source,
  }) async {
    return IdentityImageFile(
      id: label,
      label: label,
      name: '$label.jpg',
      sizeInBytes: _imageBytes.length,
      source: source,
      bytes: Uint8List.fromList(_imageBytes),
      mimeType: 'image/jpeg',
    );
  }

  @override
  bool isFileTooLarge(IdentityImageFile file) => false;

  @override
  String? validateIdentityImage(IdentityImageFile file) => null;

  @override
  Future<FileMetadataResponse> upload(
    IdentityImageFile file, {
    required FileCategory category,
  }) async => const FileMetadataResponse(
    fileId: 1,
    originalFileName: 'identity.jpg',
    url: '',
    uploaded: true,
  );
}

class _RecordingMultipartClient extends http.BaseClient {
  _RecordingMultipartClient({
    this.identityCompleted = false,
    this.profileCompleted = false,
  });

  final bool identityCompleted;
  final bool profileCompleted;
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest value) async {
    request = value;
    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(
          jsonEncode({
            'success': true,
            'identityCompleted': identityCompleted,
            'profileCompleted': profileCompleted,
            'onboarding': <String, dynamic>{},
          }),
        ),
      ),
      201,
    );
  }
}

class _OcrMultipartClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(
          jsonEncode({
            'success': true,
            'extractedIdentity': {
              'idNumber': '079123456789',
              'issuedDate': '2022-04-28',
              'issuedPlace': 'Bộ Công an',
              'address': '12 Nguyễn Trãi, Hà Nội',
            },
          }),
        ),
      ),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _ErrorMultipartClient extends http.BaseClient {
  _ErrorMultipartClient(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

const _imageBytes = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  10,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  0,
  1,
  0,
  0,
  5,
  0,
  1,
  13,
  10,
  45,
  180,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

IdentityImageFile _identityImage(String label) => IdentityImageFile(
  id: label,
  label: label,
  name: '$label.jpg',
  sizeInBytes: _imageBytes.length,
  source: IdentityImageSource.camera,
  bytes: Uint8List.fromList(_imageBytes),
  mimeType: 'image/jpeg',
);

Future<void> _pumpIdentity(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: IdentityVerificationPage(
        fileUploadService: _ImmediateIdentityFiles(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('identity-action-continue')));
  await tester.pumpAndSettle();
}

Future<void> _chooseImageAndContinue(WidgetTester tester) async {
  final capture = find.text('Chụp ảnh');
  await tester.ensureVisible(capture);
  await tester.tap(capture);
  await tester.pumpAndSettle();
  await _continue(tester);
}

Finder _input(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextFormField),
);

Future<void> _reachIdentityInfo(WidgetTester tester) async {
  await _chooseImageAndContinue(tester);
  await _chooseImageAndContinue(tester);
  await _chooseImageAndContinue(tester);
  expect(find.byKey(const ValueKey('identity-info-step')), findsOneWidget);
}

Future<void> _selectToday(WidgetTester tester) async {
  final dateField = _input('identity-issued-date-field');
  await tester.ensureVisible(dateField);
  await tester.tap(dateField);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _fillValidIdentityInfo(WidgetTester tester) async {
  await tester.ensureVisible(_input('identity-doc-number-field'));
  await tester.enterText(_input('identity-doc-number-field'), '079123456789');
  await _selectToday(tester);
  await tester.ensureVisible(_input('identity-issued-place-field'));
  await tester.enterText(
    _input('identity-issued-place-field'),
    'Cục Cảnh sát quản lý hành chính về trật tự xã hội',
  );
  await tester.enterText(
    _input('identity-permanent-address-field'),
    '12 Nguyễn Trãi, Hà Nội',
  );
  await tester.enterText(_input('identity-email-field'), 'tenant@example.com');
}

void main() {
  group('Round 23 identity verification', () {
    test('identity flow has five explicit steps and validates metadata', () {
      expect(IdentityDocumentStep.values, hasLength(5));
      expect(IdentityDocumentStep.values[3], IdentityDocumentStep.identityInfo);
      expect(IdentityDocumentStep.identityInfo.title, 'Th\u00F4ng tin');
      expect(
        validateIdentityDocumentNumber('12345678901'),
        'Số CCCD phải gồm đúng 12 chữ số',
      );
      expect(validateIdentityDocumentNumber('123456789012'), isNull);
      expect(validateIdentityIssuedDate(null), 'Vui lòng chọn ngày cấp');
      expect(
        validateIdentityIssuedDate(
          DateTime(2026, 1, 2),
          today: DateTime(2026, 1, 1),
        ),
        'Ngày cấp không được ở tương lai',
      );
      expect(validateIdentityIssuedPlace('   '), 'Vui lòng nhập nơi cấp');
      expect(
        validateIdentityIssuedPlace('a' * 256),
        'Nơi cấp không được vượt quá 255 ký tự',
      );
      expect(validatePermanentAddress(''), 'Vui lòng nhập địa chỉ thường trú');
      expect(validatePermanentAddress('a' * 1000), isNull);
      expect(
        validatePermanentAddress('a' * 1001),
        'Địa chỉ thường trú không được vượt quá 1000 ký tự',
      );
      expect(validateProfileEmail('abc'), 'Địa chỉ email không đúng định dạng');
      expect(validateProfileEmail('tenant@example.com'), isNull);
      expect(validateProfileEmail(''), isNull);
      expect(
        validateProfileEmail('a' * 245 + '@example.com'),
        'Email không được vượt quá 255 ký tự',
      );
    });

    testWidgets('back image advances to metadata, which validates inline', (
      tester,
    ) async {
      await _pumpIdentity(tester);
      await _reachIdentityInfo(tester);

      expect(find.text('Th\u00F4ng tin CCCD'), findsOneWidget);
      expect(
        find.text('Th\u00F4ng tin li\u00EAn h\u1EC7 & c\u01B0 tr\u00FA'),
        findsOneWidget,
      );
      expect(_input('identity-doc-number-field'), findsOneWidget);
      expect(_input('identity-issued-date-field'), findsOneWidget);
      expect(_input('identity-issued-place-field'), findsOneWidget);
      expect(_input('identity-permanent-address-field'), findsOneWidget);
      expect(_input('identity-email-field'), findsOneWidget);

      await _continue(tester);
      expect(find.text('Vui lòng nhập số CCCD'), findsOneWidget);
      expect(find.text('Vui lòng chọn ngày cấp'), findsOneWidget);
      expect(find.text('Vui lòng nhập nơi cấp'), findsOneWidget);
      expect(find.text('Vui lòng nhập địa chỉ thường trú'), findsOneWidget);
      expect(find.text('Vui lòng nhập email'), findsNothing);
      expect(find.byKey(const ValueKey('identity-review-info')), findsNothing);

      final docNumberInput = _input('identity-doc-number-field');
      await tester.enterText(docNumberInput, '07912abc34567890');
      expect(
        tester.widget<TextFormField>(docNumberInput).controller!.text,
        '079123456789',
      );
      await tester.enterText(docNumberInput, '07912345678');
      await _continue(tester);
      expect(find.text('Số CCCD phải gồm đúng 12 chữ số'), findsOneWidget);

      await tester.enterText(docNumberInput, '079123456789');
      await tester.enterText(_input('identity-issued-place-field'), 'a' * 256);
      await _continue(tester);
      expect(find.text('Vui lòng chọn ngày cấp'), findsOneWidget);
      expect(
        find.text('Nơi cấp không được vượt quá 255 ký tự'),
        findsOneWidget,
      );
      expect(find.text('Vui lòng nhập địa chỉ thường trú'), findsOneWidget);
      expect(find.text('Vui lòng nhập email'), findsNothing);

      await tester.enterText(
        _input('identity-permanent-address-field'),
        '12 Nguyễn Trãi, Hà Nội',
      );
      await tester.enterText(_input('identity-email-field'), 'abc');
      await _continue(tester);
      expect(find.text('Địa chỉ email không đúng định dạng'), findsOneWidget);
    });

    testWidgets('metadata persists through back, review and edit', (
      tester,
    ) async {
      await _pumpIdentity(tester);
      await _reachIdentityInfo(tester);
      await _fillValidIdentityInfo(tester);

      await tester.tap(find.text('Trở về'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('back_id_step')), findsOneWidget);
      await _continue(tester);
      expect(find.byKey(const ValueKey('identity-info-step')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(_input('identity-doc-number-field'))
            .controller!
            .text,
        '079123456789',
      );
      expect(
        tester
            .widget<TextFormField>(_input('identity-permanent-address-field'))
            .controller!
            .text,
        '12 Nguyễn Trãi, Hà Nội',
      );
      expect(
        tester
            .widget<TextFormField>(_input('identity-email-field'))
            .controller!
            .text,
        'tenant@example.com',
      );
      await _continue(tester);

      expect(find.text('Xác nhận hồ sơ'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('identity-review-portrait')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('identity-review-front-id')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('identity-review-back-id')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('identity-review-info')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('identity-review-info-edit')),
        findsOneWidget,
      );
      expect(find.text('079123456789'), findsOneWidget);
      expect(
        find.text(formatIdentityIssuedDate(DateTime.now())),
        findsOneWidget,
      );
      expect(find.text('Nơi cấp'), findsOneWidget);
      expect(find.text('Địa chỉ thường trú'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(
        find.text('Cục Cảnh sát quản lý hành chính về trật tự xã hội'),
        findsOneWidget,
      );
      expect(find.text('12 Nguyễn Trãi, Hà Nội'), findsOneWidget);
      expect(find.text('tenant@example.com'), findsOneWidget);

      await tester.tap(find.text('Trở về'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('identity-info-step')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(_input('identity-doc-number-field'))
            .controller!
            .text,
        '079123456789',
      );

      await _continue(tester);
      await tester.tap(find.byKey(const ValueKey('identity-review-info-edit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('identity-info-step')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(_input('identity-issued-place-field'))
            .controller!
            .text,
        'Cục Cảnh sát quản lý hành chính về trật tự xã hội',
      );
      expect(
        tester
            .widget<TextFormField>(_input('identity-email-field'))
            .controller!
            .text,
        'tenant@example.com',
      );
    });

    testWidgets('five-step metadata form stays usable at target phone sizes', (
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
        await _pumpIdentity(tester);
        await _reachIdentityInfo(tester);
        expect(find.byKey(const ValueKey('identity-stepper')), findsOneWidget);
        expect(find.text('Thông tin CCCD'), findsWidgets);
        expect(find.text('Thông tin liên hệ & cư trú'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });

    testWidgets(
      'long issued place wraps safely in review at target phone sizes',
      (tester) async {
        const longPlace =
            'Cục Cảnh sát quản lý hành chính về trật tự xã hội tại Thành phố Hồ Chí Minh';
        for (final size in const [
          Size(320, 640),
          Size(360, 800),
          Size(390, 844),
          Size(430, 932),
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(const SizedBox.shrink());
          await _pumpIdentity(tester);
          await _reachIdentityInfo(tester);
          await _fillValidIdentityInfo(tester);
          await tester.enterText(
            _input('identity-issued-place-field'),
            longPlace,
          );
          await _continue(tester);
          final review = find.byKey(const ValueKey('identity-review-info'));
          await tester.ensureVisible(review);
          expect(review, findsOneWidget);
          expect(find.text(longPlace), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        addTearDown(() => tester.binding.setSurfaceSize(null));
      },
    );

    test(
      'identity upload multipart contract sends metadata and image files',
      () async {
        SharedPreferences.setMockInitialValues({AuthService.tenantIdKey: 9});
        final client = _RecordingMultipartClient();
        final service = IdentityService(client: client);

        await service.uploadIdentity(
          portrait: _identityImage('portrait'),
          frontId: _identityImage('front'),
          backId: _identityImage('back'),
          docNumber: '079123456789',
          issuedDate: DateTime(2022, 3, 4),
          issuedPlace: 'Bộ Công an',
          permanentAddress: 'Hà Nội',
          email: 'tenant@example.com',
        );

        final request = client.request! as http.MultipartRequest;
        expect(request.fields, {
          'docNumber': '079123456789',
          'issuedDate': '2022-03-04',
          'issuedPlace': 'Bộ Công an',
          'permanentAddress': 'Hà Nội',
          'email': 'tenant@example.com',
        });
        expect(request.files.map((file) => file.field).toList(), [
          'portraitFile',
          'idCardFrontFile',
          'idCardBackFile',
        ]);
      },
    );

    test('identity upload omits an empty optional email', () async {
      SharedPreferences.setMockInitialValues({AuthService.tenantIdKey: 9});
      final client = _RecordingMultipartClient();
      final service = IdentityService(client: client);

      await service.uploadIdentity(
        portrait: _identityImage('portrait'),
        frontId: _identityImage('front'),
        backId: _identityImage('back'),
        docNumber: '079123456789',
        issuedDate: DateTime(2022, 3, 4),
        issuedPlace: 'Bo Cong an',
        permanentAddress: 'Ha Noi',
      );

      final request = client.request! as http.MultipartRequest;
      expect(request.fields, {
        'docNumber': '079123456789',
        'issuedDate': '2022-03-04',
        'issuedPlace': 'Bo Cong an',
        'permanentAddress': 'Ha Noi',
      });
    });

    testWidgets('OCR fills the permanent address field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: IdentityVerificationPage(
            fileUploadService: const _ImmediateIdentityFiles(),
            identityService: IdentityService(client: _OcrMultipartClient()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _reachIdentityInfo(tester);

      expect(
        tester
            .widget<TextFormField>(_input('identity-permanent-address-field'))
            .controller!
            .text,
        '12 Nguyễn Trãi, Hà Nội',
      );
    });

    test('identity and profile completion flags remain independent', () async {
      SharedPreferences.setMockInitialValues({AuthService.tenantIdKey: 9});
      final service = IdentityService(
        client: _RecordingMultipartClient(
          identityCompleted: true,
          profileCompleted: false,
        ),
      );

      final result = await service.uploadIdentity(
        portrait: _identityImage('portrait'),
        frontId: _identityImage('front'),
        backId: _identityImage('back'),
        docNumber: '079123456789',
        issuedDate: DateTime(2022, 3, 4),
        issuedPlace: 'Bộ Công an',
        permanentAddress: 'Hà Nội',
        email: 'tenant@example.com',
      );

      expect(result.identityCompleted, isTrue);
      expect(result.profileCompleted, isFalse);
    });

    test(
      'identity upload surfaces backend errors for non-validation statuses',
      () async {
        SharedPreferences.setMockInitialValues({AuthService.tenantIdKey: 9});
        final service = IdentityService(
          client: _ErrorMultipartClient(
            500,
            jsonEncode({'message': 'Tải tệp lên thất bại'}),
          ),
        );

        expect(
          () => service.uploadIdentity(
            portrait: _identityImage('portrait'),
            frontId: _identityImage('front'),
            backId: _identityImage('back'),
            docNumber: '079123456789',
            issuedDate: DateTime(2022, 3, 4),
            issuedPlace: 'Bộ Công an',
            permanentAddress: 'Hà Nội',
          ),
          throwsA(
            isA<IdentityException>().having(
              (error) => error.message,
              'message',
              'Tải tệp lên thất bại',
            ),
          ),
        );
      },
    );

    test(
      'identity upload surfaces root error message when data is present',
      () async {
        SharedPreferences.setMockInitialValues({AuthService.tenantIdKey: 9});
        final service = IdentityService(
          client: _ErrorMultipartClient(
            400,
            jsonEncode({
              'message': 'Dữ liệu không hợp lệ',
              'data': {
                'fieldErrors': {'files': 'Tệp không hợp lệ'},
              },
            }),
          ),
        );

        expect(
          () => service.uploadIdentity(
            portrait: _identityImage('portrait'),
            frontId: _identityImage('front'),
            backId: _identityImage('back'),
            docNumber: '079123456789',
            issuedDate: DateTime(2022, 3, 4),
            issuedPlace: 'Bộ Công an',
            permanentAddress: 'Hà Nội',
          ),
          throwsA(
            isA<IdentityException>().having(
              (error) => error.message,
              'message',
              'Dữ liệu không hợp lệ',
            ),
          ),
        );
      },
    );
  });
}
