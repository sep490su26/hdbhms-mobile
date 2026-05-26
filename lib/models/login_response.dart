import 'onboarding_state.dart';

class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
    required this.tenants,
    required this.onboarding,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final LoginUser user;
  final List<LoginTenant> tenants;
  final OnboardingState onboarding;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final tenantsJson = json['tenants'];
    return LoginResponse(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      expiresIn: int.tryParse(json['expires_in']?.toString() ?? '') ?? 0,
      user: LoginUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      tenants: tenantsJson is List
          ? tenantsJson
                .whereType<Map<String, dynamic>>()
                .map(LoginTenant.fromJson)
                .toList()
          : const [],
      onboarding: OnboardingState.fromJson(
        json['onboarding'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class LoginUser {
  const LoginUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.status,
    required this.mustChangePassword,
    required this.identityCompleted,
  });

  final int? id;
  final String fullName;
  final String phone;
  final String email;
  final String status;
  final bool mustChangePassword;
  final bool identityCompleted;

  factory LoginUser.fromJson(Map<String, dynamic> json) {
    return LoginUser(
      id: int.tryParse(json['id']?.toString() ?? ''),
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      mustChangePassword: json['must_change_password'] == true,
      identityCompleted: json['identity_completed'] == true,
    );
  }
}

class LoginTenant {
  const LoginTenant({
    required this.tenantId,
    required this.tenantName,
    required this.role,
    required this.propertyId,
  });

  final int? tenantId;
  final String tenantName;
  final String role;
  final int? propertyId;

  factory LoginTenant.fromJson(Map<String, dynamic> json) {
    return LoginTenant(
      tenantId: int.tryParse(json['tenant_id']?.toString() ?? ''),
      tenantName: json['tenant_name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      propertyId: int.tryParse(json['property_id']?.toString() ?? ''),
    );
  }
}
