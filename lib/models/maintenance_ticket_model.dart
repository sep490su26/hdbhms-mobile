class MaintenanceTicketModel {
  const MaintenanceTicketModel({
    required this.id,
    required this.code,
    required this.category,
    required this.title,
    required this.description,
    required this.createdDate,
    required this.status,
    this.roomId,
    this.roomCode = '',
    this.priority = TicketPriority.medium,
    this.ticketScope = TicketScope.tenantRoom,
  });

  final int id;
  final String code;
  final TicketCategory category;
  final String title;
  final String description;
  final DateTime createdDate;
  final TicketStatus status;
  final int? roomId;
  final String roomCode;
  final TicketPriority priority;
  final TicketScope ticketScope;

  MaintenanceTicketModel copyWith({
    String? code,
    TicketCategory? category,
    String? title,
    String? description,
    DateTime? createdDate,
    TicketStatus? status,
    int? roomId,
    String? roomCode,
    TicketPriority? priority,
    TicketScope? ticketScope,
  }) {
    return MaintenanceTicketModel(
      id: id,
      code: code ?? this.code,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      createdDate: createdDate ?? this.createdDate,
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? this.roomCode,
      priority: priority ?? this.priority,
      ticketScope: ticketScope ?? this.ticketScope,
    );
  }

  factory MaintenanceTicketModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceTicketModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      code: json['ticket_code']?.toString() ?? json['code']?.toString() ?? '',
      category: TicketCategory.fromBackend(json['category']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdDate:
          DateTime.tryParse(
            json['created_at']?.toString() ??
                json['created_date']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      status: TicketStatus.fromBackend(json['status']?.toString() ?? ''),
      roomId: int.tryParse(json['room_id']?.toString() ?? ''),
      roomCode: json['room_code']?.toString() ?? '',
      priority: TicketPriority.fromBackend(json['priority']?.toString() ?? ''),
      ticketScope: TicketScope.fromBackend(
        json['ticket_scope']?.toString() ?? '',
      ),
    );
  }
}

class CreateMaintenanceTicketRequest {
  const CreateMaintenanceTicketRequest({
    required this.roomId,
    required this.category,
    required this.title,
    required this.description,
    required this.attachments,
    this.ticketScope = TicketScope.tenantRoom,
    this.priority = TicketPriority.medium,
  });

  final int roomId;
  final TicketCategory category;
  final String title;
  final String description;
  final TicketScope ticketScope;
  final TicketPriority priority;
  final List<MaintenanceAttachment> attachments;

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'category': category.key,
      'title': title,
      'description': description,
      'ticketScope': ticketScope.key,
      'priority': priority.key,
      'attachments': attachments
          .map(
            (file) => {
              'name': file.name,
              'path': file.path,
              'mimeType': file.mimeType,
              'sizeBytes': file.sizeBytes,
            },
          )
          .toList(growable: false),
    };
  }
}

class MaintenanceAttachment {
  const MaintenanceAttachment({
    required this.name,
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    required this.type,
    this.previewBytes,
  });

  final String name;
  final String path;
  final String mimeType;
  final int sizeBytes;
  final MaintenanceAttachmentType type;
  final List<int>? previewBytes;
}

enum MaintenanceAttachmentType { image, video }

class MaintenanceTicketDetail {
  const MaintenanceTicketDetail({
    required this.id,
    required this.ticketCode,
    required this.status,
    required this.roomId,
    required this.roomCode,
    required this.category,
    required this.categoryName,
    required this.title,
    required this.description,
    required this.priority,
    required this.createdAt,
    this.beforeAttachments = const [],
    this.afterAttachments = const [],
    this.repairInfo,
    this.review,
    this.events = const [],
  });

  final int id;
  final String ticketCode;
  final TicketStatus status;
  final int roomId;
  final String roomCode;
  final TicketCategory category;
  final String categoryName;
  final String title;
  final String description;
  final TicketPriority priority;
  final DateTime createdAt;
  final List<TicketAttachment> beforeAttachments;
  final List<TicketAttachment> afterAttachments;
  final TicketRepairInfo? repairInfo;
  final TicketReview? review;
  final List<TicketTimelineEvent> events;

