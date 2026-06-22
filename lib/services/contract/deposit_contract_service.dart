import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/contract/contract_list_item_model.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';

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
  static const _timeout = Duration(seconds: 20);

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
      final response = await client.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = _extractListPayload(body);
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
          .get(Uri.parse('${ApiConfig.baseUrl}/deposit-agreements/$depositId'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = _extractMapPayload(body);
        if (data == null) {
          throw const DepositContractNotFoundException();
        }
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

  List<dynamic> _extractListPayload(dynamic body) {
    final payload = _unwrapEnvelope(body);
    if (payload is List) return payload;
    if (payload is Map<String, dynamic>) {
      for (final key in ['data', 'items', 'content', 'records']) {
        final value = payload[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  Map<String, dynamic>? _extractMapPayload(dynamic body) {
    final payload = _unwrapEnvelope(body);
    if (payload is Map<String, dynamic>) return payload;
    return null;
  }

  dynamic _unwrapEnvelope(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}
