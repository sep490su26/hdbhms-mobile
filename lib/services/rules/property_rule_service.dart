import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/rules/property_rule_model.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';

class PropertyRuleException implements Exception {
  const PropertyRuleException(this.message);

  final String message;
}

class PropertyRuleService {
  const PropertyRuleService({http.Client? client}) : _client = client;

  final http.Client? _client;
  static const _timeout = Duration(seconds: 20);

  Future<PropertyRulesResponse> getRules({int? propertyId}) async {
    final prefs = await SharedPreferences.getInstance();
    final currentPropertyId =
        propertyId ?? prefs.getInt(AuthService.propertyIdKey);

    if (currentPropertyId == null) {
      throw const PropertyRuleException('Không tìm thấy nhà trọ hiện tại');
    }

    final client = _client == null
        ? AuthenticatedClient()
        : AuthenticatedClient(inner: _client);
    try {
      final response = await client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/properties/$currentPropertyId/rules',
            ),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        await prefs.setString(_cacheKey(currentPropertyId), response.body);
        return PropertyRulesResponse.fromJson(_decodeBody(response.body));
      }

      final cached = _readCache(prefs, currentPropertyId);
      if (cached != null) {
        return cached.copyWith(isFromCache: true);
      }
      throw PropertyRuleException(_messageForError(response));
    } on PropertyRuleException {
      rethrow;
    } on TimeoutException {
      final cached = _readCache(prefs, currentPropertyId);
      if (cached != null) {
        return cached.copyWith(isFromCache: true);
      }
      throw const PropertyRuleException('Không kết nối được máy chủ');
    } on http.ClientException {
      final cached = _readCache(prefs, currentPropertyId);
      if (cached != null) {
        return cached.copyWith(isFromCache: true);
      }
      throw const PropertyRuleException('Không kết nối được máy chủ');
    } on FormatException {
      final cached = _readCache(prefs, currentPropertyId);
      if (cached != null) {
        return cached.copyWith(isFromCache: true);
      }
      throw const PropertyRuleException('Không tải được nội quy');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  PropertyRulesResponse? _readCache(SharedPreferences prefs, int propertyId) {
    final raw = prefs.getString(_cacheKey(propertyId));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return PropertyRulesResponse.fromJson(_decodeBody(raw));
    } on FormatException {
      return null;
    }
  }

  String _cacheKey(int propertyId) => 'property_rules_cache_$propertyId';

  String _messageForError(http.Response response) {
    try {
      final data = _decodeBody(response.body);
      final message = data['message'] ?? data['error'];
      if (message != null && message.toString().isNotEmpty) {
        return message.toString();
      }
    } on FormatException {
      // Fall through to generic message.
    }
    return 'Không tải được nội quy';
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Invalid response body');
  }
}
