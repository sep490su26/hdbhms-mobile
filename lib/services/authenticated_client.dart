import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hdbhms_mobile/app.dart';
import 'package:hdbhms_mobile/screens/auth/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';

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

    debugPrint('➡️ [HTTP] ${request.method} ${request.url}');

    http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } on http.ClientException catch (error) {
      _logNetworkFailure(request, error);
      rethrow;
    }

    debugPrint('⬅️ [HTTP] ${response.statusCode} ${request.url}');

    // Only buffer the body if we need to handle 401 (token refresh + retry).
    // For all other status codes, stream the response directly — this avoids
    // loading large binary files (images, PDFs) entirely into RAM just for logging.
    if (response.statusCode != 401) {
      return response;
    }


    // --- 401 path: buffer body so we can retry with a fresh token ---
    if (request is! http.Request) {
      // Cannot safely clone a multipart/stream request; return as-is.
      return response;
    }

    // Drain the body before retrying (required to release the connection).
    await response.stream.drain<void>();

    try {
      final newLoginData = await authService.refreshToken();
      final newRequest = _cloneRequest(request);

      newRequest.headers['Authorization'] = 'Bearer ${newLoginData.token}';

      debugPrint('🔄 [HTTP RETRY] ${newRequest.method} ${newRequest.url}');
      return await _inner.send(newRequest);
    } catch (e) {
      debugPrint('❌ [HTTP] Token refresh failed: $e');
      await AuthService.clearLocalSession();
      _redirectToLogin();
      return _empty401Response(request);
    }
  }

  void _logNetworkFailure(http.BaseRequest request, Object error) {
    final uri = request.url;
    debugPrint(
      '❌ [HTTP NETWORK] ${request.method} scheme=${uri.scheme} host=${uri.host}'
      ' port=${uri.hasPort ? uri.port : "(default)"} path=${uri.path} error=$error',
    );
    if (uri.scheme == 'http') {
      debugPrint(
        '❌ [HTTP NETWORK] Nếu chạy Android thật, kiểm tra API_BASE_URL dùng IP LAN laptop'
        ' và debug build cho phép cleartext HTTP.',
      );
    }
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

  http.Request _cloneRequest(http.Request request) {
    return http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..maxRedirects = request.maxRedirects
      ..followRedirects = request.followRedirects
      ..persistentConnection = request.persistentConnection
      ..bodyBytes = request.bodyBytes;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
