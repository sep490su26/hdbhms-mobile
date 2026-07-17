import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/contract/contract_list_item_model.dart';
import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';

class LeaseContractException implements Exception {
  const LeaseContractException(this.message);

  final String message;
}

class ActiveRoomItem {
  const ActiveRoomItem({
    required this.contractId,
    required this.contractCode,
    required this.roomId,
    required this.roomCode,
    required this.roomName,
    required this.propertyName,
    this.propertyId = 0,
    this.roomStatus = '',
    this.contractStatus = '',
    this.roleInContract = '',
    this.startDate,
    this.endDate,
    this.occupantCount = 0,
  });

  final int contractId;
  final String contractCode;
  final int roomId;
  final String roomCode;
  final String roomName;
  final int propertyId;
  final String propertyName;
  final String roomStatus;
  final String contractStatus;
  final String roleInContract;
  final DateTime? startDate;
  final DateTime? endDate;
  final int occupantCount;

  factory ActiveRoomItem.fromJson(Map<String, dynamic> json) {
    return ActiveRoomItem(
      contractId: _asInt(json['contractId'] ?? json['contract_id']) ?? 0,
      contractCode:
          json['contractCode']?.toString() ??
          json['contract_code']?.toString() ??
          '',
      roomId: _asInt(json['roomId'] ?? json['room_id']) ?? 0,
      roomCode:
          json['roomCode']?.toString() ?? json['room_code']?.toString() ?? '',
      roomName:
          json['roomName']?.toString() ?? json['room_name']?.toString() ?? '',
      propertyId: _asInt(json['propertyId'] ?? json['property_id']) ?? 0,
      propertyName:
          json['propertyName']?.toString() ??
          json['property_name']?.toString() ??
          '',
      roomStatus:
          json['roomStatus']?.toString() ??
          json['room_status']?.toString() ??
          json['currentStatus']?.toString() ??
          json['current_status']?.toString() ??
          '',
      contractStatus:
          json['contractStatus']?.toString() ??
          json['contract_status']?.toString() ??
          '',
      roleInContract:
          json['roleInContract']?.toString() ??
          json['role_in_contract']?.toString() ??
          '',
      startDate: DateTime.tryParse(
        json['startDate']?.toString() ?? json['start_date']?.toString() ?? '',
      ),
      endDate: DateTime.tryParse(
        json['endDate']?.toString() ?? json['end_date']?.toString() ?? '',
      ),
      occupantCount:
          _asInt(json['occupantCount'] ?? json['occupant_count']) ?? 0,
    );
  }

