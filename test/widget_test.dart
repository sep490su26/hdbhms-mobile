import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hdbhms_mobile/app.dart';
import 'package:hdbhms_mobile/models/home_summary_model.dart';
import 'package:hdbhms_mobile/models/identity_image_file.dart';
import 'package:hdbhms_mobile/models/login_response.dart';
import 'package:hdbhms_mobile/models/onboarding_state.dart';
import 'package:hdbhms_mobile/models/tenant_profile_model.dart';
import 'package:hdbhms_mobile/screens/identity_verification_page.dart';
import 'package:hdbhms_mobile/screens/tenant_profile_screen.dart';
import 'package:hdbhms_mobile/services/auth_service.dart';
import 'package:hdbhms_mobile/services/file_upload_service.dart';
import 'package:hdbhms_mobile/services/home_service.dart';
import 'package:hdbhms_mobile/services/identity_service.dart';
import 'package:hdbhms_mobile/services/tenant_profile_service.dart';

class _FakeAuthService extends AuthService {
  const _FakeAuthService();

  @override
  Future<LoginResponse> login({
    required String phoneOrEmail,
    required String password,
  }) async {
    return _homeLoginResponse;
  }
}

class _FakeHomeService extends HomeService {
  const _FakeHomeService();

  @override
  Future<HomeSummary> fetchHomeSummary() async {
    return _homeSummary;
  }
}

class _FakeTenantProfileService extends TenantProfileService {
  _FakeTenantProfileService({this.responses = const [], this.error});

  final List<TenantProfileResponse> responses;
  final Object? error;
  int _callCount = 0;

  @override
  Future<TenantProfileResponse> getMyProfile({int? tenantId}) async {
    if (error != null) {
      throw error!;
    }
    final index = _callCount < responses.length
        ? _callCount
        : responses.length - 1;
    _callCount++;
    return responses[index];
  }
}

const _testApp = App(
  authService: _FakeAuthService(),
  homeService: _FakeHomeService(),
);
const _homeOnboarding = OnboardingState(
  userId: 1,
  mustChangePassword: false,
  identityCompleted: true,
  nextStep: OnboardingState.home,
);
const _homeLoginResponse = LoginResponse(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  expiresIn: 900,
  user: LoginUser(
    id: 1,
    fullName: 'Test User',
    phone: '0900000000',
    email: 'test@example.com',
    status: 'ACTIVE',
    mustChangePassword: false,
    identityCompleted: true,
  ),
  tenants: [
    LoginTenant(
      tenantId: 1,
      tenantName: 'Test Tenant',
      role: 'TENANT',
      propertyId: 1,
    ),
  ],
  onboarding: _homeOnboarding,
);
const _homeSummary = HomeSummary(
  user: HomeUser(
    id: 1,
    fullName: 'Test User',
    phone: '0900000000',
    email: 'test@example.com',
    role: 'TENANT',
  ),
  tenant: HomeTenant(id: 1, name: 'Test Tenant'),
  room: HomeRoom(
    id: 1,
    roomCode: '101',
    name: 'Phòng 101',
    currentStatus: 'OCCUPIED',
  ),
  contract: HomeContract(
    id: 1,
    contractCode: 'HD-TEST-001',
    status: 'ACTIVE',
    startDate: null,
    endDate: null,
  ),
  invoiceSummary: InvoiceSummary(
    unpaidCount: 2,
    totalUnpaidAmount: 2800000,
    nearestDueDate: null,
  ),
  notificationSummary: NotificationSummary(unreadCount: 3),
  onboarding: _homeOnboarding,
);

final _tenantProfile = TenantProfileResponse(
  tenantProfileId: 1,
  status: 'ACTIVE',
  person: PersonProfileDto(
    fullName: 'Nguyễn Văn A',
    phone: '0912345678',
    email: 'a@gmail.com',
    permanentAddress: '12 Nguyễn Trãi, Hà Nội',
  ),
  identityDocument: IdentityDocumentDto(
    docType: 'CCCD',
    docNumber: '036078008683',
    issuedDate: DateTime(2020, 4, 1),
    issuedPlace: 'Cục CS QLHCVTTXH',
  ),
  vehicles: [
    VehicleDto(
      id: 1,
      vehicleType: 'MOTORBIKE',
      licensePlate: '29B1-12345',
      imageUrl: 'https://example.com/vehicle.jpg',
    ),
  ],
  emergencyContacts: [
    EmergencyContactDto(
      fullName: 'Nguyễn Thị B',
      relationship: 'Mẹ',
      phone: '0987111222',
    ),
  ],
);

