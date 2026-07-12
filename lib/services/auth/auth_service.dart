import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/api_response.dart';
import 'package:hdbhms_mobile/models/auth/login_response.dart';
import 'package:hdbhms_mobile/models/auth/user_model.dart';
import 'package:hdbhms_mobile/models/onboarding_state.dart';
import 'package:hdbhms_mobile/models/onboarding_action.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

class SessionExpiredException extends AuthException {
  const SessionExpiredException([super.message = 'Phiên đăng nhập đã hết hạn']);
}

class AuthService {
  const AuthService({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const _timeout = Duration(seconds: 20);
  static const accessTokenKey = 'access_token';
  static const sessionIdKey = 'session_id';
  static const tenantIdKey = 'tenant_id';
  static const propertyIdKey = 'property_id';
  static const roleKey = 'role';
  static const userIdKey = 'user_id';
  static const onBoardingCompletedKey = 'onboarding_completed';
  static const onboardingActionsKey = 'onboarding_actions';

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-Client-Type': 'mobile',
  };

  Future<LoginResponse> login({
    required String phone,
    required String password,
  }) async {
    final client = _client ?? http.Client();

    try {
      final response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/login'),
            headers: _headers,
            body: jsonEncode({'phone': phone, 'password': password}),
          )
          .timeout(_timeout);

      final apiResponse = ApiResponse<LoginResponse>.fromJson(
        _decodeBody(response.body),
        (data) => LoginResponse.fromJson(data as Map<String, dynamic>),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (apiResponse.data == null) {
          throw const AuthException('Dữ liệu đăng nhập không hợp lệ');
        }

        var loginResponse = apiResponse.data!;
        if (loginResponse.onboarding == null) {
          final onboarding = await _fetchOnboardingWithToken(
            loginResponse.token,
          );
          loginResponse = loginResponse.copyWith(onboarding: onboarding);
        }

        await _saveLoginData(loginResponse);
        return loginResponse;
      }

      throw AuthException(
        apiResponse.message ?? _messageForLoginError(response),
      );
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

  Future<OnboardingState> fetchOnboarding() async {
    var token = await accessToken;
    if (token == null || token.isEmpty) {
      final refreshed = await refreshToken();
      token = refreshed.token;
    }
    return _fetchOnboardingWithToken(token);
  }

  Future<LoginResponse> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(sessionIdKey);

    if (sessionId == null || sessionId.isEmpty) {
      throw const SessionExpiredException();
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
            headers: _headers,
            body: jsonEncode({'sessionId': sessionId}),
          )
          .timeout(_timeout);

      final apiResponse = ApiResponse<LoginResponse>.fromJson(
        _decodeBody(response.body),
        (data) => LoginResponse.fromJson(data as Map<String, dynamic>),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (apiResponse.data == null) {
          throw const AuthException('Dữ liệu refresh không hợp lệ');
        }
        final loginResponse = apiResponse.data!;
        await _saveLoginData(loginResponse);
        return loginResponse;
      }

      // If refresh fails, it's a hard logout
      await AuthService.clearLocalSession();
      throw const SessionExpiredException();
    } on TimeoutException {
      throw const AuthException('Không kết nối được máy chủ (refresh)');
    } on http.ClientException {
      throw const AuthException('Không kết nối được máy chủ (refresh)');
    } on FormatException {
      throw const AuthException('Refresh token thất bại');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<OnboardingState> _fetchOnboardingWithToken(String token) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/auth/onboarding'),
            headers: {..._headers, 'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);

      final apiResponse = ApiResponse<OnboardingState>.fromJson(
        _decodeBody(response.body),
        (data) => OnboardingState.fromJson(data as Map<String, dynamic>),
      );

      if (response.statusCode == 200 && apiResponse.data != null) {
        final onboarding = apiResponse.data!;
        await saveOnboarding(onboarding);
        return onboarding;
      }

      if (response.statusCode == 401) {
        try {
          final refreshed = await refreshToken();
          return _fetchOnboardingWithToken(refreshed.token);
        } on SessionExpiredException {
          rethrow;
        }
      }

      throw AuthException(
        apiResponse.message ?? 'Không lấy được trạng thái đăng nhập',
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

  Future<void> logout() async {
    final token = await accessToken;
    if (token == null || token.isEmpty) {
      await clearLocalSession();
      return;
    }

    final client = _client ?? http.Client();
    try {
      await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
            headers: _headers,
            body: jsonEncode({'accessToken': token}),
          )
          .timeout(_timeout);
    } catch (_) {
      // Even if server logout fails, we clear local session
    } finally {
      await clearLocalSession();
      if (_client == null) {
        client.close();
      }
    }
  }

  static Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessTokenKey);
    await prefs.remove(sessionIdKey);
    await prefs.remove(tenantIdKey);
    await prefs.remove(propertyIdKey);
    await prefs.remove(roleKey);
    await prefs.remove(userIdKey);
    await prefs.remove(onBoardingCompletedKey);
    await prefs.remove(onboardingActionsKey);
  }

  Future<OnboardingState?> getCachedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final actionsRaw = prefs.getString(onboardingActionsKey);
    if (actionsRaw == null) return null;

    try {
      final List<dynamic> actionsJson = jsonDecode(actionsRaw);
      return OnboardingState(
        userId: prefs.getInt(userIdKey),
        onBoardingCompleted: prefs.getBool(onBoardingCompletedKey) ?? false,
        actions: actionsJson
            .map((e) => OnboardingAction.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLoginData(LoginResponse response) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(accessTokenKey, response.token);
    await prefs.setString(sessionIdKey, response.sessionId);
    await prefs.setString(roleKey, response.role);
    if (response.tenantId != null) {
      await prefs.setInt(tenantIdKey, response.tenantId!);
    } else {
      await prefs.remove(tenantIdKey);
    }

    if (response.propertyId != null) {
      await prefs.setInt(propertyIdKey, response.propertyId!);
    } else {
      await prefs.remove(propertyIdKey);
    }

    if (response.onboarding != null) {
      await saveOnboarding(response.onboarding!);
    }
  }

  static Future<void> saveOnboarding(OnboardingState onboarding) async {
    final prefs = await SharedPreferences.getInstance();
    if (onboarding.userId != null) {
      await prefs.setInt(userIdKey, onboarding.userId!);
    }
    await prefs.setBool(onBoardingCompletedKey, onboarding.onBoardingCompleted);
    await prefs.setString(
      onboardingActionsKey,
      jsonEncode(onboarding.actions.map((a) => a.toJson()).toList()),
    );
  }

  String _messageForLoginError(http.Response response) {
    if (response.statusCode == 401) {
      return 'Sai thông tin đăng nhập';
    }

    if (response.statusCode == 403) {
      return 'Tài khoản chưa được duyệt hoặc đã bị khóa';
    }

    return 'Đăng nhập thất bại';
  }

  Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<OnboardingState> changePassword({
    String? oldPassword,
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
          .patch(
            Uri.parse('${ApiConfig.baseUrl}/users/me/first-password'),
            headers: {..._headers, 'Authorization': 'Bearer $token'},
            body: jsonEncode({'newPassword': newPassword}),
          )
          .timeout(_timeout);

      final apiResponse = ApiResponse<UserResponse>.fromJson(
        _decodeBody(response.body),
        (data) => UserResponse.fromJson(data as Map<String, dynamic>),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final user = apiResponse.data;
        if (user == null) {
          throw const AuthException('Dữ liệu đổi mật khẩu không hợp lệ');
        }

        if (!user.mustChangePassword) {
          await markFirstPasswordChanged(userId: user.id);
        }

        try {
          return await fetchOnboarding();
        } on AuthException {
          final cachedOnboarding = await getCachedOnboarding();
          if (cachedOnboarding != null) {
            return cachedOnboarding;
          }
          rethrow;
        }
      }

      throw AuthException(apiResponse.message ?? 'Đổi mật khẩu thất bại');
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

  static Future<void> markFirstPasswordChanged({int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final actionsRaw = prefs.getString(onboardingActionsKey);
    final actions = <OnboardingAction>[];

    if (actionsRaw != null) {
      try {
        final List<dynamic> actionsJson = jsonDecode(actionsRaw);
        actions.addAll(
          actionsJson.whereType<Map<String, dynamic>>().map(
            OnboardingAction.fromJson,
          ),
        );
      } catch (_) {
        actions.clear();
      }
    }

    final changePasswordIndex = actions.indexWhere(
      (action) => action.actionKey == OnboardingState.changePassword,
    );
    if (changePasswordIndex >= 0) {
      final current = actions[changePasswordIndex];
      actions[changePasswordIndex] = OnboardingAction(
        actionKey: current.actionKey,
        label: current.label.isEmpty ? 'Change password' : current.label,
        completed: true,
        priority: current.priority,
        actionUrl: null,
      );
    } else {
      actions.add(
        const OnboardingAction(
          actionKey: OnboardingState.changePassword,
          label: 'Change password',
          completed: true,
          priority: 1,
        ),
      );
    }

    actions.sort((a, b) => a.priority.compareTo(b.priority));
    final onboarding = OnboardingState(
      userId: userId ?? prefs.getInt(userIdKey),
      onBoardingCompleted: actions.every((action) => action.completed),
      actions: actions,
    );
    await saveOnboarding(onboarding);
  }
}
