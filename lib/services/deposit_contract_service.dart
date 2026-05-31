import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/contract_list_item_model.dart';
import 'authenticated_client.dart';

class DepositContractException implements Exception {
  const DepositContractException(this.message);

  final String message;
}

class DepositContractNotFoundException extends DepositContractException {
  const DepositContractNotFoundException() : super('Bạn chưa có hợp đồng cọc');
}

class DepositContractService {
  const DepositContractService({http.Client? client}) : _client = client;

  final http.Client? _client;
  http.Client get _effectiveClient => _client ?? AuthenticatedClient();
  static const _timeout = Duration(seconds: 10);

  Future<List<ContractListItem>> getMyDeposits({
    String? status,
    DateTime? signedFrom,
    DateTime? signedTo,
  }) async {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (signedFrom != null) {
      queryParams['signedFrom'] = signedFrom.toIso8601String();
    }
    if (signedTo != null) {
      queryParams['signedTo'] = signedTo.toIso8601String();
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/deposit-agreements/me',
    ).replace(queryParameters: queryParams);

    final client = _effectiveClient;
    try {
      final response = await client
          .get(
            uri,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        // Handle ApiResponse wrapper and PageResponse wrapper
        dynamic listData = body;
        if (body is Map<String, dynamic>) {
          if (body.containsKey('data')) {
            final data = body['data'];
            if (data is Map<String, dynamic> && data.containsKey('data')) {
              // It's a PageResponse
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
    final client = _effectiveClient;
    try {
      final response = await client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/deposit-agreements/$depositId'),
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