const _tenantProfileWithoutVehicles = TenantProfileResponse(
  tenantProfileId: 1,
  status: 'ACTIVE',
  person: PersonProfileDto(
    fullName: 'Nguyễn Văn A',
    phone: '',
    email: '',
    permanentAddress: '',
  ),
  identityDocument: null,
  vehicles: [],
  emergencyContacts: [],
);

const _tenantProfileWithNullVehicleImage = TenantProfileResponse(
  tenantProfileId: 1,
  status: 'ACTIVE',
  person: PersonProfileDto(
    fullName: 'Nguyễn Văn A',
    phone: '0912345678',
    email: '',
    permanentAddress: '',
  ),
  identityDocument: null,
  vehicles: [
    VehicleDto(
      id: 1,
      vehicleType: 'MOTORBIKE',
      licensePlate: '29B1-12345',
      imageUrl: '',
    ),
  ],
  emergencyContacts: [],
);

class _FakeIdentityService extends IdentityService {
  const _FakeIdentityService();

  @override
  Future<IdentityUploadResult> uploadIdentity({
    required IdentityImageFile portrait,
    required IdentityImageFile frontId,
    required IdentityImageFile backId,
  }) async {
    return const IdentityUploadResult(
      identityCompleted: true,
      onboarding: _homeOnboarding,
    );
  }
}

const _identityPage = MaterialApp(
  home: IdentityVerificationPage(
    fileUploadService: MockFileUploadService(),
    identityService: _FakeIdentityService(),
    authService: _FakeAuthService(),
    homeService: _FakeHomeService(),
  ),
);

Future<void> login(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(ElevatedButton).last);
  await tester.tap(find.byType(ElevatedButton).last);
  await tester.pumpAndSettle();
}

Future<void> openBillsFromHomeCta(WidgetTester tester) async {
  final cta = find.text('Thanh to\u00E1n ngay');
  await tester.ensureVisible(cta);
  await tester.pumpAndSettle();
  await tester.tap(cta);
  await tester.pumpAndSettle();
}

