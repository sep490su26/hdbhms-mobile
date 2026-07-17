import 'dart:convert';

/// Mirror of backend TransferRequestStatus enum.
enum TransferRequestStatus {
  requested,
  waitingManagerApproval,
  managerApproved,
  waitingHolderResponse,
  waitingApproval,
  waitingNewContract,
  waitingTargetHolderApproval,
  waitingTenantConfirmation,
  waitingPayment,
  waitingContractConfirmation,
  waitingSigning,
  waitingContractSigning,
  waitingTransferDate,
  readyForHandover,
  waitingExecution,
  executed,
  completed,
  cancelled,
  rejected,
  expired;

  static TransferRequestStatus fromBackend(String value) {
    switch (value.trim().toUpperCase()) {
      case 'REQUESTED':
        return TransferRequestStatus.requested;
      case 'WAITING_MANAGER_APPROVAL':
        return TransferRequestStatus.waitingManagerApproval;
      case 'MANAGER_APPROVED':
        return TransferRequestStatus.managerApproved;
      case 'WAITING_HOLDER_RESPONSE':
        return TransferRequestStatus.waitingHolderResponse;
      case 'WAITING_APPROVAL':
        return TransferRequestStatus.waitingApproval;
      case 'WAITING_NEW_CONTRACT':
        return TransferRequestStatus.waitingNewContract;
      case 'WAITING_TARGET_HOLDER_APPROVAL':
        return TransferRequestStatus.waitingTargetHolderApproval;
      case 'WAITING_TENANT_CONFIRMATION':
        return TransferRequestStatus.waitingTenantConfirmation;
      case 'WAITING_PAYMENT':
        return TransferRequestStatus.waitingPayment;
      case 'WAITING_CONTRACT_CONFIRMATION':
        return TransferRequestStatus.waitingContractConfirmation;
      case 'WAITING_SIGNING':
        return TransferRequestStatus.waitingSigning;
      case 'WAITING_CONTRACT_SIGNING':
        return TransferRequestStatus.waitingContractSigning;
      case 'WAITING_TRANSFER_DATE':
        return TransferRequestStatus.waitingTransferDate;
      case 'READY_FOR_HANDOVER':
        return TransferRequestStatus.readyForHandover;
      case 'WAITING_EXECUTION':
        return TransferRequestStatus.waitingExecution;
      case 'EXECUTED':
        return TransferRequestStatus.executed;
      case 'COMPLETED':
        return TransferRequestStatus.completed;
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
      case TransferRequestStatus.requested:
        return 'REQUESTED';
      case TransferRequestStatus.waitingManagerApproval:
        return 'WAITING_MANAGER_APPROVAL';
      case TransferRequestStatus.managerApproved:
        return 'MANAGER_APPROVED';
      case TransferRequestStatus.waitingHolderResponse:
        return 'WAITING_HOLDER_RESPONSE';
      case TransferRequestStatus.waitingApproval:
        return 'WAITING_APPROVAL';
      case TransferRequestStatus.waitingNewContract:
        return 'WAITING_NEW_CONTRACT';
      case TransferRequestStatus.waitingTargetHolderApproval:
        return 'WAITING_TARGET_HOLDER_APPROVAL';
      case TransferRequestStatus.waitingTenantConfirmation:
        return 'WAITING_TENANT_CONFIRMATION';
      case TransferRequestStatus.waitingPayment:
        return 'WAITING_PAYMENT';
      case TransferRequestStatus.waitingContractConfirmation:
        return 'WAITING_CONTRACT_CONFIRMATION';
      case TransferRequestStatus.waitingSigning:
        return 'WAITING_SIGNING';
      case TransferRequestStatus.waitingContractSigning:
        return 'WAITING_CONTRACT_SIGNING';
      case TransferRequestStatus.waitingTransferDate:
        return 'WAITING_TRANSFER_DATE';
      case TransferRequestStatus.readyForHandover:
        return 'READY_FOR_HANDOVER';
      case TransferRequestStatus.waitingExecution:
        return 'WAITING_EXECUTION';
      case TransferRequestStatus.executed:
        return 'EXECUTED';
      case TransferRequestStatus.completed:
        return 'COMPLETED';
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
      case TransferRequestStatus.requested:
        return 'Đã tạo yêu cầu';
      case TransferRequestStatus.waitingManagerApproval:
        return 'Chờ quản lý duyệt';
      case TransferRequestStatus.managerApproved:
        return 'Quản lý đã duyệt';
      case TransferRequestStatus.waitingHolderResponse:
        return 'Chờ holder mới phản hồi';
      case TransferRequestStatus.waitingApproval:
        return 'Chờ duyệt';
      case TransferRequestStatus.waitingNewContract:
        return 'Chờ đề cử / tạo hợp đồng';
      case TransferRequestStatus.waitingTargetHolderApproval:
        return 'Chờ chủ phòng đích duyệt';
      case TransferRequestStatus.waitingTenantConfirmation:
        return 'Chờ xác nhận yêu cầu';
      case TransferRequestStatus.waitingPayment:
        return 'Chờ xác nhận yêu cầu';
      case TransferRequestStatus.waitingContractConfirmation:
        return 'Đang chuẩn bị hợp đồng';
      case TransferRequestStatus.waitingSigning:
        return 'Chờ quản lý xử lý ký';
      case TransferRequestStatus.waitingContractSigning:
        return 'Chờ quản lý xử lý ký';
      case TransferRequestStatus.waitingTransferDate:
        return 'Sẵn sàng chuyển phòng';
      case TransferRequestStatus.readyForHandover:
        return 'Sẵn sàng chuyển phòng';
      case TransferRequestStatus.waitingExecution:
        return 'Đang chuyển phòng';
      case TransferRequestStatus.executed:
        return 'Đã thực hiện';
      case TransferRequestStatus.completed:
        return 'Hoàn tất';
      case TransferRequestStatus.cancelled:
        return 'Đã hủy';
      case TransferRequestStatus.rejected:
        return 'Bị từ chối';
      case TransferRequestStatus.expired:
        return 'Hết hạn';
    }
  }

