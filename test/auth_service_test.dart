import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'refresh sends the session cookie and preserves mobile context',
    () async {
      SharedPreferences.setMockInitialValues({
        AuthService.accessTokenKey: 'old-token',
        AuthService.sessionIdKey: 'session-1',
        AuthService.tenantIdKey: 58,
        AuthService.propertyIdKey: 7,
        AuthService.roleKey: 'TENANT',
      });

      final client = MockClient((request) async {
        expect(request.headers['Cookie'], 'JSESSIONID=session-1');
        expect(jsonDecode(request.body), {'sessionId': 'session-1'});
        return http.Response(
          jsonEncode({
            'code': 0,
            'data': {
              'token': 'new-token',
              'role': 'TENANT',
              'authorized': true,
            },
          }),
          200,
        );
      });

      final response = await AuthService(client: client).refreshToken();
      final prefs = await SharedPreferences.getInstance();

      expect(response.token, 'new-token');
      expect(prefs.getString(AuthService.accessTokenKey), 'new-token');
      expect(prefs.getString(AuthService.sessionIdKey), 'session-1');
      expect(prefs.getInt(AuthService.tenantIdKey), 58);
      expect(prefs.getInt(AuthService.propertyIdKey), 7);
    },
  );

  test('concurrent refresh calls share one network request', () async {
    SharedPreferences.setMockInitialValues({
      AuthService.sessionIdKey: 'session-1',
    });

    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response(
        jsonEncode({
          'code': 0,
          'data': {
            'token': 'new-token',
            'sessionId': 'session-1',
            'role': 'TENANT',
            'authorized': true,
          },
        }),
        200,
      );
    });

    final service = AuthService(client: client);
    final responses = await Future.wait([
      service.refreshToken(),
      service.refreshToken(),
    ]);

    expect(requestCount, 1);
    expect(responses.map((response) => response.token), [
      'new-token',
      'new-token',
    ]);
  });
}
