/// Các loại yêu cầu mà tenant có thể tạo.
enum TenantRequestType {
  renewContract,
  terminateContract,
  changeRoom,
  addRoommate;

  String get label {
    switch (this) {
      case TenantRequestType.renewContract:
        return 'Gia hạn HĐ';
      case TenantRequestType.terminateContract:
        return 'Thanh lý HĐ';
      case TenantRequestType.changeRoom:
        return 'Chuyển phòng';
      case TenantRequestType.addRoommate:
        return 'Thêm người ở';
    }
  }

  String get fullLabel {
    switch (this) {
      case TenantRequestType.renewContract:
        return 'Gia hạn hợp đồng';
      case TenantRequestType.terminateContract:
        return 'Thanh lý hợp đồng';
      case TenantRequestType.changeRoom:
        return 'Chuyển phòng';
      case TenantRequestType.addRoommate:
        return 'Thêm người ở cùng';
    }
  }

  String get description {
    switch (this) {
      case TenantRequestType.renewContract:
        return 'Gia hạn thời gian thuê phòng';
      case TenantRequestType.terminateContract:
        return 'Chấm dứt hợp đồng trước hạn';
      case TenantRequestType.changeRoom:
        return 'Yêu cầu đổi sang phòng khác';
      case TenantRequestType.addRoommate:
        return 'Đăng ký thêm người ở cùng';
    }
  }
}

/// Trạng thái của một yêu cầu.
enum TenantRequestStatus {
  pending,
  processing,
  approved,
  rejected;

  String get label {
    switch (this) {
      case TenantRequestStatus.pending:
        return 'Chờ duyệt';
      case TenantRequestStatus.processing:
        return 'Đang xử lý';
      case TenantRequestStatus.approved:
        return 'Đã duyệt';
      case TenantRequestStatus.rejected:
        return 'Từ chối';
    }
  }
}

/// Model đại diện cho một yêu cầu của tenant.
class TenantRequest {
  const TenantRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final TenantRequestType type;
  final TenantRequestStatus status;
  final String note;
  final DateTime createdAt;
}

// ---------------------------------------------------------------------------
// Mock data – dùng tạm khi chưa có API
// ---------------------------------------------------------------------------
final List<TenantRequest> mockTenantRequests = [
  TenantRequest(
    id: 'REQ-001',
    type: TenantRequestType.renewContract,
    status: TenantRequestStatus.approved,
    note: 'Tôi muốn gia hạn hợp đồng thêm 12 tháng.',
    createdAt: DateTime(2026, 6, 1, 10, 0),
  ),
  TenantRequest(
    id: 'REQ-002',
    type: TenantRequestType.addRoommate,
    status: TenantRequestStatus.pending,
    note: 'Đăng ký thêm 1 người ở cùng từ ngày 15/06/2026.',
    createdAt: DateTime(2026, 6, 5, 14, 30),
  ),
  TenantRequest(
    id: 'REQ-003',
    type: TenantRequestType.changeRoom,
    status: TenantRequestStatus.rejected,
    note: 'Muốn chuyển sang phòng 305 tầng 3.',
    createdAt: DateTime(2026, 5, 20, 9, 0),
  ),
  TenantRequest(
    id: 'REQ-004',
    type: TenantRequestType.terminateContract,
    status: TenantRequestStatus.processing,
    note: 'Tôi cần thanh lý hợp đồng trước hạn do công việc chuyển địa điểm.',
    createdAt: DateTime(2026, 5, 10, 16, 0),
  ),
  TenantRequest(
    id: 'REQ-005',
    type: TenantRequestType.renewContract,
    status: TenantRequestStatus.pending,
    note: 'Gia hạn thêm 6 tháng, bắt đầu từ 01/07/2026.',
    createdAt: DateTime(2026, 6, 7, 8, 0),
  ),
];
