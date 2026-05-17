import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/login_response.dart';
import '../models/onboarding_state.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

class AuthService {
  const AuthService({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const _timeout = Duration(seconds: 10);
  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const tenantIdKey = 'tenant_id';
  static const roleKey = 'role';
  static const userIdKey = 'user_id';
  static const mustChangePasswordKey = 'must_change_password';
  static const identityCompletedKey = 'identity_completed';
  static const nextStepKey = 'next_step';

  Future<LoginResponse> login({
    required String phoneOrEmail,
    required String password,
  }) async {
    final client = _client ?? http.Client();

    try {
      final response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/login'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'phone_or_email': phoneOrEmail,
              'password': password,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final loginResponse = LoginResponse.fromJson(
          _decodeBody(response.body),
        );
        await _saveLoginData(loginResponse);
        return loginResponse;
      }

      throw AuthException(_messageForLoginError(response));
    } on TimeoutException {
      throw const AuthException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const AuthException('Không kết nối được máy chủ');
    } on FormatException {
      throw const AuthException('Đăng nhập thất bại');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<OnboardingState> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final token = await accessToken;
    if (token == null || token.isEmpty) {
      throw const AuthException('Phiên đăng nhập không hợp lệ');
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/change-password'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'old_password': oldPassword,
              'new_password': newPassword,
              'confirm_password': confirmPassword,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = _decodeBody(response.body);
        final onboarding = OnboardingState.fromJson(
          body['onboarding'] as Map<String, dynamic>? ?? {},
        );
        await saveOnboarding(onboarding);
        return onboarding;
      }

      throw AuthException(
        _messageForDefaultError(response, 'Đổi mật khẩu thất bại'),
      );
    } on TimeoutException {
      throw const AuthException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const AuthException('Không kết nối được máy chủ');
    } on FormatException {
      throw const AuthException('Đổi mật khẩu thất bại');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<OnboardingState> fetchOnboarding() async {
    final token = await accessToken;
    if (token == null || token.isEmpty) {
      throw const AuthException('Phiên đăng nhập không hợp lệ');
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/auth/me/onboarding'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final onboarding = OnboardingState.fromJson(_decodeBody(response.body));
        await saveOnboarding(onboarding);
        return onboarding;
      }

      throw AuthException(
        _messageForDefaultError(
          response,
          'Không lấy được trạng thái đăng nhập',
        ),
      );
    } on TimeoutException {
      throw const AuthException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const AuthException('Không kết nối được máy chủ');
    } on FormatException {
      throw const AuthException('Không lấy được trạng thái đăng nhập');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<String?> get accessToken async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessTokenKey);
  }

  static Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
    await prefs.remove(tenantIdKey);
    await prefs.remove(roleKey);
    await prefs.remove(userIdKey);
    await prefs.remove(mustChangePasswordKey);
    await prefs.remove(identityCompletedKey);
    await prefs.remove(nextStepKey);
  }

  Future<OnboardingState?> getCachedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final nextStep = prefs.getString(nextStepKey);
    if (nextStep == null || nextStep.isEmpty) {
      return null;
    }
    return OnboardingState(
      userId: prefs.getInt(userIdKey),
      mustChangePassword: prefs.getBool(mustChangePasswordKey) ?? false,
      identityCompleted: prefs.getBool(identityCompletedKey) ?? false,
      nextStep: nextStep,
    );
  }

  Future<void> _saveLoginData(LoginResponse response) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(accessTokenKey, response.accessToken);
    await prefs.setString(refreshTokenKey, response.refreshToken);

    if (response.user.id != null) {
      await prefs.setInt(userIdKey, response.user.id!);
    }

    if (response.tenants.isNotEmpty) {
      final tenant = response.tenants.first;
      if (tenant.tenantId != null) {
        await prefs.setInt(tenantIdKey, tenant.tenantId!);
      }
      await prefs.setString(roleKey, tenant.role);
    }

    await saveOnboarding(response.onboarding);
  }

  static Future<void> saveOnboarding(OnboardingState onboarding) async {
    final prefs = await SharedPreferences.getInstance();
    if (onboarding.userId != null) {
      await prefs.setInt(userIdKey, onboarding.userId!);
    }
    await prefs.setBool(mustChangePasswordKey, onboarding.mustChangePassword);
    await prefs.setBool(identityCompletedKey, onboarding.identityCompleted);
    await prefs.setString(nextStepKey, onboarding.nextStep);
  }

  String _messageForLoginError(http.Response response) {
    if (response.statusCode == 401) {
      return 'Sai thông tin đăng nhập';
    }

    if (response.statusCode == 403) {
      final backendMessage = _readBackendMessage(response.body);
      return backendMessage.isNotEmpty
          ? backendMessage
          : 'Tài khoản chưa được duyệt hoặc đã bị khóa';
    }

    return 'Đăng nhập thất bại';
  }

  String _messageForDefaultError(http.Response response, String fallback) {
    final backendMessage = _readBackendMessage(response.body);
    return backendMessage.isNotEmpty ? backendMessage : fallback;
  }

  String _readBackendMessage(String body) {
    try {
      final data = _decodeBody(body);
      final message = data['message'] ?? data['error'];
      return message?.toString() ?? '';
    } on FormatException {
      return '';
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const FormatException('Invalid response body');
  }
}
