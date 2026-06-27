import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';

class RoomTransferException implements Exception {
  const RoomTransferException(this.message);
  final String message;
}

/// Service for room transfer (tenant-facing endpoints).
class RoomTransferService {
  const RoomTransferService({http.Client? client}) : _client = client;

  final http.Client? _client;
  http.Client get _effectiveClient => _client ?? AuthenticatedClient();
  static const _timeout = Duration(seconds: 20);

  // ── Create ────────────────────────────────────────────────────────────────

  /// POST /api/v1/occupant-transfer-requests
  Future<int> createTransferRequest({
    required int sourceContractId,
    required int targetRoomId,
    required DateTime requestedTransferDate,
    List<int>? transferredTenantProfileIds,
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'sourceContractId': sourceContractId,
      'targetRoomId': targetRoomId,
      'requestedTransferDate': _dateOnly(requestedTransferDate),
      if (transferredTenantProfileIds != null &&
          transferredTenantProfileIds.isNotEmpty)
        'transferredTenantProfileIds': transferredTenantProfileIds,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };
    final json = await _postJson(
      _uri('/occupant-transfer-requests'),
      body,
    );
    // Backend returns the transfer request ID as Long directly.
    final data = json['data'];
    if (data is int) return data;
    if (data is num) return data.toInt();
    if (data is Map<String, dynamic>) {
      return _asInt(data['id']) ?? 0;
    }
    return 0;
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  /// POST /api/v1/occupant-transfer-requests/{id}/cancel
  Future<void> cancelTransferRequest(int requestId) async {
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/cancel'),
      {},
    );
  }

  // ── Get by ID (placeholder – backend needs GET endpoint) ──────────────────

