import 'package:hdbhms_mobile/models/onboarding_state.dart';

class LoginResponse {
  const LoginResponse({
    required this.token,
    required this.sessionId,
    required this.role,
    required this.authorized,
    this.tenantId,
    this.propertyId,
    this.onboarding,
  });

  final String token;
  final String sessionId;
  final String role;
  final bool authorized;
  final int? tenantId;
  final int? propertyId;
  final OnboardingState? onboarding;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token']?.toString() ?? '',
      sessionId:
          json['sessionId']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      authorized: json['authorized'] == true,
      tenantId: _asInt(json['tenantId']),
      propertyId: _asInt(json['propertyId']),
      onboarding: json['onboarding'] != null
          ? OnboardingState.fromJson(json['onboarding'] as Map<String, dynamic>)
          : null,
    );
  }

  // Backup copies to keep existing code from breaking immediately
  LoginResponse copyWith({OnboardingState? onboarding}) {
    return LoginResponse(
      token: token,
      sessionId: sessionId,
      role: role,
      authorized: authorized,
      tenantId: tenantId,
      propertyId: propertyId,
      onboarding: onboarding ?? this.onboarding,
    );
  }

  String get refreshToken => sessionId;
  int get expiresIn => 3600;
  LoginUser get user => const LoginUser();
  List<LoginTenant> get tenants => const [];

  @override
  String toString() {
    return 'LoginResponse{token: $token, sessionId: $sessionId, role: $role, authorized: $authorized, tenantId: $tenantId, propertyId: $propertyId, onboarding: $onboarding}';
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

class LoginUser {
  const LoginUser({
    this.id,
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.status = '',
    this.mustChangePassword = false,
    this.identityCompleted = false,
  });

  final int? id;
  final String fullName;
  final String phone;
  final String email;
  final String status;
  final bool mustChangePassword;
  final bool identityCompleted;

  factory LoginUser.fromJson(Map<String, dynamic> json) => const LoginUser();
}

class LoginTenant {
  const LoginTenant({
    this.tenantId,
    this.tenantName = '',
    this.role = '',
    this.propertyId,
  });

  final int? tenantId;
  final String tenantName;
  final String role;
  final int? propertyId;

  factory LoginTenant.fromJson(Map<String, dynamic> json) =>
      const LoginTenant();
}
