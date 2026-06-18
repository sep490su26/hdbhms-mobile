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

    debugPrint('➡️ [HTTP REQUEST] ${request.method} ${request.url}');
    if (request is http.Request) {
      debugPrint('➡️ [BODY] ${request.body}');
    }

    final response = await _inner.send(request);

    // Read the response stream so we can log it, then reconstruct it
    final responseBytes = await response.stream.toBytes();
    String bodyString = '';
    try {
      bodyString = String.fromCharCodes(responseBytes);
    } catch (e) {
      bodyString = '[Binary Data]';
    }

    debugPrint('⬅️ [HTTP RESPONSE] ${response.statusCode} ${request.url}');
    debugPrint('⬅️ [BODY] $bodyString');

    final clonedResponse = http.StreamedResponse(
      Stream.value(responseBytes),
      response.statusCode,
      contentLength: response.contentLength ?? responseBytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );

    if (clonedResponse.statusCode == 401 || clonedResponse.statusCode == 403) {
      final isRetryable = request is http.Request;
      if (!isRetryable) {
        // Cannot retry streams safely
        return clonedResponse;
      }

      try {
        final newLoginData = await authService.refreshToken();

        final newRequest = _cloneRequest(request);
        newRequest.headers['Authorization'] = 'Bearer ${newLoginData.token}';

        debugPrint('🔄 [HTTP RETRY] ${newRequest.method} ${newRequest.url}');
        return await _inner.send(newRequest);
      } catch (e) {
        await AuthService.clearLocalSession();
        _redirectToLogin();
        return clonedResponse;
      }
    }

    return clonedResponse;
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