  /// GET /occupant-transfer-requests/{id}
  /// Note: Requires backend to expose this endpoint.
  Future<RoomTransferRequest> getTransferRequest(int requestId) async {
    final json = await _getJson(
      _uri('/occupant-transfer-requests/$requestId'),
    );
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return RoomTransferRequest.fromJson(data);
    }
    return RoomTransferRequest.fromJson(json);
  }

  // ── Get by request code ─────────────────────────────────────────────────────

  /// GET /occupant-transfer-requests/code/{requestCode}
  Future<RoomTransferRequest> getTransferRequestByCode(String requestCode) async {
    final json = await _getJson(
      _uri('/occupant-transfer-requests/code/$requestCode'),
    );
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return RoomTransferRequest.fromJson(data);
    }
    return RoomTransferRequest.fromJson(json);
  }

  // ── Pending Approvals (for target holder) ────────────────────────────────

  /// GET /occupant-transfer-requests/pending-target-holder-approvals
  /// Returns transfer requests awaiting current user's approval as target contract holder.
  /// Note: Requires backend to expose this endpoint.
  Future<List<RoomTransferRequest>> fetchPendingTargetHolderApprovals() async {
    final json = await _getJson(
      _uri('/occupant-transfer-requests/pending-target-holder-approvals'),
    );
    final list = _extractList(json);
    return list
        .map(RoomTransferRequest.fromJson)
        .toList(growable: false);
  }

  // ── Holder nomination ─────────────────────────────────────────────────────

  /// POST /api/v1/occupant-transfer-requests/{id}/holder-replacement
  Future<void> nominateHolder({
    required int requestId,
    required int nominatedHolderProfileId,
  }) async {
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/holder-replacement'),
      {'nominatedHolderProfileId': nominatedHolderProfileId},
    );
  }

  /// POST /api/v1/occupant-transfer-requests/{id}/accept-holder-nomination
  Future<void> acceptHolderNomination(int requestId) async {
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/accept-holder-nomination'),
      {},
    );
  }

  // ── Contract ──────────────────────────────────────────────────────────────

  /// POST /api/v1/occupant-transfer-requests/{id}/contract/confirm
  Future<void> confirmTransferContract(int requestId) async {
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/contract/confirm'),
      {},
    );
  }

  /// POST /api/v1/occupant-transfer-requests/{id}/contract/sign
  Future<void> signTransferContract(int requestId) async {
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/contract/sign'),
      {},
    );
  }

  /// POST /api/v1/occupant-transfer-requests/{id}/contract/reject
  Future<void> rejectTransferContract(int requestId) async {
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/contract/reject'),
      {},
    );
  }

  // ── Target holder approval (other-contract transfers) ─────────────────────

  /// POST /api/v1/occupant-transfer-requests/{id}/target-holder/approve
  Future<void> approveTargetHolderTransfer(int requestId) async {
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/target-holder/approve'),
      {},
    );
  }

  /// POST /api/v1/occupant-transfer-requests/{id}/target-holder/reject
  Future<void> rejectTargetHolderTransfer(int requestId) async {
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/target-holder/reject'),
      {},
    );
  }

  // ── Execute ───────────────────────────────────────────────────────────────

  /// POST /api/v1/occupant-transfer-requests/{id}/execute
  Future<void> executeTransfer({
    required int requestId,
    TransferHandoverData? transferOutHandover,
    TransferHandoverData? transferInHandover,
  }) async {
    final body = <String, dynamic>{};
    if (transferOutHandover != null) {
      body['transferOutHandover'] = transferOutHandover.toJson();
    }
    if (transferInHandover != null) {
      body['transferInHandover'] = transferInHandover.toJson();
    }
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/execute'),
      body,
    );
  }

  // ── Rooms (for picker) ────────────────────────────────────────────────────

  /// GET /api/v1/rooms — list available rooms for transfer target.
  Future<List<AvailableRoom>> fetchAvailableRooms({
    required int propertyId,
    int page = 0,
    int size = 50,
  }) async {
    final json = await _getJson(
      _uriWithApiPrefix('/rooms', {
        'propertyId': propertyId.toString(),
        'page': page.toString(),
        'size': size.toString(),
      }),
    );
    final list = _extractList(json);
    return list
        .map(AvailableRoom.fromJson)
        .toList(growable: false);
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
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .post(uri, body: jsonEncode(_withoutNulls(body)))
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
        json['detail']?.toString() ??
        'Không thể thực hiện yêu cầu chuyển phòng.';
    throw RoomTransferException(message);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    // RoomTransferController is at /occupant-transfer-requests (no /api/v1 prefix)
    final base = ApiConfig.baseUrl.replaceAll('/api/v1', '');
    return Uri.parse('$base$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  /// For endpoints that DO have /api/v1 prefix (e.g. /rooms).
  Uri _uriWithApiPrefix(String path, [Map<String, String>? query]) {
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
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

  Map<String, dynamic> _withoutNulls(Map<String, dynamic> body) {
    return Map<String, dynamic>.fromEntries(
      body.entries.where((entry) => entry.value != null),
    );
  }

  String _dateOnly(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

/// Handover data payload for the execute-transfer endpoint.
class TransferHandoverData {
  const TransferHandoverData({
    required this.handoverDate,
    required this.electricity,
    required this.water,
    this.note,
    this.assets = const [],
  });

  final DateTime handoverDate;
  final MeterReadingData electricity;
  final MeterReadingData water;
  final String? note;
  final List<AssetData> assets;

  Map<String, dynamic> toJson() {
    return {
      'handoverDate':
          '${handoverDate.year.toString().padLeft(4, '0')}-'
          '${handoverDate.month.toString().padLeft(2, '0')}-'
          '${handoverDate.day.toString().padLeft(2, '0')}',
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      'electricity': electricity.toJson(),
      'water': water.toJson(),
      if (assets.isNotEmpty)
        'assets': assets.map((a) => a.toJson()).toList(growable: false),
    };
  }
}

class MeterReadingData {
  const MeterReadingData({
    required this.currentValue,
    this.photoFileId,
    this.readingDate,
  });

  final double currentValue;
  final int? photoFileId;
  final DateTime? readingDate;

  Map<String, dynamic> toJson() {
    return {
      'currentValue': currentValue,
      if (photoFileId != null) 'photoFileId': photoFileId,
      if (readingDate != null)
        'readingDate':
            '${readingDate!.year.toString().padLeft(4, '0')}-'
            '${readingDate!.month.toString().padLeft(2, '0')}-'
            '${readingDate!.day.toString().padLeft(2, '0')}',
    };
  }
}

class AssetData {
  const AssetData({
    required this.assetName,
    required this.assetCategory,
    required this.quantity,
    required this.currentCondition,
    this.id,
    this.description,
    this.fileImageId,
  });

  final int? id;
  final String assetName;
  final String assetCategory;
  final int quantity;
  final String currentCondition;
  final String? description;
  final int? fileImageId;

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'assetName': assetName,
      'assetCategory': assetCategory,
      'quantity': quantity,
      'currentCondition': currentCondition,
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      if (fileImageId != null) 'fileImageId': fileImageId,
    };
  }
}
