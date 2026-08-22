import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/auth/login_response.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    required this.token,
    this.refreshResponse,
    this.tokenSequence,
  });

  final String? token;
  final LoginResponse? refreshResponse;
  final List<String?>? tokenSequence;
  int refreshCalls = 0;
  int accessTokenReads = 0;

  @override
  Future<String?> get accessToken async {
    final sequence = tokenSequence;
    if (sequence == null || sequence.isEmpty) {
      return token;
    }
    final index = accessTokenReads++;
    return sequence[index < sequence.length ? index : sequence.length - 1];
  }

  @override
  Future<LoginResponse> refreshToken() async {
    refreshCalls++;
    final response = refreshResponse;
    if (response == null) {
      throw const SessionExpiredException();
    }
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('403 response does not refresh or clear local session', () async {
    SharedPreferences.setMockInitialValues({
      AuthService.accessTokenKey: 'old-token',
      AuthService.sessionIdKey: 'session-1',
    });

    final authService = _FakeAuthService(
      token: 'old-token',
      refreshResponse: const LoginResponse(
        token: 'new-token',
        sessionId: 'session-1',
        role: 'TENANT',
        authorized: true,
      ),
    );
    final client = AuthenticatedClient(
      authService: authService,
      inner: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer old-token');
        return http.Response('forbidden', 403);
      }),
    );

    final response = await client.get(
      Uri.parse('https://example.test/api/v1/files/download/44'),
    );
    client.close();

    expect(response.statusCode, 403);
    expect(response.body, 'forbidden');
    expect(authService.refreshCalls, 0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AuthService.accessTokenKey), 'old-token');
    expect(prefs.getString(AuthService.sessionIdKey), 'session-1');
  });

  test('401 response refreshes and retries retryable requests', () async {
    SharedPreferences.setMockInitialValues({
      AuthService.accessTokenKey: 'old-token',
      AuthService.sessionIdKey: 'session-1',
    });

    var requestCount = 0;
    final authService = _FakeAuthService(
      token: 'old-token',
      refreshResponse: const LoginResponse(
        token: 'new-token',
        sessionId: 'session-1',
        role: 'TENANT',
        authorized: true,
      ),
    );
    final client = AuthenticatedClient(
      authService: authService,
      inner: MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          expect(request.headers['Authorization'], 'Bearer old-token');
          return http.Response('expired', 401);
        }
        expect(request.headers['Authorization'], 'Bearer new-token');
        return http.Response('ok', 200);
      }),
    );

    final response = await client.get(
      Uri.parse('https://example.test/api/v1/protected'),
    );
    client.close();

    expect(response.statusCode, 200);
    expect(response.body, 'ok');
    expect(authService.refreshCalls, 1);
    expect(requestCount, 2);
  });

  test('401 reuses a token refreshed by another request', () async {
    SharedPreferences.setMockInitialValues({
      AuthService.accessTokenKey: 'new-token',
      AuthService.sessionIdKey: 'session-1',
    });

    final authService = _FakeAuthService(
      token: 'old-token',
      tokenSequence: ['old-token', 'new-token'],
      refreshResponse: const LoginResponse(
        token: 'refresh-token',
        sessionId: 'session-1',
        role: 'TENANT',
        authorized: true,
      ),
    );
    var requestCount = 0;
    final client = AuthenticatedClient(
      authService: authService,
      inner: MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          expect(request.headers['Authorization'], 'Bearer old-token');
          return http.Response('expired', 401);
        }
        expect(request.headers['Authorization'], 'Bearer new-token');
        return http.Response('ok', 200);
      }),
    );

    final response = await client.get(
      Uri.parse('https://example.test/api/v1/protected'),
    );
    client.close();

    expect(response.statusCode, 200);
    expect(authService.refreshCalls, 0);
    expect(requestCount, 2);
  });
}
