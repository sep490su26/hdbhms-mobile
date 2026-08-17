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
    DateTime? requestedTransferDate,
    List<int>? transferredTenantProfileIds,
    int? nominatedHolderProfileId,
    String? reason,
  }) async {
    final requestedMonth = requestedTransferDate ?? _nextTransferMonth();
    final transferMonth = DateTime(
      requestedMonth.year,
      requestedMonth.month,
      1,
    );
    final body = <String, dynamic>{
      'sourceContractId': sourceContractId,
      'targetRoomId': targetRoomId,
      'requestedTransferDate': _dateOnly(transferMonth),
      'expectedTransferDate': _dateOnly(transferMonth),
      if (transferredTenantProfileIds != null &&
          transferredTenantProfileIds.isNotEmpty)
        'transferredTenantProfileIds': transferredTenantProfileIds,
      'nominatedHolderProfileId': nominatedHolderProfileId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };
    final json = await _postJson(_uri('/occupant-transfer-requests'), body);
    final data = json['data'];
    if (data is int) return data;
    if (data is num) return data.toInt();
    if (data is Map<String, dynamic>) {
      return _asInt(data['id']) ?? 0;
    }
    return 0;
  }

  DateTime _nextTransferMonth() {
    final today = DateTime.now();
    return DateTime(today.year, today.month + 1, 1);
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  /// POST /api/v1/occupant-transfer-requests/{id}/cancel
  Future<void> cancelTransferRequest(int requestId) async {
    await _postJson(_uri('/occupant-transfer-requests/$requestId/cancel'), {});
  }

  // ── Get by ID ─────────────────────────────────────────────────────────────

  /// GET /occupant-transfer-requests/{id}
  Future<RoomTransferRequest> getTransferRequest(int requestId) async {
    final json = await _getJson(_uri('/occupant-transfer-requests/$requestId'));
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return RoomTransferRequest.fromJson(data);
    }
    return RoomTransferRequest.fromJson(json);
  }

  // ── Get by request code ───────────────────────────────────────────────────

  /// GET /occupant-transfer-requests/code/{requestCode}
  Future<RoomTransferRequest> getTransferRequestByCode(
    String requestCode,
  ) async {
    final json = await _getJson(
      _uri('/occupant-transfer-requests/code/$requestCode'),
    );
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return RoomTransferRequest.fromJson(data);
    }
    return RoomTransferRequest.fromJson(json);
  }

  /// GET /occupant-transfer-requests/pending-holder-nominations
  Future<List<RoomTransferRequest>> fetchPendingHolderNominations() async {
    final json = await _getJson(
      _uri('/occupant-transfer-requests/pending-holder-nominations'),
    );
    final list = _extractList(json);
    return list.map(RoomTransferRequest.fromJson).toList(growable: false);
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

  /// POST /api/v1/occupant-transfer-requests/{id}/reject-holder-nomination
  Future<void> rejectHolderNomination(int requestId) async {
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/reject-holder-nomination'),
      {},
    );
  }

  // ── Contract ──────────────────────────────────────────────────────────────

  /// POST /occupant-transfer-requests/{id}/confirm
  Future<void> confirmTenantTransfer({
    required int requestId,
    required SettlementType settlementType,
    int? nominatedHolderProfileId,
  }) async {
    final body = <String, dynamic>{
      'settlementType': settlementType.backendValue,
    };
    if (nominatedHolderProfileId != null) {
      body['nominatedHolderProfileId'] = nominatedHolderProfileId;
    }
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/confirm'),
      body,
    );
  }

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

  // ── Execute ───────────────────────────────────────────────────────────────

  /// POST /api/v1/occupant-transfer-requests/{id}/execute
  Future<void> executeTransfer({
    required int requestId,
    TransferHandoverData? transferOutHandover,
    TransferHandoverData? transferInHandover,
    SettlementType? positiveDifferenceSettlementType,
  }) async {
    final body = <String, dynamic>{};
    if (transferOutHandover != null) {
      body['transferOutHandover'] = transferOutHandover.toJson();
    }
    if (transferInHandover != null) {
      body['transferInHandover'] = transferInHandover.toJson();
    }
    if (positiveDifferenceSettlementType != null) {
      body['positiveDifferenceSettlementType'] =
          positiveDifferenceSettlementType.backendValue;
    }
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/execute'),
      body,
    );
  }

  /// POST /api/v1/occupant-transfer-requests/{id}/complete-with-handover
  Future<void> completeTransfer({
    required int requestId,
    TransferHandoverData? transferInHandover,
    SettlementType? positiveDifferenceSettlementType,
  }) async {
    final body = <String, dynamic>{};
    if (transferInHandover != null) {
      body['transferInHandover'] = transferInHandover.toJson();
    }
    if (positiveDifferenceSettlementType != null) {
      body['positiveDifferenceSettlementType'] =
          positiveDifferenceSettlementType.backendValue;
    }
    await _postJson(
      _uri('/occupant-transfer-requests/$requestId/complete-with-handover'),
      body,
    );
  }

  /// GET /api/v1/rooms/{roomId}/meter-readings/latest
  Future<LatestRoomMeterReadings?> getLatestRoomMeterReadings(
    int roomId,
  ) async {
    final json = await _getJson(
      _uriWithApiPrefix('/rooms/$roomId/meter-readings/latest'),
    );
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return LatestRoomMeterReadings.fromJson(data);
    }
    if (data is Map) {
      return LatestRoomMeterReadings.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  /// GET /api/v1/lease-contracts/{contractId}/handover?type=MOVE_OUT
  Future<ContractHandoverDetails?> getContractHandoverDetails({
    required int contractId,
    String type = 'MOVE_OUT',
  }) async {
    final json = await _getJson(
      _uriWithApiPrefix('/lease-contracts/$contractId/handover', {
        'type': type,
      }),
    );
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return ContractHandoverDetails.fromJson(data);
    }
    if (data is Map) {
      return ContractHandoverDetails.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  // ── Rooms ─────────────────────────────────────────────────────────────────

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
    return list.map(AvailableRoom.fromJson).toList(growable: false);
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
    return Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
  }

  Uri _uriWithApiPrefix(String path, [Map<String, String>? query]) {
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

int? _topLevelAsInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _parseDateTimeFlexible(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

class LatestRoomMeterReadings {
  const LatestRoomMeterReadings({this.electricity, this.water});

  final LatestMeterReadingItem? electricity;
  final LatestMeterReadingItem? water;

  factory LatestRoomMeterReadings.fromJson(Map<String, dynamic> json) {
    return LatestRoomMeterReadings(
      electricity: _readingOrNull(json['electricity']),
      water: _readingOrNull(json['water']),
    );
  }
}

class ContractHandoverDetails {
  const ContractHandoverDetails({
    this.handoverRecordId,
    this.handoverType,
    this.status,
    this.handoverDate,
    this.note,
    this.electricity,
    this.water,
  });

  final int? handoverRecordId;
  final String? handoverType;
  final String? status;
  final DateTime? handoverDate;
  final String? note;
  final LatestMeterReadingItem? electricity;
  final LatestMeterReadingItem? water;

  bool get hasAnyData =>
      handoverRecordId != null ||
      handoverDate != null ||
      (note?.trim().isNotEmpty ?? false) ||
      electricity?.currentValue != null ||
      water?.currentValue != null;

  factory ContractHandoverDetails.fromJson(Map<String, dynamic> json) {
    return ContractHandoverDetails(
      handoverRecordId: _topLevelAsInt(json['handoverRecordId']),
      handoverType: json['handoverType']?.toString(),
      status: json['status']?.toString(),
      handoverDate: _parseDateTimeFlexible(json['handoverDate']),
      note: json['note']?.toString(),
      electricity: _readingOrNull(json['electricity']),
      water: _readingOrNull(json['water']),
    );
  }
}

class LatestMeterReadingItem {
  const LatestMeterReadingItem({
    this.id,
    this.currentValue,
    this.previousValue,
    this.readingDate,
    this.photoFileId,
  });

  final int? id;
  final double? currentValue;
  final double? previousValue;
  final DateTime? readingDate;
  final int? photoFileId;

  factory LatestMeterReadingItem.fromJson(Map<String, dynamic> json) {
    return LatestMeterReadingItem(
      id: _topLevelAsInt(json['id']),
      currentValue: _asDouble(json['currentValue']),
      previousValue: _asDouble(json['previousValue']),
      readingDate: _parseDateTimeFlexible(json['readingDate']),
      photoFileId: _topLevelAsInt(json['photoFileId']),
    );
  }
}

LatestMeterReadingItem? _readingOrNull(Object? value) {
  if (value is Map<String, dynamic>) {
    return LatestMeterReadingItem.fromJson(value);
  }
  if (value is Map) {
    return LatestMeterReadingItem.fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

/// Settlement option for positive room-rent difference during transfer.
enum SettlementType {
  tenantPayMore('TENANT_PAY_MORE'),
  addToNextInvoice('ADD_TO_NEXT_INVOICE'),
  refundNow('REFUND_NOW'),
  creditNextContract('CREDIT_NEXT_CONTRACT'),
  noDifference('NO_DIFFERENCE');

  const SettlementType(this.backendValue);

  final String backendValue;
}

/// Handover data payload for execute-transfer endpoint.
class TransferHandoverData {
  const TransferHandoverData({
    required this.handoverDate,
    required this.electricity,
    this.note,
    this.assets = const [],
  });

  final DateTime handoverDate;
  final MeterReadingData electricity;
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
