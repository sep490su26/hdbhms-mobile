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

  Future<PropertyRulesResponse> getRules({int? tenantId}) async {
    final prefs = await SharedPreferences.getInstance();
    final currentTenantId = tenantId ?? prefs.getInt(AuthService.tenantIdKey);

    if (currentTenantId == null) {
      throw const PropertyRuleException('Không tìm thấy tenant hiện tại');
    }

    final client = _client == null
        ? AuthenticatedClient()
        : AuthenticatedClient(inner: _client);
    try {
      final response = await client
          .get(Uri.parse('${ApiConfig.baseUrl}/tenants/$currentTenantId/rules'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        await prefs.setString(_cacheKey(currentTenantId), response.body);
        return PropertyRulesResponse.fromJson(_decodeBody(response.body));
      }

      final cached = _readCache(prefs, currentTenantId);
      if (cached != null) {
        return cached.copyWith(isFromCache: true);
      }
      throw PropertyRuleException(_messageForError(response));
    } on PropertyRuleException {
      rethrow;
    } on TimeoutException {
      final cached = _readCache(prefs, currentTenantId);
      if (cached != null) {
        return cached.copyWith(isFromCache: true);
      }
      throw const PropertyRuleException('Không kết nối được máy chủ');
    } on http.ClientException {
      final cached = _readCache(prefs, currentTenantId);
      if (cached != null) {
        return cached.copyWith(isFromCache: true);
      }
      throw const PropertyRuleException('Không kết nối được máy chủ');
    } on FormatException {
      final cached = _readCache(prefs, currentTenantId);
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

  PropertyRulesResponse? _readCache(SharedPreferences prefs, int tenantId) {
    final raw = prefs.getString(_cacheKey(tenantId));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return PropertyRulesResponse.fromJson(_decodeBody(raw));
    } on FormatException {
      return null;
    }
  }

  String _cacheKey(int tenantId) => 'property_rules_cache_$tenantId';

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