  bool get isTerminal =>
      this == executed ||
      this == completed ||
      this == cancelled ||
      this == rejected ||
      this == expired;
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
    required this.transferringTenantNames,
    required this.sourceHolderCandidateProfileIds,
    required this.sourceHolderCandidateNames,
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
    this.oldRoomPrice,
    this.newRoomPrice,
    this.priceDifferenceToPay,
    this.reason = '',
    this.reservedSlots,
    this.reservationExpiresAt,
    this.createdAt,
    this.updatedAt,
    this.transferDifferenceInvoiceId,
    this.oldRoomFinalInvoiceId,
    this.remainingOccupantCountAfterTransfer,
    this.sourceRoomWillBeEmptyAfterTransfer,
    this.priceDifferenceSettlementType = '',
    this.paymentBranch = '',
    this.transferOutHandoverRequired = false,
    this.transferInHandoverRequired = false,
    this.roomHandoverRequired = false,
    this.allowedActions = const [],
    this.blockingReasons = const [],
  });

  final int id;
  final String requestCode;
  final int requesterId;
  final int oldContractId;
  final int oldRoomId;
  final int targetRoomId;
  final List<int> transferringTenantProfileIds;
  final Map<int, String> transferringTenantNames;
  final List<int> sourceHolderCandidateProfileIds;
  final Map<int, String> sourceHolderCandidateNames;
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
  final int? oldRoomPrice;
  final int? newRoomPrice;
  final int? priceDifferenceToPay;
  final String reason;
  final int? reservedSlots;
  final DateTime? reservationExpiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? transferDifferenceInvoiceId;
  final int? oldRoomFinalInvoiceId;
  final int? remainingOccupantCountAfterTransfer;
  final bool? sourceRoomWillBeEmptyAfterTransfer;
  final String priceDifferenceSettlementType;
  final String paymentBranch;
  final bool transferOutHandoverRequired;
  final bool transferInHandoverRequired;
  final bool roomHandoverRequired;
  final List<String> allowedActions;
  final List<String> blockingReasons;

  bool allowsAction(String action) {
    final normalized = action.trim().toUpperCase();
    return allowedActions.any(
      (item) => item.trim().toUpperCase() == normalized,
    );
  }

  bool get hasBackendActions =>
      allowedActions.isNotEmpty || blockingReasons.isNotEmpty;

  bool get canNominateSourceHolder => allowsAction('NOMINATE_SOURCE_HOLDER');

  bool get canAcceptSourceHolderNomination =>
      allowsAction('ACCEPT_SOURCE_HOLDER_NOMINATION');

  bool get canConfirmTenantTransfer => allowsAction('CONFIRM_TENANT_TRANSFER');

  bool get canPayTransferDifference => allowsAction('PAY_TRANSFER_DIFFERENCE');

  bool get canPayTransferOutUtility => allowsAction('PAY_TRANSFER_OUT_UTILITY');

  bool get canConfirmTransferContract =>
      allowsAction('CONFIRM_TRANSFER_CONTRACT');

  bool get canSignTransferContract => allowsAction('SIGN_TRANSFER_CONTRACT');

  bool get canExecuteTransfer => allowsAction('EXECUTE_TRANSFER');

  bool get canCompleteTransfer => allowsAction('COMPLETE_TRANSFER');

  bool get hasPositiveDifference => (priceDifferenceToPay ?? 0) > 0;

  String get paymentBranchLabel {
    switch (paymentBranch.trim().toUpperCase()) {
      case 'PAY_NOW':
      case 'TENANT_PAY_MORE':
        return 'Thanh toán ngay';
      case 'ADD_TO_NEXT_INVOICE':
        return 'Cộng vào hóa đơn kỳ sau';
      case 'REFUND_NOW':
        return 'Hoàn tiền ngay';
      case 'CREDIT_NEXT_CONTRACT':
        return 'Cấn trừ hợp đồng mới';
      case 'NO_DIFFERENCE':
        return 'Không có chênh lệch';
      case 'UNSELECTED_POSITIVE_DIFFERENCE':
      case 'UNSELECTED_NEGATIVE_DIFFERENCE':
        return 'Chưa chọn phương thức';
      case 'UNKNOWN':
      case '':
        return 'Chưa xác định';
      default:
        return paymentBranch;
    }
  }

  factory RoomTransferRequest.fromJson(Map<String, dynamic> json) {
    final targetTransferType = TargetTransferType.fromBackend(
      _str(json, 'targetTransferType'),
    );
    final status = TransferRequestStatus.fromBackend(_str(json, 'status'));
    return RoomTransferRequest(
      id: _asInt(json['id']) ?? 0,
      requestCode: _str(json, 'requestCode'),
      requesterId: _asInt(json['requesterId']) ?? 0,
      oldContractId: _asInt(json['oldContractId']) ?? 0,
      oldRoomId: _asInt(json['oldRoomId']) ?? 0,
      targetRoomId: _asInt(json['targetRoomId']) ?? 0,
      transferringTenantProfileIds: _parseIntList(
        json['transferringTenantProfileIds'],
      ),
      transferringTenantNames: _parseIntStringMap(
        json['transferringTenantNames'],
      ),
      sourceHolderCandidateProfileIds: _parseIntList(
        json['sourceHolderCandidateProfileIds'],
      ),
      sourceHolderCandidateNames: _parseIntStringMap(
        json['sourceHolderCandidateNames'],
      ),
      targetTransferType: targetTransferType,
      requestedTransferDate: _parseDate(
        _str(json, 'expectedTransferDate').isNotEmpty
            ? _str(json, 'expectedTransferDate')
            : _str(json, 'requestedTransferDate'),
      ),
      status: status,
      oldRoomName: _str(json, 'oldRoomName'),
      oldRoomCode: _str(json, 'oldRoomCode'),
      oldContractCode: _str(json, 'oldContractCode'),
      targetRoomName: _str(json, 'targetRoomName'),
      targetRoomCode: _str(json, 'targetRoomCode'),
      nominatedHolderProfileId: _asInt(json['nominatedHolderProfileId']),
      targetContractId: _asInt(json['targetContractId']),
      newContractId: _asInt(json['newContractId']),
      oldRoomPrice: _asInt(json['oldRoomPrice']),
      newRoomPrice: _asInt(json['newRoomPrice']),
      priceDifferenceToPay: _asInt(json['priceDifferenceToPay']),
      reason: _str(json, 'reason'),
      reservedSlots: _asInt(json['reservedSlots']),
      reservationExpiresAt: _parseDateTime(_str(json, 'reservationExpiresAt')),
      createdAt: _parseDateTime(_str(json, 'createdAt')),
      updatedAt: _parseDateTime(_str(json, 'updatedAt')),
      transferDifferenceInvoiceId: _asInt(json['transferDifferenceInvoiceId']),
      oldRoomFinalInvoiceId: _asInt(json['oldRoomFinalInvoiceId']),
      remainingOccupantCountAfterTransfer: _asInt(
        json['remainingOccupantCountAfterTransfer'],
      ),
      sourceRoomWillBeEmptyAfterTransfer: _asBool(
        json['sourceRoomWillBeEmptyAfterTransfer'],
      ),
      priceDifferenceSettlementType: _str(
        json,
        'priceDifferenceSettlementType',
      ),
      paymentBranch: _str(json, 'paymentBranch'),
      transferOutHandoverRequired:
          _asBool(json['transferOutHandoverRequired']) ??
          status == TransferRequestStatus.readyForHandover,
      transferInHandoverRequired:
          _asBool(json['transferInHandoverRequired']) ??
          (targetTransferType == TargetTransferType.newContract &&
              status == TransferRequestStatus.waitingExecution),
      roomHandoverRequired:
          _asBool(json['roomHandoverRequired']) ??
          _asBool(json['sourceRoomWillBeEmptyAfterTransfer']) == true,
      allowedActions: _parseStringList(json['allowedActions']),
      blockingReasons: _parseStringList(json['blockingReasons']),
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

  String get statusLabel {
    return switch (currentStatus) {
      'VACANT' => 'Còn trống',
      'SOON_VACANT' => 'Sắp trống',
      'OCCUPIED' => 'Đang có người ở - cần người đứng tên duyệt',
      'RESERVED_FOR_TRANSFER' => 'Đang giữ chỗ chuyển phòng',
      'RESERVED' => 'Đã đặt chỗ',
      'ON_HOLD' => 'Đang giữ chỗ',
      'MAINTENANCE' => 'Bảo trì',
      'DRAFT' => 'Nháp',
      _ => currentStatus,
    };
  }

  factory AvailableRoom.fromJson(Map<String, dynamic> json) {
    return AvailableRoom(
      id: _asInt(json['id']) ?? 0,
      roomCode: _str(json, 'roomCode'),
      roomName: _str(json, 'roomName').isNotEmpty
          ? _str(json, 'roomName')
          : _str(json, 'name'),
      propertyName: _str(json, 'propertyName'),
      floorName: _str(json, 'floorName'),
      currentStatus: _str(json, 'currentStatus'),
      listedPrice: _asInt(json['listedPrice']) ?? 0,
      maxOccupants: _asInt(json['maxOccupants']) ?? 0,
      areaM2: _asInt(json['areaM2']),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _str(Map<String, dynamic> json, String key) {
  final v = json[key];
  return v?.toString() ?? '';
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool? _asBool(Object? value) {
  if (value is bool) return value;
  final raw = value?.toString().trim().toLowerCase() ?? '';
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  return null;
}

DateTime _parseDate(String value) {
  if (value.isEmpty) return DateTime.now();
  return DateTime.tryParse(value) ?? DateTime.now();
}

DateTime? _parseDateTime(String value) {
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}

Map<int, String> _parseIntStringMap(Object? raw) {
  if (raw is Map) {
    final result = <int, String>{};
    raw.forEach((key, value) {
      final parsedKey = int.tryParse(key.toString());
      final parsedValue = value?.toString().trim();
      if (parsedKey != null &&
          parsedValue != null &&
          parsedValue.isNotEmpty &&
          parsedValue != 'null') {
        result[parsedKey] = parsedValue;
      }
    });
    return result;
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return _parseIntStringMap(decoded);
      }
    } catch (_) {
      // ignore
    }
  }
  return const {};
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

List<String> _parseStringList(Object? raw) {
  if (raw is List) {
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty && item != 'null')
        .toList(growable: false);
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return _parseStringList(decoded);
      }
    } catch (_) {
      return raw
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
  }
  return const [];
}
