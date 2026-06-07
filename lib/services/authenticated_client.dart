import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app.dart';
import '../screens/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'home_service.dart';

class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient({
    http.Client? inner,
    this.authService = const AuthService(),
  }) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final AuthService authService;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await authService.accessToken;
    final sessionId = await _getSessionId();

    if (token == null && sessionId == null) {
      _redirectToLogin();
      return _empty401Response(request);
    }

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    if (request is! http.MultipartRequest) {
      request.headers['Content-Type'] = 'application/json';
    }
    request.headers['X-Client-Type'] = 'mobile';

    final response = await _inner.send(request);

    if (response.statusCode == 401 || response.statusCode == 403) {
      final isRetryable = request is http.Request;
      if (!isRetryable) {
        // Cannot retry streams safely
        return response;
      }

      try {
        final newLoginData = await authService.refreshToken();

        final newRequest = _cloneRequest(request);
        newRequest.headers['Authorization'] = 'Bearer ${newLoginData.token}';

        return await _inner.send(newRequest);
      } catch (e) {
        await AuthService.clearLocalSession();
        _redirectToLogin();
        return response;
      }
    }

    return response;
  }

  void _redirectToLogin() {
    App.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const LoginPage(
          authService: AuthService(),
          homeService: HomeService(),
        ),
      ),
      (route) => false,
    );
  }

  Future<String?> _getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AuthService.sessionIdKey);
  }

  http.StreamedResponse _empty401Response(http.BaseRequest request) {
    return http.StreamedResponse(
      Stream.fromIterable([]),
      401,
      request: request,
    );
  }

  http.BaseRequest _cloneRequest(http.BaseRequest request) {
    if (request is http.Request) {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..maxRedirects = request.maxRedirects
        ..followRedirects = request.followRedirects
        ..persistentConnection = request.persistentConnection
        ..bodyBytes = request.bodyBytes;
      return copy;
    } else if (request is http.MultipartRequest) {
      // Multipart requests are harder to clone because the streams might be consumed.
      // For now, return original or implement full clone if needed.
      return request;
    }
    return request;
  }
}
