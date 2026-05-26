import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ForgotPasswordException implements Exception {
  const ForgotPasswordException(this.message);

  final String message;
}

class ForgotPasswordVerifyResult {
  const ForgotPasswordVerifyResult({required this.resetToken});

  final String resetToken;
}

class ForgotPasswordService {
  const ForgotPasswordService({http.Client? client}) : _client = client;

  static const _timeout = Duration(seconds: 10);
  final http.Client? _client;

  Future<void> sendForgotPasswordOtp(String email) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password/request-otp'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      throw ForgotPasswordException(
        _messageForDefaultError(
          response,
          'Không gửi được mã OTP, vui lòng thử lại',
        ),
      );
    } on TimeoutException {
      throw const ForgotPasswordException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const ForgotPasswordException('Không kết nối được máy chủ');
    } on FormatException {
      throw const ForgotPasswordException(
        'Không gửi được mã OTP, vui lòng thử lại',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<ForgotPasswordVerifyResult> verifyForgotPasswordOtp({
    required String email,
    required String otp,
  }) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password/verify-otp'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'email': email.trim(), 'otp': otp.trim()}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = _decodeBody(response.body);
        return ForgotPasswordVerifyResult(
          resetToken: body['reset_token']?.toString() ?? '',
        );
      }

      throw ForgotPasswordException(
        _messageForDefaultError(response, 'Mã OTP không đúng hoặc đã hết hạn'),
      );
    } on TimeoutException {
      throw const ForgotPasswordException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const ForgotPasswordException('Không kết nối được máy chủ');
    } on FormatException {
      throw const ForgotPasswordException('Xác minh OTP thất bại');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password/reset'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': email.trim(),
              'reset_token': resetToken,
              'new_password': newPassword,
              'confirm_password': confirmPassword,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      throw ForgotPasswordException(
        _messageForDefaultError(response, 'Đổi mật khẩu thất bại'),
      );
    } on TimeoutException {
      throw const ForgotPasswordException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const ForgotPasswordException('Không kết nối được máy chủ');
    } on FormatException {
      throw const ForgotPasswordException('Đổi mật khẩu thất bại');
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
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
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
