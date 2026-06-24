import 'dart:convert';

/// Mirror of backend TransferRequestStatus enum.
enum TransferRequestStatus {
  waitingApproval,
  waitingNewContract,
  waitingTargetHolderApproval,
  waitingContractConfirmation,
  waitingSigning,
  waitingExecution,
  executed,
  cancelled,
  rejected,
  expired;

  static TransferRequestStatus fromBackend(String value) {
    switch (value.trim().toUpperCase()) {
      case 'WAITING_APPROVAL':
        return TransferRequestStatus.waitingApproval;
      case 'WAITING_NEW_CONTRACT':
        return TransferRequestStatus.waitingNewContract;
      case 'WAITING_TARGET_HOLDER_APPROVAL':
        return TransferRequestStatus.waitingTargetHolderApproval;
      case 'WAITING_CONTRACT_CONFIRMATION':
        return TransferRequestStatus.waitingContractConfirmation;
      case 'WAITING_SIGNING':
        return TransferRequestStatus.waitingSigning;
      case 'WAITING_EXECUTION':
        return TransferRequestStatus.waitingExecution;
      case 'EXECUTED':
        return TransferRequestStatus.executed;
      case 'CANCELLED':
        return TransferRequestStatus.cancelled;
      case 'REJECTED':
        return TransferRequestStatus.rejected;
      case 'EXPIRED':
        return TransferRequestStatus.expired;
      default:
        return TransferRequestStatus.waitingApproval;
    }
  }

  String get key {
    switch (this) {
      case TransferRequestStatus.waitingApproval:
        return 'WAITING_APPROVAL';
      case TransferRequestStatus.waitingNewContract:
        return 'WAITING_NEW_CONTRACT';
      case TransferRequestStatus.waitingTargetHolderApproval:
        return 'WAITING_TARGET_HOLDER_APPROVAL';
      case TransferRequestStatus.waitingContractConfirmation:
        return 'WAITING_CONTRACT_CONFIRMATION';
      case TransferRequestStatus.waitingSigning:
        return 'WAITING_SIGNING';
      case TransferRequestStatus.waitingExecution:
        return 'WAITING_EXECUTION';
      case TransferRequestStatus.executed:
        return 'EXECUTED';
      case TransferRequestStatus.cancelled:
        return 'CANCELLED';
      case TransferRequestStatus.rejected:
        return 'REJECTED';
      case TransferRequestStatus.expired:
        return 'EXPIRED';
    }
  }

  String get label {
    switch (this) {
      case TransferRequestStatus.waitingApproval:
        return 'Chờ duyệt';
      case TransferRequestStatus.waitingNewContract:
        return 'Đợi tạo hợp đồng';
      case TransferRequestStatus.waitingTargetHolderApproval:
        return 'Chờ chủ phòng đích duyệt';
      case TransferRequestStatus.waitingContractConfirmation:
        return 'Chờ xác nhận hợp đồng';
      case TransferRequestStatus.waitingSigning:
        return 'Chờ ký hợp đồng';
      case TransferRequestStatus.waitingExecution:
        return 'Chờ thực hiện';
      case TransferRequestStatus.executed:
        return 'Đã thực hiện';
      case TransferRequestStatus.cancelled:
        return 'Đã hủy';
      case TransferRequestStatus.rejected:
        return 'Bị từ chối';
      case TransferRequestStatus.expired:
        return 'Hết hạn';
    }
  }

  bool get isTerminal =>
      this == executed || this == cancelled || this == rejected || this == expired;
}

/// Mirror of backend TargetTransferType enum.
enum TargetTransferType {
  newContract,
  ownContract,
  otherContract;

  static TargetTransferType fromBackend(String value) {
    switch (value.trim().toUpperCase()) {
      case 'OWN_CONTRACT':
        return TargetTransferType.ownContract;
      case 'OTHER_CONTRACT':
        return TargetTransferType.otherContract;
      case 'NEW_CONTRACT':
      default:
        return TargetTransferType.newContract;
    }
  }

  String get label {
    switch (this) {
      case TargetTransferType.newContract:
        return 'Hợp đồng mới';
      case TargetTransferType.ownContract:
        return 'Hợp đồng của bạn';
      case TargetTransferType.otherContract:
        return 'Hợp đồng khác';
    }
  }
}

