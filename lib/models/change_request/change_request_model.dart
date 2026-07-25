import 'dart:convert';

/// Mirror of backend RequestType enum.
enum ChangeRequestType {
  meterReadingCorrection,
  invoiceAdjustment,
  rentPriceAdjustment,
  depositRefundRequest,
  roomTransfer,
  contractRenewal,
  contractLiquidation,
  moveOut,
  addCoOccupant,
  complaint;

  static ChangeRequestType fromBackend(String value) {
    switch (value.trim().toUpperCase()) {
      case 'METER_READING_CORRECTION':
        return ChangeRequestType.meterReadingCorrection;
      case 'INVOICE_ADJUSTMENT':
        return ChangeRequestType.invoiceAdjustment;
      case 'RENT_PRICE_ADJUSTMENT':
        return ChangeRequestType.rentPriceAdjustment;
      case 'DEPOSIT_REFUND_REQUEST':
        return ChangeRequestType.depositRefundRequest;
      case 'ROOM_TRANSFER':
        return ChangeRequestType.roomTransfer;
      case 'CONTRACT_RENEWAL':
        return ChangeRequestType.contractRenewal;
      case 'CONTRACT_LIQUIDATION':
        return ChangeRequestType.contractLiquidation;
      case 'MOVE_OUT':
        return ChangeRequestType.moveOut;
      case 'ADD_CO_OCCUPANT':
        return ChangeRequestType.addCoOccupant;
      case 'COMPLAINT':
        return ChangeRequestType.complaint;
      default:
        return ChangeRequestType.complaint;
    }
  }

  String get key {
    switch (this) {
      case ChangeRequestType.meterReadingCorrection:
        return 'METER_READING_CORRECTION';
      case ChangeRequestType.invoiceAdjustment:
        return 'INVOICE_ADJUSTMENT';
      case ChangeRequestType.rentPriceAdjustment:
        return 'RENT_PRICE_ADJUSTMENT';
      case ChangeRequestType.depositRefundRequest:
        return 'DEPOSIT_REFUND_REQUEST';
      case ChangeRequestType.roomTransfer:
        return 'ROOM_TRANSFER';
      case ChangeRequestType.contractRenewal:
        return 'CONTRACT_RENEWAL';
      case ChangeRequestType.contractLiquidation:
        return 'CONTRACT_LIQUIDATION';
      case ChangeRequestType.moveOut:
        return 'MOVE_OUT';
      case ChangeRequestType.addCoOccupant:
        return 'ADD_CO_OCCUPANT';
      case ChangeRequestType.complaint:
        return 'COMPLAINT';
    }
  }

  String get label {
    switch (this) {
      case ChangeRequestType.meterReadingCorrection:
        return 'Chỉnh chỉ số điện/nước';
      case ChangeRequestType.invoiceAdjustment:
        return 'Điều chỉnh hóa đơn';
      case ChangeRequestType.rentPriceAdjustment:
        return 'Điều chỉnh giá thuê';
      case ChangeRequestType.depositRefundRequest:
        return 'Hoàn tiền cọc';
      case ChangeRequestType.roomTransfer:
        return 'Chuyển phòng';
      case ChangeRequestType.contractRenewal:
        return 'Gia hạn hợp đồng';
      case ChangeRequestType.contractLiquidation:
        return 'Thanh lý hợp đồng';
      case ChangeRequestType.moveOut:
        return 'Trả phòng';
      case ChangeRequestType.addCoOccupant:
        return 'Thêm người ở cùng';
      case ChangeRequestType.complaint:
        return 'Khiếu nại';
    }
  }
}

/// Mirror of backend RequestStatus enum.
enum ChangeRequestStatus {
  pending,
  underReview,
  approved,
  rejected,
  processing,
  completed,
  cancelled;

  static ChangeRequestStatus fromBackend(String value) {
    switch (value.trim().toUpperCase()) {
      case 'PENDING':
        return ChangeRequestStatus.pending;
      case 'UNDER_REVIEW':
        return ChangeRequestStatus.underReview;
      case 'APPROVED':
        return ChangeRequestStatus.approved;
      case 'REJECTED':
        return ChangeRequestStatus.rejected;
      case 'PROCESSING':
        return ChangeRequestStatus.processing;
      case 'COMPLETED':
        return ChangeRequestStatus.completed;
      case 'CANCELLED':
        return ChangeRequestStatus.cancelled;
      default:
        return ChangeRequestStatus.pending;
    }
  }

  String get key {
    switch (this) {
      case ChangeRequestStatus.pending:
        return 'PENDING';
      case ChangeRequestStatus.underReview:
        return 'UNDER_REVIEW';
      case ChangeRequestStatus.approved:
        return 'APPROVED';
      case ChangeRequestStatus.rejected:
        return 'REJECTED';
      case ChangeRequestStatus.processing:
        return 'PROCESSING';
      case ChangeRequestStatus.completed:
        return 'COMPLETED';
      case ChangeRequestStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String get label {
    switch (this) {
      case ChangeRequestStatus.pending:
        return 'Chờ duyệt';
      case ChangeRequestStatus.underReview:
        return 'Đang xem xét';
      case ChangeRequestStatus.approved:
        return 'Đã duyệt';
      case ChangeRequestStatus.rejected:
        return 'Bị từ chối';
      case ChangeRequestStatus.processing:
        return 'Đang xử lý';
      case ChangeRequestStatus.completed:
        return 'Hoàn tất';
      case ChangeRequestStatus.cancelled:
        return 'Đã hủy';
    }
  }

  bool get isTerminal =>
      this == approved ||
      this == rejected ||
      this == completed ||
      this == cancelled;
}

/// Mirror of backend ChangeRequest domain model.
class ChangeRequest {
  const ChangeRequest({
    required this.id,
    required this.requestCode,
    required this.requestType,
    required this.title,
    required this.description,
    required this.status,
    required this.requesterId,
    this.targetId,
    this.resolutionNote,
    this.createdAt,
    this.resolvedAt,
    this.requestPayload,
  });

  final int id;
  final String requestCode;
  final ChangeRequestType requestType;
  final String title;
  final String description;
  final ChangeRequestStatus status;
  final int requesterId;
  final int? targetId;
  final String? resolutionNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? requestPayload;

  factory ChangeRequest.fromJson(Map<String, dynamic> json) {
    return ChangeRequest(
      id: _asInt(json['id']) ?? 0,
      requestCode: _str(json, 'requestCode'),
      requestType: ChangeRequestType.fromBackend(_str(json, 'requestType')),
      title: _str(json, 'title'),
      description: _str(json, 'description'),
      status: ChangeRequestStatus.fromBackend(_str(json, 'status')),
      requesterId: _asInt(json['requesterId']) ?? 0,
      targetId: _asInt(json['targetId']),
      resolutionNote: json['resolutionNote']?.toString(),
      createdAt: _parseDateTime(json['createdAt']?.toString() ?? ''),
      resolvedAt: _parseDateTime(json['resolvedAt']?.toString() ?? ''),
      requestPayload: _payloadString(json['requestPayload']),
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

String? _payloadString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return jsonEncode(value);
}

DateTime? _parseDateTime(String value) {
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}