  String get displayLabel {
    final name = roomName.trim();
    final code = roomCode.trim();
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return 'Phòng $code';
    return 'Phòng';
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
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
  http.Client get _effectiveClient => _client ?? AuthenticatedClient();
  static const _timeout = Duration(seconds: 20);

  Future<LeaseContract> getMyActiveContract({int? tenantId}) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/lease-contracts/me?status=ACTIVE&size=1',
            ),
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
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (signedFrom != null) {
      queryParams['signedFrom'] = signedFrom.toIso8601String();
    }
    if (signedTo != null) {
      queryParams['signedTo'] = signedTo.toIso8601String();
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/lease-contracts/me',
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

  Future<List<ActiveRoomItem>> fetchMyActiveRooms() async {
    final client = _effectiveClient;
    try {
      final response = await client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/lease-contracts/me/active-rooms'),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        dynamic listData;
        if (body is Map<String, dynamic> && body.containsKey('data')) {
          listData = body['data'];
        }
        final List<dynamic> list = listData is List ? listData : [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(ActiveRoomItem.fromJson)
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
      throw const LeaseContractException('Không tải được danh sách phòng');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<LeaseContract> getContractById(int contractId, {int? tenantId}) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .get(Uri.parse('${ApiConfig.baseUrl}/lease-contracts/$contractId'))
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

  Future<LeaseContract> recordIntention({
    required int contractId,
    required String intention,
    DateTime? expectedMoveOutDate,
    String note = '',
  }) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/tenant/contracts/$contractId/intention',
            ),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'intention': intention,
              'expectedMoveOutDate': expectedMoveOutDate == null
                  ? null
                  : _dateOnlyString(expectedMoveOutDate),
              'note': note.trim().isEmpty ? null : note.trim(),
            }),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return getContractById(contractId);
      }
      throw LeaseContractException(_messageForIntentionError(response));
    } on LeaseContractException {
      rethrow;
    } on TimeoutException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on FormatException {
      throw const LeaseContractException(
        'Không thể lưu ý định. Vui lòng thử lại.',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<void> submitLiquidationRequest({
    required int contractId,
    String reason = '',
  }) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/lease-contracts/$contractId/liquidation-requests',
            ),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'reason': reason.trim().isEmpty ? null : reason.trim(),
            }),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      throw LeaseContractException(_messageForLifecycleRequestError(response));
    } on LeaseContractException {
      rethrow;
    } on TimeoutException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on FormatException {
      throw const LeaseContractException(
        'Không thể gửi yêu cầu. Vui lòng thử lại.',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<void> submitRenewalRequest({
    required int contractId,
    required DateTime newStartDate,
    required DateTime newEndDate,
    required num monthlyRent,
    required int paymentCycleMonths,
    required num depositAmount,
    String note = '',
  }) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/lease-contracts/$contractId/renewal-requests',
            ),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'newStartDate': _dateOnlyString(newStartDate),
              'newEndDate': _dateOnlyString(newEndDate),
              'monthlyRent': monthlyRent.round(),
              'paymentCycleMonths': paymentCycleMonths,
              'depositAmount': depositAmount.round(),
              'note': note.trim().isEmpty ? null : note.trim(),
            }),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      throw LeaseContractException(_messageForLifecycleRequestError(response));
    } on LeaseContractException {
      rethrow;
    } on TimeoutException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const LeaseContractException('Không kết nối được máy chủ');
    } on FormatException {
      throw const LeaseContractException(
        'Không thể gửi yêu cầu. Vui lòng thử lại.',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<void> submitAddCoOccupantRequest({
    required int contractId,
    required String fullName,
    required String phone,
    String email = '',
    String note = '',
  }) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/lease-contracts/$contractId/co-occupant-requests',
            ),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': fullName.trim(),
              'phone': phone.trim(),
              'email': email.trim().isEmpty ? null : email.trim(),
              'note': note.trim().isEmpty ? null : note.trim(),
            }),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      throw LeaseContractException(_messageForLifecycleRequestError(response));
    } on LeaseContractException {
      rethrow;
    } on TimeoutException {
      throw const LeaseContractException(
        'KhÃ´ng káº¿t ná»‘i Ä‘Æ°á»£c mÃ¡y chá»§',
      );
    } on http.ClientException {
      throw const LeaseContractException(
        'KhÃ´ng káº¿t ná»‘i Ä‘Æ°á»£c mÃ¡y chá»§',
      );
    } on FormatException {
      throw const LeaseContractException(
        'KhÃ´ng thá»ƒ gá»­i yÃªu cáº§u. Vui lÃ²ng thá»­ láº¡i.',
      );
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

  String _messageForIntentionError(http.Response response) {
    final raw = _messageForError(response);
    if (raw.contains('CONTRACT_INTENTION_PRIMARY_ONLY')) {
      return 'Chỉ người ký chính của hợp đồng mới được ghi nhận ý định.';
    }
    if (raw.contains('EXPECTED_MOVE_OUT_DATE_REQUIRED')) {
      return 'Vui lòng chọn ngày dự kiến trả phòng.';
    }
    if (raw.contains('EXPECTED_MOVE_OUT_DATE_IN_PAST')) {
      return 'Ngày dự kiến trả phòng không được trước ngày hiện tại.';
    }
    if (raw.contains('EXPECTED_MOVE_OUT_DATE_AFTER_CONTRACT_END')) {
      return 'Ngày dự kiến trả phòng không được sau ngày kết thúc hợp đồng.';
    }
    if (raw.contains('ROOM_HOLD_IN_PROGRESS') ||
        raw.contains('ROOM_ALREADY_RESERVED_FOR_FUTURE') ||
        raw.contains('ROOM_ALREADY_RESERVED_BY_NEW_TENANT')) {
      return 'Phòng đã có khách khác đặt cọc/giữ chỗ, không thể gia hạn. Vui lòng liên hệ quản lý.';
    }
    if (raw.trim().isNotEmpty && !raw.contains('Không tải')) {
      return raw;
    }
    return 'Không thể lưu ý định. Vui lòng thử lại.';
  }

  String _messageForLifecycleRequestError(http.Response response) {
    final raw = _messageForError(response);
    if (response.statusCode == 409 || raw.contains('dang cho duyet')) {
      return 'Hợp đồng đã có yêu cầu đang chờ duyệt.';
    }
    if (response.statusCode == 403) {
      return 'Bạn không có quyền gửi yêu cầu cho hợp đồng này.';
    }
    if (raw.trim().isNotEmpty && !raw.contains('Không tải')) {
      return raw;
    }
    return 'Không thể gửi yêu cầu. Vui lòng thử lại.';
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Invalid response body');
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

  dynamic _unwrapEnvelope(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  String _dateOnlyString(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
