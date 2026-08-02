import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/change_request/change_request_model.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';

class ChangeRequestException implements Exception {
  const ChangeRequestException(this.message);
  final String message;
}

/// Service for change request (tenant-facing endpoints).
class ChangeRequestService {
  const ChangeRequestService({http.Client? client}) : _client = client;

  final http.Client? _client;
  http.Client get _effectiveClient => _client ?? AuthenticatedClient();
  static const _timeout = Duration(seconds: 20);

  // ── List (tenant's own requests, or filtered) ─────────────────────────────

  /// GET /api/v1/change-requests/my
  Future<List<ChangeRequest>> getMyRequests({
    ChangeRequestType? type,
    ChangeRequestStatus? status,
    String? search,
    int? roomId,
    String? roomCode,
    int page = 0,
    int size = 50,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      'sort': 'createdAt,desc',
    };
    if (type != null) query['type'] = type.key;
    if (status != null) query['status'] = status.key;
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final json = await _getJson(_uri('/change-requests/my', query));
    final list = _extractList(json);
    final requests = list.map(ChangeRequest.fromJson).toList(growable: false);
    return _filterRequestsByRoom(requests, roomId: roomId, roomCode: roomCode);
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  /// GET /api/v1/change-requests/stats
  Future<ChangeRequestStats> getStats() async {
    final json = await _getJson(_uri('/change-requests/stats'));
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return ChangeRequestStats.fromJson(data);
    }
    return const ChangeRequestStats(
      pending: 0,
      approvedToday: 0,
      rejectedToday: 0,
      thisMonth: 0,
    );
  }

  Future<ChangeRequest> confirmLiquidationDepositReceipt(int requestId) async {
    final json = await _postJson(
      _uri(
        '/change-requests/$requestId/liquidation/deposit-refund/confirm-receipt',
      ),
    );
    return _extractChangeRequest(json);
  }

  Future<ChangeRequest> disputeLiquidationDepositRefund(
    int requestId,
    String reason,
  ) async {
    final json = await _postJson(
      _uri('/change-requests/$requestId/liquidation/deposit-refund/dispute'),
      body: {'reason': reason},
    );
    return _extractChangeRequest(json);
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = _effectiveClient;
    try {
      final response = await client.get(uri).timeout(_timeout);
      return _decodeResponse(response);
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeout);
      return _decodeResponse(response);
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.bodyBytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    final json = body is Map<String, dynamic>
        ? body
        : Map<String, dynamic>.from(body as Map);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    final message =
        json['message']?.toString() ??
        json['error']?.toString() ??
        'Không thể tải danh sách yêu cầu.';
    throw ChangeRequestException(message);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> json) {
    Object? candidate = json['data'];
    if (candidate is Map) {
      candidate =
          candidate['data'] ?? candidate['items'] ?? candidate['content'];
    }
    candidate ??= json['items'] ?? json['content'];
    if (candidate is! List) return const [];
    return candidate
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  ChangeRequest _extractChangeRequest(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) {
      return ChangeRequest.fromJson(Map<String, dynamic>.from(data));
    }
    return ChangeRequest.fromJson(json);
  }

  List<ChangeRequest> _filterRequestsByRoom(
    List<ChangeRequest> requests, {
    int? roomId,
    String? roomCode,
  }) {
    final normalizedCode = roomCode?.trim().toLowerCase() ?? '';
    if ((roomId ?? 0) <= 0 && normalizedCode.isEmpty) {
      return requests;
    }
    return requests
        .where(
          (request) => _requestMatchesRoom(
            request,
            roomId: roomId,
            roomCode: normalizedCode,
          ),
        )
        .toList(growable: false);
  }

  bool _requestMatchesRoom(
    ChangeRequest request, {
    int? roomId,
    required String roomCode,
  }) {
    final payload = _payloadMap(request.requestPayload);
    final ids = <int?>[
      _asInt(payload['roomId'] ?? payload['room_id']),
      _asInt(payload['currentRoomId'] ?? payload['current_room_id']),
      _asInt(payload['sourceRoomId'] ?? payload['source_room_id']),
      _asInt(payload['oldRoomId'] ?? payload['old_room_id']),
      _asInt(payload['targetRoomId'] ?? payload['target_room_id']),
      _asInt(payload['newRoomId'] ?? payload['new_room_id']),
      _nestedInt(payload['room'], ['id', 'roomId', 'room_id']),
      _nestedInt(payload['oldRoom'], ['id', 'roomId', 'room_id']),
      _nestedInt(payload['targetRoom'], ['id', 'roomId', 'room_id']),
    ].whereType<int>();
    if ((roomId ?? 0) > 0 && ids.contains(roomId)) return true;

    if (roomCode.isEmpty) return false;
    final codes =
        <String>[
          payload['roomCode']?.toString() ?? '',
          payload['room_code']?.toString() ?? '',
          payload['currentRoomCode']?.toString() ?? '',
          payload['oldRoomCode']?.toString() ?? '',
          payload['targetRoomCode']?.toString() ?? '',
          payload['newRoomCode']?.toString() ?? '',
          payload['room']?.toString() ?? '',
          _nestedString(payload['room'], ['roomCode', 'room_code', 'code']),
          _nestedString(payload['oldRoom'], ['roomCode', 'room_code', 'code']),
          _nestedString(payload['targetRoom'], [
            'roomCode',
            'room_code',
            'code',
          ]),
        ].map((value) => value.trim().toLowerCase()).where((value) {
          return value.isNotEmpty && value != 'null';
        });
    return codes.any((value) => value == roomCode || value.contains(roomCode));
  }

  Map<String, dynamic> _payloadMap(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return const {};
    }
    return const {};
  }

  int? _nestedInt(Object? raw, List<String> keys) {
    final map = _asMap(raw);
    for (final key in keys) {
      final value = _asInt(map[key]);
      if (value != null) return value;
    }
    return null;
  }

  String _nestedString(Object? raw, List<String> keys) {
    final map = _asMap(raw);
    for (final key in keys) {
      final value = map[key]?.toString() ?? '';
      if (value.trim().isNotEmpty) return value;
    }
    return '';
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class ChangeRequestStats {
  const ChangeRequestStats({
    required this.pending,
    required this.approvedToday,
    required this.rejectedToday,
    required this.thisMonth,
    this.breakdownByType = const {},
  });

  final int pending;
  final int approvedToday;
  final int rejectedToday;
  final int thisMonth;
  final Map<String, int> breakdownByType;

  factory ChangeRequestStats.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['breakdownByType'];
    final breakdown = <String, int>{};
    if (breakdownRaw is Map) {
      breakdownRaw.forEach((k, v) {
        breakdown[k.toString()] = v is int
            ? v
            : int.tryParse(v.toString()) ?? 0;
      });
    }
    return ChangeRequestStats(
      pending: json['pending'] is int ? json['pending'] as int : 0,
      approvedToday: json['approvedToday'] is int
          ? json['approvedToday'] as int
          : 0,
      rejectedToday: json['rejectedToday'] is int
          ? json['rejectedToday'] as int
          : 0,
      thisMonth: json['thisMonth'] is int ? json['thisMonth'] as int : 0,
      breakdownByType: breakdown,
    );
  }
}
