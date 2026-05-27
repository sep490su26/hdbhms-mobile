import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/contract_list_item_model.dart';
import '../models/lease_contract_model.dart';
import 'auth_service.dart';

class LeaseContractException implements Exception {
  const LeaseContractException(this.message);

  final String message;
}

class LeaseContractNotFoundException extends LeaseContractException {
  const LeaseContractNotFoundException()
    : super('Bạn chưa có hợp đồng thuê phòng đang hiệu lực');
}

class LeaseContractForbiddenException extends LeaseContractException {
  const LeaseContractForbiddenException()
    : super('Bạn không có quyền xem hợp đồng này');
}

class LeaseContractService {
  const LeaseContractService({http.Client? client}) : _client = client;

  final http.Client? _client;
  static const _timeout = Duration(seconds: 10);

  Future<LeaseContract> getMyActiveContract({int? tenantId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);
    final currentTenantId = tenantId ?? prefs.getInt(AuthService.tenantIdKey);

    if (token == null || token.isEmpty) {
      throw const LeaseContractForbiddenException();
    }
    if (currentTenantId == null) {
      throw const LeaseContractException('Không tìm thấy tenant hiện tại');
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/lease-contracts/me?status=ACTIVE&size=1',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = _decodeBody(response.body);
        // Extract from ApiResponse -> PageResponse -> List
        dynamic data;
        if (body.containsKey('data')) {
          final payload = body['data'];
          if (payload is Map<String, dynamic> && payload.containsKey('data')) {
            final list = payload['data'];
            if (list is List && list.isNotEmpty) {
              data = list.first;
            }
          } else {
            data = payload;
          }
        }
        
        if (data == null) {
          throw const LeaseContractNotFoundException();
        }
        return LeaseContract.fromJson(data);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const LeaseContractForbiddenException();
      }
      if (response.statusCode == 404) {
        throw const LeaseContractNotFoundException();
      }

      throw LeaseContractException(_messageForError(response));
    } on LeaseContractException {
      rethrow;
    } on TimeoutException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on FormatException {
      throw const LeaseContractException('Không tải được dữ liệu hợp đồng');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<List<ContractListItem>> getMyContracts({
    String? status,
    DateTime? signedFrom,
    DateTime? signedTo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);

    if (token == null || token.isEmpty) {
      throw const LeaseContractForbiddenException();
    }

    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (signedFrom != null) {
      queryParams['signedFrom'] = signedFrom.toIso8601String();
    }
    if (signedTo != null) {
      queryParams['signedTo'] = signedTo.toIso8601String();
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/lease-contracts/me')
        .replace(queryParameters: queryParams);

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        dynamic listData = body;
        if (body is Map<String, dynamic>) {
          if (body.containsKey('data')) {
            final data = body['data'];
            if (data is Map<String, dynamic> && data.containsKey('data')) {
              listData = data['data'];
            } else {
              listData = data;
            }
          }
        }
        final List<dynamic> list = listData is List ? listData : [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(ContractListItem.fromJson)
            .toList(growable: false);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const LeaseContractForbiddenException();
      }
      throw LeaseContractException(_messageForError(response));
    } on LeaseContractException {
      rethrow;
    } on TimeoutException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on FormatException {
      throw const LeaseContractException('Không tải được danh sách hợp đồng');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<LeaseContract> getContractById(int contractId, {int? tenantId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);
    // final currentTenantId = tenantId ?? prefs.getInt(AuthService.tenantIdKey);

    if (token == null || token.isEmpty) {
      throw const LeaseContractForbiddenException();
    }
    // if (currentTenantId == null) {
    //   throw const LeaseContractException('Không tìm thấy tenant hiện tại');
    // }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/lease-contracts/$contractId',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = _decodeBody(response.body);
        final data = _contractPayload(body);
        if (data == null) {
          throw const LeaseContractNotFoundException();
        }
        return LeaseContract.fromJson(data);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const LeaseContractForbiddenException();
      }
      if (response.statusCode == 404) {
        throw const LeaseContractNotFoundException();
      }
      throw LeaseContractException(_messageForError(response));
    } on LeaseContractException {
      rethrow;
    } on TimeoutException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on FormatException {
      throw const LeaseContractException('Không tải được dữ liệu hợp đồng');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Map<String, dynamic>? _contractPayload(Map<String, dynamic> body) {
    for (final key in ['data', 'contract', 'lease_contract', 'leaseContract']) {
      final value = body[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }

    if (body.isEmpty) {
      return null;
    }
    final hasContractFields = [
      'id',
      'contract_id',
      'contract_code',
      'contractCode',
      'status',
      'room',
      'monthly_rent',
      'monthlyRent',
    ].any(body.containsKey);
    if (!hasContractFields) {
      return null;
    }
    return body;
  }

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
    return 'Không tải được dữ liệu hợp đồng';
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Invalid response body');
  }
}