  bool get hasRepairData {
    final repair = repairInfo;
    return repair != null &&
        (repair.workerName?.trim().isNotEmpty == true ||
            repair.repairItems?.trim().isNotEmpty == true ||
            repair.completionNote?.trim().isNotEmpty == true ||
            repair.totalCost != null ||
            repair.costCategory?.trim().isNotEmpty == true);
  }

  MaintenanceTicketDetail copyWith({
    TicketStatus? status,
    List<TicketAttachment>? beforeAttachments,
    List<TicketAttachment>? afterAttachments,
    TicketRepairInfo? repairInfo,
    TicketReview? review,
    List<TicketTimelineEvent>? events,
  }) {
    return MaintenanceTicketDetail(
      id: id,
      ticketCode: ticketCode,
      status: status ?? this.status,
      roomId: roomId,
      roomCode: roomCode,
      category: category,
      categoryName: categoryName,
      title: title,
      description: description,
      priority: priority,
      createdAt: createdAt,
      beforeAttachments: beforeAttachments ?? this.beforeAttachments,
      afterAttachments: afterAttachments ?? this.afterAttachments,
      repairInfo: repairInfo ?? this.repairInfo,
      review: review ?? this.review,
      events: events ?? this.events,
    );
  }

  factory MaintenanceTicketDetail.fromTicket(MaintenanceTicketModel ticket) {
    return MaintenanceTicketDetail(
      id: ticket.id,
      ticketCode: ticket.code,
      status: ticket.status,
      roomId: ticket.roomId ?? 0,
      roomCode: ticket.roomCode,
      category: ticket.category,
      categoryName: ticket.category.label,
      title: ticket.title,
      description: ticket.description,
      priority: ticket.priority,
      createdAt: ticket.createdDate,
      events: [
        TicketTimelineEvent(
          status: TicketStatus.pending.key,
          title: 'Yêu cầu mới',
          description: 'Đã gửi báo cáo sự cố',
          createdAt: ticket.createdDate,
        ),
      ],
    );
  }
}

class TicketAttachment {
  const TicketAttachment({
    required this.id,
    required this.url,
    required this.mimeType,
    required this.phase,
    required this.sortOrder,
    this.name = '',
  });

  final int id;
  final String url;
  final String mimeType;
  final TicketAttachmentPhase phase;
  final int sortOrder;
  final String name;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
}

enum TicketAttachmentPhase {
  before('BEFORE'),
  after('AFTER');

  const TicketAttachmentPhase(this.key);

  final String key;
}

class TicketRepairInfo {
  const TicketRepairInfo({
    this.workerName,
    this.repairItems,
    this.completionNote,
    this.totalCost,
    this.costCategory,
    this.expectedCompletionDate,
    this.completedAt,
  });

  final String? workerName;
  final String? repairItems;
  final String? completionNote;
  final num? totalCost;
  final String? costCategory;
  final DateTime? expectedCompletionDate;
  final DateTime? completedAt;

