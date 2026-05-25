import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/contract_list_item_model.dart';
import 'auth_service.dart';

class DepositContractException implements Exception {
  const DepositContractException(this.message);

  final String message;
}

class DepositContractNotFoundException extends DepositContractException {
  const DepositContractNotFoundException()
    : super('Bạn chưa có hợp đồng cọc');
}

class DepositContractService {
  const DepositContractService({http.Client? client}) : _client = client;

  final http.Client? _client;
  static const _timeout = Duration(seconds: 10);

  Future<List<ContractListItem>> getMyDeposits({int? tenantId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);
    final currentTenantId = tenantId ?? prefs.getInt(AuthService.tenantIdKey);

    if (token == null || token.isEmpty) {
      throw const DepositContractException('Bạn không có quyền xem');
    }
    if (currentTenantId == null) {
      throw const DepositContractException('Không tìm thấy tenant hiện tại');
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/tenants/$currentTenantId/deposits/my-list',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> list = body is List ? body : (body['data'] ?? []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(ContractListItem.fromJson)
            .toList(growable: false);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const DepositContractException('Bạn không có quyền xem');
      }
      throw DepositContractException(_messageForError(response));
    } on DepositContractException {
      rethrow;
    } on TimeoutException {
      throw const DepositContractException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const DepositContractException('Không kết nối được máy chủ');
    } on FormatException {
      throw const DepositContractException('Không tải được danh sách HĐ cọc');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<DepositContract> getDepositById(int depositId, {int? tenantId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);
    final currentTenantId = tenantId ?? prefs.getInt(AuthService.tenantIdKey);

    if (token == null || token.isEmpty) {
      throw const DepositContractException('Bạn không có quyền xem');
    }
    if (currentTenantId == null) {
      throw const DepositContractException('Không tìm thấy tenant hiện tại');
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/tenants/$currentTenantId/deposits/$depositId',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final Map<String, dynamic> data =
            body is Map<String, dynamic> && body.containsKey('data')
                ? body['data'] as Map<String, dynamic>
                : body as Map<String, dynamic>;
        return DepositContract.fromJson(data);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const DepositContractException('Bạn không có quyền xem');
      }
      if (response.statusCode == 404) {
        throw const DepositContractNotFoundException();
      }
      throw DepositContractException(_messageForError(response));
    } on DepositContractException {
      rethrow;
    } on TimeoutException {
      throw const DepositContractException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const DepositContractException('Không kết nối được máy chủ');
    } on FormatException {
      throw const DepositContractException('Không tải được dữ liệu HĐ cọc');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  String _messageForError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final message = data['message'] ?? data['error'];
        if (message != null && message.toString().isNotEmpty) {
          return message.toString();
        }
      }
    } on FormatException {
      // Fall through
    }
    return 'Không tải được dữ liệu HĐ cọc';
  }
}