Future<void> pumpTenantProfile(
  WidgetTester tester,
  TenantProfileService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TenantProfileScreen(
        profileService: service,
        authService: const _FakeAuthService(),
        homeService: const _FakeHomeService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(_testApp);
    await tester.pumpAndSettle();

    expect(find.text('resident@complex.com'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('opens overview after login', (WidgetTester tester) async {
    await tester.pumpWidget(_testApp);
    await tester.pumpAndSettle();

    await login(tester);

    expect(find.text('XIN CH\u00C0O,'), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('Test Tenant'), findsOneWidget);
    expect(find.text('2.800.000'), findsOneWidget);
  });

  testWidgets('opens bill selection from payment CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp);
    await tester.pumpAndSettle();

    await login(tester);

    await openBillsFromHomeCta(tester);

    expect(find.text('H\u00F3a \u0111\u01A1n'), findsOneWidget);
    expect(
      find.text('H\u00D3A \u0110\u01A0N \u0110\u00C3 THANH TO\u00C1N'),
      findsOneWidget,
    );
    expect(find.text('View All Historical Data'), findsOneWidget);
  });

  testWidgets('opens bill selection from bottom Bills tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp);
    await tester.pumpAndSettle();

    await login(tester);

    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();

    expect(find.text('H\u00F3a \u0111\u01A1n'), findsOneWidget);
    expect(find.text('Ti\u1EC1n ph\u00F2ng'), findsNWidgets(2));
    expect(find.text('View All Historical Data'), findsOneWidget);
  });

  testWidgets('opens QR payment from bill selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp);
    await tester.pumpAndSettle();

    await login(tester);

    await openBillsFromHomeCta(tester);

    await tester.tap(find.text('Ti\u1EC1n ph\u00F2ng').first);
    await tester.pumpAndSettle();

    expect(find.text('Thanh to\u00E1n h\u00F3a \u0111\u01A1n'), findsOneWidget);
    expect(find.text('2.450.000\u0111'), findsOneWidget);
    expect(find.text('RESIDENT_99283_JULY'), findsOneWidget);
    expect(find.text('T\u00F4i \u0111\u00E3 thanh to\u00E1n'), findsOneWidget);
  });

  testWidgets('opens payment success after confirming paid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp);
    await tester.pumpAndSettle();

    await login(tester);

    await openBillsFromHomeCta(tester);

    await tester.tap(find.text('Ti\u1EC1n ph\u00F2ng').first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.text('T\u00F4i \u0111\u00E3 thanh to\u00E1n'),
    );
    await tester.tap(find.text('T\u00F4i \u0111\u00E3 thanh to\u00E1n'));
    await tester.pumpAndSettle();

    expect(find.text('Thanh to\u00E1n th\u00E0nh c\u00F4ng!'), findsOneWidget);
    expect(find.text('#TXN-882910'), findsOneWidget);
    expect(find.text('800.000 \u0111'), findsOneWidget);
    expect(find.text('Quay l\u1EA1i trang ch\u1EE7'), findsOneWidget);
  });

  testWidgets('opens payment history from success page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp);
    await tester.pumpAndSettle();

    await login(tester);

    await openBillsFromHomeCta(tester);

    await tester.tap(find.text('Ti\u1EC1n ph\u00F2ng').first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.text('T\u00F4i \u0111\u00E3 thanh to\u00E1n'),
    );
    await tester.tap(find.text('T\u00F4i \u0111\u00E3 thanh to\u00E1n'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Xem l\u1ECBch s\u1EED'));
    await tester.tap(find.text('Xem l\u1ECBch s\u1EED'));
    await tester.pumpAndSettle();

    expect(find.text('L\u1ECBch s\u1EED thanh to\u00E1n'), findsOneWidget);
    expect(find.text('T\u00ECm ki\u1EBFm..'), findsOneWidget);
    expect(find.text('Th\u00E1ng 2 2023'), findsOneWidget);
    expect(find.text('S\u1EEDa t\u1EE7 l\u1EA1nh'), findsOneWidget);
  });

  testWidgets('opens payment history from bill selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp);
    await tester.pumpAndSettle();

    await login(tester);

    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('View All Historical Data'));
    await tester.tap(find.text('View All Historical Data'));
    await tester.pumpAndSettle();

    expect(find.text('L\u1ECBch s\u1EED thanh to\u00E1n'), findsOneWidget);
    expect(find.text('T\u00ECm ki\u1EBFm..'), findsOneWidget);
    expect(find.text('S\u1EEDa t\u1EE7 l\u1EA1nh'), findsOneWidget);
  });

  testWidgets('bottom Home tab returns from bill selection to home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp);
    await tester.pumpAndSettle();

    await login(tester);

    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('XIN CH\u00C0O,'), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);
  });

  testWidgets('bottom Home tab returns from payment history to home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp);
    await tester.pumpAndSettle();

    await login(tester);

    await tester.tap(find.text('Bills'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('View All Historical Data'));
    await tester.tap(find.text('View All Historical Data'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('XIN CH\u00C0O,'), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);
  });

  testWidgets('tenant profile shows saved database fields', (
    WidgetTester tester,
  ) async {
    await pumpTenantProfile(
      tester,
      _FakeTenantProfileService(responses: [_tenantProfile]),
    );

    expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsWidgets);
    expect(find.text('0912345678'), findsOneWidget);
    expect(find.text('a@gmail.com'), findsOneWidget);
    expect(find.text('036078008683'), findsOneWidget);
    expect(find.text('29B1-12345'), findsOneWidget);
    expect(find.text('Nguyễn Thị B'), findsOneWidget);
    expect(find.text('0987111222'), findsOneWidget);
    expect(find.text('01/04/2020'), findsOneWidget);
  });

  testWidgets('tenant profile not found shows friendly empty state', (
    WidgetTester tester,
  ) async {
    await pumpTenantProfile(
      tester,
      _FakeTenantProfileService(error: const TenantProfileNotFoundException()),
    );

    expect(find.text('Chưa có hồ sơ cá nhân'), findsOneWidget);
    expect(find.text('Tải lại'), findsOneWidget);
  });

  testWidgets('tenant profile handles empty vehicles and contacts', (
    WidgetTester tester,
  ) async {
    await pumpTenantProfile(
      tester,
      _FakeTenantProfileService(responses: [_tenantProfileWithoutVehicles]),
    );

    expect(find.text('Chưa có phương tiện'), findsOneWidget);
    expect(find.text('Chưa có liên hệ khẩn cấp'), findsOneWidget);
    expect(find.text('Chưa cập nhật'), findsWidgets);
  });

  testWidgets('tenant profile handles null vehicle image without crashing', (
    WidgetTester tester,
  ) async {
    await pumpTenantProfile(
      tester,
      _FakeTenantProfileService(
        responses: [_tenantProfileWithNullVehicleImage],
      ),
    );

    expect(find.text('29B1-12345'), findsOneWidget);
    expect(find.text('Chưa có ảnh phương tiện'), findsOneWidget);
  });

  testWidgets('tenant profile vehicle image opens zoom preview', (
    WidgetTester tester,
  ) async {
    await pumpTenantProfile(
      tester,
      _FakeTenantProfileService(responses: [_tenantProfile]),
    );

    final imageTapTarget = find.byKey(const ValueKey('vehicle-image-1'));
    await tester.ensureVisible(imageTapTarget);
    await tester.tap(imageTapTarget);
    await tester.pumpAndSettle();

    expect(find.byType(VehicleImagePreviewPage), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('tenant profile forbidden state is displayed', (
    WidgetTester tester,
  ) async {
    await pumpTenantProfile(
      tester,
      _FakeTenantProfileService(error: const TenantProfileForbiddenException()),
    );

    expect(find.text('Bạn không có quyền xem hồ sơ này'), findsOneWidget);
  });

  testWidgets('tenant profile refresh reads updated service data', (
    WidgetTester tester,
  ) async {
    final service = _FakeTenantProfileService(
      responses: [
        _tenantProfileWithoutVehicles,
        const TenantProfileResponse(
          tenantProfileId: 1,
          status: 'ACTIVE',
          person: PersonProfileDto(
            fullName: 'Nguyễn Văn A Updated',
            phone: '0909009009',
            email: '',
            permanentAddress: '',
          ),
          identityDocument: null,
          vehicles: [],
          emergencyContacts: [],
        ),
      ],
    );
    await pumpTenantProfile(tester, service);

    expect(find.text('Nguyễn Văn A'), findsWidgets);
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Văn A Updated'), findsWidgets);
    expect(find.text('0909009009'), findsOneWidget);
  });

  testWidgets('identity verification requires three images before continuing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_identityPage);

    final continueButton = find.widgetWithText(
      ElevatedButton,
      'Ti\u1EBFp t\u1EE5c',
    );
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);

    await tester.ensureVisible(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.tap(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.pumpAndSettle();
    expect(find.text('CCCD m\u1EB7t tr\u01B0\u1EDBc'), findsWidgets);
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);

    await tester.ensureVisible(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.tap(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.pumpAndSettle();
    expect(find.text('CCCD m\u1EB7t sau'), findsWidgets);
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);

    await tester.ensureVisible(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.tap(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.pumpAndSettle();
    expect(find.text('X\u00E1c nh\u1EADn h\u1ED3 s\u01A1'), findsOneWidget);
    final confirmButton = find.widgetWithText(ElevatedButton, 'Xác nhận');
    expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNotNull);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(find.text('XIN CH\u00C0O,'), findsOneWidget);
  });

  testWidgets('identity verification back button returns to previous step', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_identityPage);

    await tester.ensureVisible(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.tap(find.text('Ch\u1EE5p \u1EA3nh'));
    await tester.pumpAndSettle();

    expect(find.text('CCCD m\u1EB7t tr\u01B0\u1EDBc'), findsWidgets);

    await tester.tap(find.text('Tr\u1EDF v\u1EC1'));
    await tester.pumpAndSettle();

    expect(find.text('\u1EA2nh ch\u00E2n dung'), findsWidgets);
  });
}