  TicketRepairInfo copyWith({
    String? workerName,
    String? repairItems,
    String? completionNote,
    num? totalCost,
    String? costCategory,
    DateTime? expectedCompletionDate,
    DateTime? completedAt,
  }) {
    return TicketRepairInfo(
      workerName: workerName ?? this.workerName,
      repairItems: repairItems ?? this.repairItems,
      completionNote: completionNote ?? this.completionNote,
      totalCost: totalCost ?? this.totalCost,
      costCategory: costCategory ?? this.costCategory,
      expectedCompletionDate:
          expectedCompletionDate ?? this.expectedCompletionDate,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class TicketReview {
  const TicketReview({
    required this.rating,
    required this.createdAt,
    this.comment,
  });

  final double rating;
  final String? comment;
  final DateTime createdAt;
}

class TicketTimelineEvent {
  const TicketTimelineEvent({
    required this.status,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  final String status;
  final String title;
  final String description;
  final DateTime createdAt;
}

enum TicketUserRole {
  tenant('TENANT'),
  owner('OWNER'),
  manager('MANAGER');

  const TicketUserRole(this.key);

  final String key;

  bool get canManage =>
      this == TicketUserRole.owner || this == TicketUserRole.manager;
}

bool canAcceptTicket(TicketUserRole role, TicketStatus status) {
  return role.canManage && status == TicketStatus.pending;
}

bool canRejectTicket(TicketUserRole role, TicketStatus status) {
  return role.canManage && status == TicketStatus.pending;
}

bool canUpdateProgress(TicketUserRole role, TicketStatus status) {
  return role.canManage &&
      (status == TicketStatus.accepted || status == TicketStatus.inProgress);
}

bool canCompleteTicket(TicketUserRole role, TicketStatus status) {
  return role.canManage && status == TicketStatus.inProgress;
}

bool canConfirmTicket(TicketUserRole role, TicketStatus status) {
  return role == TicketUserRole.tenant &&
      status == TicketStatus.waitingConfirmation;
}

bool canReviewTicket(
  TicketUserRole role,
  TicketStatus status, {
  required bool hasReview,
}) {
  return role == TicketUserRole.tenant &&
      status == TicketStatus.completed &&
      !hasReview;
}

class CurrentRentedRoom {
  const CurrentRentedRoom({required this.id, required this.roomCode});

  final int id;
  final String roomCode;
}

enum TicketScope {
  tenantRoom('TENANT_ROOM');

  const TicketScope(this.key);

  final String key;

  static TicketScope fromBackend(String value) {
    final normalized = value.trim().toUpperCase();
    for (final scope in TicketScope.values) {
      if (normalized == scope.key) {
        return scope;
      }
    }
    return TicketScope.tenantRoom;
  }
}

enum TicketPriority {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const TicketPriority(this.key);

  final String key;

  static TicketPriority fromBackend(String value) {
    final normalized = value.trim().toUpperCase();
    for (final priority in TicketPriority.values) {
      if (normalized == priority.key) {
        return priority;
      }
    }
    return TicketPriority.medium;
  }
}

enum TicketStatus {
  pending('PENDING_ACCEPTANCE', 'Chờ tiếp nhận'),
  accepted('ACCEPTED', 'Đã tiếp nhận'),
  inProgress('IN_PROGRESS', 'Đang xử lý'),
  waitingConfirmation('WAITING_CONFIRMATION', 'Chờ xác nhận'),
  completed('COMPLETED', 'Hoàn tất'),
  rejected('REJECTED', 'Từ chối'),
  cancelled('CANCELLED', 'Đã hủy');

  const TicketStatus(this.key, this.label);

  final String key;
  final String label;

  static TicketStatus fromBackend(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized == 'PENDING') {
      return TicketStatus.pending;
    }
    for (final status in TicketStatus.values) {
      if (normalized == status.key ||
          normalized == status.label.toUpperCase()) {
        return status;
      }
    }
    return TicketStatus.pending;
  }
}

enum TicketCategory {
  equipment('ROOM_EQUIPMENT', 'Thiết bị trong phòng'),
  electricity('ELECTRICITY', 'Điện'),
  water('WATER', 'Nước'),
  airConditioner('AIR_CONDITIONER', 'Điều hòa'),
  internet('WIFI', 'Wifi'),
  doorLock('DOOR_LOCK', 'Cửa / khóa'),
  cleaningDrainage('CLEANING_DRAINAGE', 'Vệ sinh / thoát nước'),
  other('OTHER', 'Khác');

  const TicketCategory(this.key, this.label);

  final String key;
  final String label;

  static TicketCategory fromBackend(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized == 'EQUIPMENT' || normalized == 'THIẾT BỊ') {
      return TicketCategory.equipment;
    }
    if (normalized == 'INTERNET') {
      return TicketCategory.internet;
    }
    for (final category in TicketCategory.values) {
      if (normalized == category.key ||
          normalized == category.label.toUpperCase()) {
        return category;
      }
    }
    return TicketCategory.other;
  }
}
