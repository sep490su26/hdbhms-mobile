import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hdbhms_mobile/app.dart';
import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/models/auth/login_response.dart';
import 'package:hdbhms_mobile/models/onboarding_state.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_profile_model.dart';
import 'package:hdbhms_mobile/models/onboarding_action.dart';
import 'package:hdbhms_mobile/screens/auth/change_password_page.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';

class _FakeAuthService extends AuthService {
  const _FakeAuthService();

  @override
  Future<LoginResponse> login({
    required String phone,
    required String password,
  }) async {
    return _homeLoginResponse;
  }
}

class _IdentityStepLoginAuthService extends AuthService {
  const _IdentityStepLoginAuthService();

  @override
  Future<LoginResponse> login({
    required String phone,
    required String password,
  }) async {
    return _identityStepLoginResponse;
  }
}

class _IdentityStepStartupAuthService extends AuthService {
  const _IdentityStepStartupAuthService();

  @override
  Future<String?> get accessToken async => 'test-access-token';

  @override
  Future<OnboardingState> fetchOnboarding() async {
    return _identityStepOnboarding;
  }
}

class _IdentityStepAfterPasswordAuthService extends AuthService {
  const _IdentityStepAfterPasswordAuthService();

  @override
  Future<OnboardingState> changePassword({
    String? oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return _identityStepOnboarding;
  }

  @override
  Future<OnboardingState> fetchOnboarding() async {
    return _identityStepOnboarding;
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
  Future<TenantProfileResponse> getMyProfile() async {
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
  onBoardingCompleted: true,
  actions: [],
);
const _homeLoginResponse = LoginResponse(
  token: 'test-access-token',
  sessionId: 'test-session-id',
  role: 'TENANT',
  authorized: true,
  onboarding: _homeOnboarding,
);
const _identityStepOnboarding = OnboardingState(
  userId: 1,
  onBoardingCompleted: false,
  actions: [
    OnboardingAction(
      actionKey: OnboardingState.identityVerification,
      label: 'Identity Verification',
      completed: false,
      priority: 1,
    ),
  ],
);
const _identityStepLoginResponse = LoginResponse(
  token: 'test-access-token',
  sessionId: 'test-session-id',
  role: 'TENANT',
  authorized: true,
  onboarding: _identityStepOnboarding,
);
final _homeSummary = HomeSummary(
  user: const HomeUser(
    id: 1,
    fullName: 'Test User',
    phone: '0900000000',
    email: 'test@example.com',
    role: 'TENANT',
  ),
  tenant: const HomeTenant(id: 1, name: 'Test Tenant'),
  room: const HomeRoom(
    id: 1,
    roomCode: '101',
    name: 'Phòng 101',
    currentStatus: 'OCCUPIED',
  ),
  rooms: const [],
  contract: HomeContract(
    id: 1,
    contractCode: 'HD-TEST-001',
    status: 'ACTIVE',
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2025, 1, 1),
  ),
  invoiceSummary: const InvoiceSummary(
    unpaidCount: 2,
    totalUnpaidAmount: 2800000,
    nearestDueDate: null,
  ),
  notificationSummary: const NotificationSummary(unreadCount: 0),
  utilitySummary: const UtilitySummary(
    electricity: UtilityUsage(
      name: 'Điện',
      value: 150.0,
      unit: 'kWh',
      status: 'Bình thường',
      percentChange: null,
    ),
    water: UtilityUsage(
      name: 'Nước',
      value: 10.0,
      unit: 'm³',
      status: 'Bình thường',
      percentChange: null,
    ),
  ),
  onboarding: _homeOnboarding,
);

final _tenantProfile = TenantProfileResponse(
  tenantProfileId: 1,
  status: 'ACTIVE',
  person: const PersonProfileDto(
    fullName: 'Nguyễn Văn A',
    phone: '0912345678',
    email: 'a@gmail.com',
    permanentAddress: '12 Nguyễn Trãi, Hà Nội',
    portraitFileUrl: '',
  ),
  identityDocument: IdentityDocumentDto(
    docType: 'CCCD',
    docNumber: '036078008683',
    issuedDate: DateTime(2020, 4, 1),
    frontFileUrl: '',
    backFileUrl: '',
    issuedPlace: 'Cục CS QLHCVTTXH',
  ),
  vehicles: [
    const VehicleDto(
      id: 1,
      vehicleType: 'MOTORBIKE',
      licensePlate: '29B1-12345',
      imageUrl: 'https://example.com/vehicle.jpg',
    ),
  ],
  emergencyContacts: [
    const EmergencyContactDto(
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
    portraitFileUrl: '',
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
    portraitFileUrl: '',
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

Future<void> login(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), '0912000201');
  await tester.enterText(find.byType(TextFormField).at(1), 'Changed@123');
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

    expect(find.text('SỐ ĐIỆN THOẠI'), findsOneWidget);
    expect(find.text('Nhập số điện thoại'), findsOneWidget);
    expect(find.text('resident@complex.com'), findsNothing);
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
            portraitFileUrl: '',
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

  test('mobile onboarding preserves identity verification step', () {
    final onboarding = OnboardingState.fromJson(const {
      'user_id': 1,
      'must_change_password': false,
      'identity_completed': false,
      'next_step': OnboardingState.identityVerification,
    });

    expect(onboarding.nextStep, OnboardingState.identityVerification);
  });

  test('mobile login response parses tenant context for identity upload', () {
    final response = LoginResponse.fromJson(const {
      'token': 'token',
      'sessionId': 'session',
      'role': 'TENANT',
      'authorized': true,
      'tenantId': 23,
      'propertyId': 7,
    });

    expect(response.tenantId, 23);
    expect(response.propertyId, 7);
  });

  test('mobile login saves tenant context for identity upload', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AuthService(
      client: MockClient(
        (_) async => http.Response('''
          {
            "code": 0,
            "data": {
              "token": "token",
              "sessionId": "session",
              "role": "TENANT",
              "tenantId": 23,
              "propertyId": 7,
              "authorized": true,
              "onboarding": {
                "user_id": 1,
                "on_boarding_completed": false,
                "actions": [
                  {
                    "action_key": "IDENTITY_VERIFICATION",
                    "label": "Upload identity documents",
                    "completed": false,
                    "priority": 1
                  }
                ]
              }
            }
          }
          ''', 200),
      ),
    );

    final response = await service.login(
      phone: '0900000000',
      password: 'password',
    );
    final prefs = await SharedPreferences.getInstance();

    expect(response.onboarding?.nextStep, OnboardingState.identityVerification);
    expect(prefs.getInt(AuthService.tenantIdKey), 23);
  });

  testWidgets('login requires identity verification before home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const App(
        authService: _IdentityStepLoginAuthService(),
        homeService: _FakeHomeService(),
      ),
    );
    await tester.pumpAndSettle();

    await login(tester);

    expect(find.text('XIN CH\u00C0O,'), findsNothing);
    expect(find.text('Hoàn tất hồ sơ'), findsWidgets);
    expect(find.text('CCCD mặt trước'), findsWidgets);
  });

  testWidgets('startup requires identity verification before home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const App(
        authService: _IdentityStepStartupAuthService(),
        homeService: _FakeHomeService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('XIN CH\u00C0O,'), findsNothing);
    expect(find.text('Hoàn tất hồ sơ'), findsWidgets);
    expect(find.text('CCCD mặt trước'), findsWidgets);
  });

  testWidgets('change password continues to required identity verification', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChangePasswordPage(
          authService: _IdentityStepAfterPasswordAuthService(),
          homeService: _FakeHomeService(),
          isRequired: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Changed123');
    await tester.enterText(find.byType(TextFormField).at(1), 'Changed123');
    await tester.ensureVisible(find.text('ĐỔI MẬT KHẨU'));
    await tester.tap(find.text('ĐỔI MẬT KHẨU'));
    await tester.pumpAndSettle();

    expect(find.text('XIN CH\u00C0O,'), findsNothing);
    expect(find.text('Hoàn tất hồ sơ'), findsWidgets);
    expect(find.text('CCCD mặt trước'), findsWidgets);
  });
}