/// Room transfer request domain model.
class RoomTransferRequest {
  const RoomTransferRequest({
    required this.id,
    required this.requestCode,
    required this.requesterId,
    required this.oldContractId,
    required this.oldRoomId,
    required this.targetRoomId,
    required this.transferringTenantProfileIds,
    required this.targetTransferType,
    required this.requestedTransferDate,
    required this.status,
    this.oldRoomName = '',
    this.oldRoomCode = '',
    this.oldContractCode = '',
    this.targetRoomName = '',
    this.targetRoomCode = '',
    this.nominatedHolderProfileId,
    this.targetContractId,
    this.newContractId,
    this.reason = '',
    this.reservedSlots,
    this.reservationExpiresAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String requestCode;
  final int requesterId;
  final int oldContractId;
  final int oldRoomId;
  final int targetRoomId;
  final List<int> transferringTenantProfileIds;
  final TargetTransferType targetTransferType;
  final DateTime requestedTransferDate;
  final TransferRequestStatus status;

  final String oldRoomName;
  final String oldRoomCode;
  final String oldContractCode;
  final String targetRoomName;
  final String targetRoomCode;
  final int? nominatedHolderProfileId;
  final int? targetContractId;
  final int? newContractId;
  final String reason;
  final int? reservedSlots;
  final DateTime? reservationExpiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RoomTransferRequest.fromJson(Map<String, dynamic> json) {
    return RoomTransferRequest(
      id: _asInt(json['id']) ?? 0,
      requestCode: _str(json, 'request_code', 'requestCode'),
      requesterId: _asInt(json['requester_id'] ?? json['requesterId']) ?? 0,
      oldContractId: _asInt(json['old_contract_id'] ?? json['oldContractId']) ?? 0,
      oldRoomId: _asInt(json['old_room_id'] ?? json['oldRoomId']) ?? 0,
      targetRoomId: _asInt(json['target_room_id'] ?? json['targetRoomId']) ?? 0,
      transferringTenantProfileIds: _parseIntList(
        json['transferring_tenant_profile_ids'] ??
            json['transferringTenantProfileIds'],
      ),
      targetTransferType: TargetTransferType.fromBackend(
        _str(json, 'target_transfer_type', 'targetTransferType'),
      ),
      requestedTransferDate: _parseDate(
        _str(json, 'requested_transfer_date', 'requestedTransferDate'),
      ),
      status: TransferRequestStatus.fromBackend(
        _str(json, 'status'),
      ),
      oldRoomName: _str(json, 'old_room_name', 'oldRoomName'),
      oldRoomCode: _str(json, 'old_room_code', 'oldRoomCode'),
      oldContractCode: _str(json, 'old_contract_code', 'oldContractCode'),
      targetRoomName: _str(json, 'target_room_name', 'targetRoomName'),
      targetRoomCode: _str(json, 'target_room_code', 'targetRoomCode'),
      nominatedHolderProfileId: _asInt(
        json['nominated_holder_profile_id'] ?? json['nominatedHolderProfileId'],
      ),
      targetContractId: _asInt(json['target_contract_id'] ?? json['targetContractId']),
      newContractId: _asInt(json['new_contract_id'] ?? json['newContractId']),
      reason: _str(json, 'reason'),
      reservedSlots: _asInt(json['reserved_slots'] ?? json['reservedSlots']),
      reservationExpiresAt: _parseDateTime(
        _str(json, 'reservation_expires_at', 'reservationExpiresAt'),
      ),
      createdAt: _parseDateTime(_str(json, 'created_at', 'createdAt')),
      updatedAt: _parseDateTime(_str(json, 'updated_at', 'updatedAt')),
    );
  }
}

/// Available room for picking as target in the create-transfer form.
class AvailableRoom {
  const AvailableRoom({
    required this.id,
    required this.roomCode,
    required this.roomName,
    required this.propertyName,
    required this.floorName,
    required this.currentStatus,
    required this.listedPrice,
    required this.maxOccupants,
    this.areaM2,
  });

  final int id;
  final String roomCode;
  final String roomName;
  final String propertyName;
  final String floorName;
  final String currentStatus;
  final int listedPrice;
  final int maxOccupants;
  final int? areaM2;

  String get displayName {
    final name = roomName.trim();
    if (name.isNotEmpty) return name;
    return 'Phòng $roomCode';
  }

  factory AvailableRoom.fromJson(Map<String, dynamic> json) {
    return AvailableRoom(
      id: _asInt(json['id']) ?? 0,
      roomCode: _str(json, 'room_code', 'roomCode'),
      roomName: _str(json, 'room_name', 'roomName'),
      propertyName: _str(json, 'property_name', 'propertyName'),
      floorName: _str(json, 'floor_name', 'floorName'),
      currentStatus: _str(json, 'current_status', 'currentStatus'),
      listedPrice: _asInt(json['listed_price'] ?? json['listedPrice']) ?? 0,
      maxOccupants: _asInt(json['max_occupants'] ?? json['maxOccupants']) ?? 0,
      areaM2: _asInt(json['area_m2'] ?? json['areaM2']),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _str(Map<String, dynamic> json, String key, [String? altKey]) {
  final v = json[key] ?? (altKey != null ? json[altKey] : null);
  return v?.toString() ?? '';
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime _parseDate(String value) {
  if (value.isEmpty) return DateTime.now();
  return DateTime.tryParse(value) ?? DateTime.now();
}

DateTime? _parseDateTime(String value) {
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}

List<int> _parseIntList(Object? raw) {
  if (raw is List) {
    return raw
        .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
        .toList(growable: false);
  }
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
            .toList(growable: false);
      }
    } catch (_) {
      // ignore
    }
  }
  return const [];
}
