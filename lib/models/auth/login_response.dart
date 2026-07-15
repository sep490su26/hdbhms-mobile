import 'package:hdbhms_mobile/models/onboarding_state.dart';

class LoginResponse {
  const LoginResponse({
    required this.token,
    required this.sessionId,
    required this.role,
    required this.authorized,
    this.mustChangePassword,
    this.tenantId,
    this.propertyId,
    this.onboarding,
  });

  final String token;
  final String sessionId;
  final String role;
  final bool authorized;
  final bool? mustChangePassword;
  final int? tenantId;
  final int? propertyId;
  final OnboardingState? onboarding;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token']?.toString() ?? '',
      sessionId:
          json['sessionId']?.toString() ?? json['session_id']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      authorized: json['authorized'] == true,
      mustChangePassword:
          json.containsKey('mustChangePassword') ||
              json.containsKey('must_change_password')
          ? json['mustChangePassword'] == true ||
                json['must_change_password'] == true
          : null,
      tenantId: _asInt(json['tenantId'] ?? json['tenant_id']),
      propertyId: _asInt(json['propertyId'] ?? json['property_id']),
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
      mustChangePassword: mustChangePassword,
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
    return 'LoginResponse{token: $token, sessionId: $sessionId, role: $role, authorized: $authorized, mustChangePassword: $mustChangePassword, tenantId: $tenantId, propertyId: $propertyId, onboarding: $onboarding}';
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
