import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hdbhms_mobile/config/api_config.dart';

class ForgotPasswordException implements Exception {
  const ForgotPasswordException(this.message);

  final String message;
}

class ForgotPasswordService {
  const ForgotPasswordService({http.Client? client}) : _client = client;

  static const _timeout = Duration(seconds: 20);
  final http.Client? _client;

  /// Phase 1: Request a password reset. 
  /// The backend will send an email containing a reset token (or magic link).
  Future<void> requestResetPassword(String email) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      throw ForgotPasswordException(
        _messageForDefaultError(
          response,
          'Không gửi được yêu cầu cấp lại mật khẩu, vui lòng thử lại',
        ),
      );
    } on TimeoutException {
      throw const ForgotPasswordException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const ForgotPasswordException('Không kết nối được máy chủ');
    } on FormatException {
      throw const ForgotPasswordException(
        'Có lỗi xảy ra, vui lòng thử lại',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  /// Phase 2: Reset the password using the token received in the email.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/reset-password'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'token': token.trim(),
              'new_password': newPassword,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      throw ForgotPasswordException(
        _messageForDefaultError(response, 'Đặt lại mật khẩu thất bại'),
      );
    } on TimeoutException {
      throw const ForgotPasswordException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const ForgotPasswordException('Không kết nối được máy chủ');
    } on FormatException {
      throw const ForgotPasswordException('Đặt lại mật khẩu thất bại');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _messageForDefaultError(http.Response response, String fallback) {
    try {
      final body = _decodeBody(response.body);
      final message = body['message']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return message;
      }
    } catch (_) {
      return fallback;
    }
    return fallback;
  }
}
