import '../config/api_config.dart';

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
      code:
          json['ticket_code']?.toString() ??
          json['ticketCode']?.toString() ??
          json['code']?.toString() ??
          '',
      category: TicketCategory.fromBackend(json['category']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdDate:
          DateTime.tryParse(
            json['created_at']?.toString() ??
                json['createdAt']?.toString() ??
                json['created_date']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      status: TicketStatus.fromBackend(json['status']?.toString() ?? ''),
      roomId: int.tryParse(
        json['room_id']?.toString() ?? json['roomId']?.toString() ?? '',
      ),
      roomCode:
          json['room_code']?.toString() ?? json['roomCode']?.toString() ?? '',
      priority: TicketPriority.fromBackend(
        json['severity']?.toString() ?? json['priority']?.toString() ?? '',
      ),
      ticketScope: TicketScope.fromBackend(
        json['scope']?.toString() ??
            json['ticket_scope']?.toString() ??
            json['ticketScope']?.toString() ??
            '',
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
    this.propertyName = '',
    this.ticketScope = TicketScope.tenantRoom,
    this.rejectionReason = '',
    this.beforeAttachments = const [],
    this.afterAttachments = const [],
    this.repairInfo,
    this.review,
    this.events = const [],
    this.billingStatus = '',
    this.billingStatusLabel = '',
    this.invoiceCode = '',
    this.lineType = '',
    this.chargeAmount,
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
  final String propertyName;
  final TicketScope ticketScope;
  final String rejectionReason;
  final List<TicketAttachment> beforeAttachments;
  final List<TicketAttachment> afterAttachments;
  final TicketRepairInfo? repairInfo;
  final TicketReview? review;
  final List<TicketTimelineEvent> events;
  final String billingStatus;
  final String billingStatusLabel;
  final String invoiceCode;
  final String lineType;
  final num? chargeAmount;

  bool get hasRepairData {
    final repair = repairInfo;
    return repair != null &&
        (repair.workerName?.trim().isNotEmpty == true ||
            repair.repairmanPhone?.trim().isNotEmpty == true ||
            repair.rootCause?.trim().isNotEmpty == true ||
            repair.repairItems?.trim().isNotEmpty == true ||
            repair.completionNote?.trim().isNotEmpty == true ||
            repair.totalCost != null ||
            chargeAmount != null ||
            repair.costCategory?.trim().isNotEmpty == true ||
            repair.costResponsibility?.trim().isNotEmpty == true);
  }

  MaintenanceTicketDetail copyWith({
    TicketStatus? status,
    String? propertyName,
    TicketScope? ticketScope,
    String? rejectionReason,
    List<TicketAttachment>? beforeAttachments,
    List<TicketAttachment>? afterAttachments,
    TicketRepairInfo? repairInfo,
    TicketReview? review,
    List<TicketTimelineEvent>? events,
    String? billingStatus,
    String? billingStatusLabel,
    String? invoiceCode,
    String? lineType,
    num? chargeAmount,
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
      propertyName: propertyName ?? this.propertyName,
      ticketScope: ticketScope ?? this.ticketScope,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      beforeAttachments: beforeAttachments ?? this.beforeAttachments,
      afterAttachments: afterAttachments ?? this.afterAttachments,
      repairInfo: repairInfo ?? this.repairInfo,
      review: review ?? this.review,
      events: events ?? this.events,
      billingStatus: billingStatus ?? this.billingStatus,
      billingStatusLabel: billingStatusLabel ?? this.billingStatusLabel,
      invoiceCode: invoiceCode ?? this.invoiceCode,
      lineType: lineType ?? this.lineType,
      chargeAmount: chargeAmount ?? this.chargeAmount,
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
      ticketScope: ticket.ticketScope,
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

  factory MaintenanceTicketDetail.fromJson(Map<String, dynamic> json) {
    final beforeAttachments = _listOfMaps(
      json['before_attachments'] ?? json['beforeAttachments'],
    ).map(TicketAttachment.fromJson).toList(growable: false);
    final afterAttachments = _listOfMaps(
      json['after_attachments'] ?? json['afterAttachments'],
    ).map(TicketAttachment.fromJson).toList(growable: false);
    final allAttachments = _listOfMaps(
      json['attachments'],
    ).map(TicketAttachment.fromJson).toList(growable: false);
    final before = beforeAttachments.isNotEmpty
        ? beforeAttachments
        : allAttachments
              .where((item) => item.phase == TicketAttachmentPhase.before)
              .toList(growable: false);
    final after = afterAttachments.isNotEmpty
        ? afterAttachments
        : allAttachments
              .where((item) => item.phase == TicketAttachmentPhase.after)
              .toList(growable: false);

    final category = TicketCategory.fromBackend(
      json['category']?.toString() ?? '',
    );
    final status = TicketStatus.fromBackend(json['status']?.toString() ?? '');
    final repairInfo = TicketRepairInfo.fromJson(json);
    final reviewJson = _asMap(json['review']);

    return MaintenanceTicketDetail(
      id: _asInt(json['id']) ?? 0,
      ticketCode:
          json['ticket_code']?.toString() ??
          json['ticketCode']?.toString() ??
          json['code']?.toString() ??
          '',
      status: status,
      roomId: _asInt(json['room_id'] ?? json['roomId']) ?? 0,
      roomCode:
          json['room_code']?.toString() ?? json['roomCode']?.toString() ?? '',
      propertyName:
          json['property_name']?.toString() ??
          json['propertyName']?.toString() ??
          '',
      ticketScope: TicketScope.fromBackend(
        json['scope']?.toString() ??
            json['ticket_scope']?.toString() ??
            json['ticketScope']?.toString() ??
            '',
      ),
      category: category,
      categoryName: category.label,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priority: TicketPriority.fromBackend(
        json['severity']?.toString() ?? json['priority']?.toString() ?? '',
      ),
      createdAt:
          DateTime.tryParse(
            json['created_at']?.toString() ??
                json['createdAt']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      rejectionReason:
          json['rejectionReason']?.toString() ??
          json['rejection_reason']?.toString() ??
          '',
      beforeAttachments: before,
      afterAttachments: after,
      repairInfo: repairInfo,
      review: reviewJson.isEmpty ? null : TicketReview.fromJson(reviewJson),
      events: _listOfMaps(
        json['events'],
      ).map(TicketTimelineEvent.fromJson).toList(growable: false),
      billingStatus:
          json['billing_status']?.toString() ??
          json['billingStatus']?.toString() ??
          '',
      billingStatusLabel:
          json['billing_status_label']?.toString() ??
          json['billingStatusLabel']?.toString() ??
          '',
      invoiceCode:
          json['invoice_code']?.toString() ??
          json['invoiceCode']?.toString() ??
          '',
      lineType:
          json['line_type']?.toString() ??
          json['lineType']?.toString() ??
          '',
      chargeAmount:
          _asNum(json['charge_amount'] ?? json['chargeAmount']),
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

  factory TicketAttachment.fromJson(Map<String, dynamic> json) {
    final fileId = _asInt(json['file_id'] ?? json['fileId']);
    final rawUrl = json['url']?.toString() ?? '';
    return TicketAttachment(
      id: _asInt(json['id']) ?? fileId ?? 0,
      url: _resolveFileUrl(rawUrl, fileId),
      mimeType:
          json['mime_type']?.toString() ??
          json['mimeType']?.toString() ??
          'image/jpeg',
      phase: TicketAttachmentPhase.fromBackend(json['phase']?.toString() ?? ''),
      sortOrder: _asInt(json['sort_order'] ?? json['sortOrder']) ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

enum TicketAttachmentPhase {
  before('BEFORE'),
  after('AFTER');

  const TicketAttachmentPhase(this.key);

  final String key;

  static TicketAttachmentPhase fromBackend(String value) {
    final normalized = value.trim().toUpperCase();
    for (final phase in TicketAttachmentPhase.values) {
      if (normalized == phase.key) {
        return phase;
      }
    }
    return TicketAttachmentPhase.before;
  }
}

class TicketRepairInfo {
  const TicketRepairInfo({
    this.workerName,
    this.repairmanPhone,
    this.rootCause,
    this.repairItems,
    this.completionNote,
    this.totalCost,
    this.costCategory,
    this.costResponsibility,
    this.expectedCompletionDate,
    this.completedAt,
  });

  final String? workerName;
  final String? repairmanPhone;
  final String? rootCause;
  final String? repairItems;
  final String? completionNote;
  final num? totalCost;
  final String? costCategory;
  final String? costResponsibility;
  final DateTime? expectedCompletionDate;
  final DateTime? completedAt;

  TicketRepairInfo copyWith({
    String? workerName,
    String? repairmanPhone,
    String? rootCause,
    String? repairItems,
    String? completionNote,
    num? totalCost,
    String? costCategory,
    String? costResponsibility,
    DateTime? expectedCompletionDate,
    DateTime? completedAt,
  }) {
    return TicketRepairInfo(
      workerName: workerName ?? this.workerName,
      repairmanPhone: repairmanPhone ?? this.repairmanPhone,
      rootCause: rootCause ?? this.rootCause,
      repairItems: repairItems ?? this.repairItems,
      completionNote: completionNote ?? this.completionNote,
      totalCost: totalCost ?? this.totalCost,
      costCategory: costCategory ?? this.costCategory,
      costResponsibility: costResponsibility ?? this.costResponsibility,
      expectedCompletionDate:
          expectedCompletionDate ?? this.expectedCompletionDate,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory TicketRepairInfo.fromJson(Map<String, dynamic> json) {
    final workerName =
        json['repairman_name']?.toString() ??
        json['repairmanName']?.toString() ??
        json['worker_name']?.toString() ??
        json['workerName']?.toString();
    final repairItems =
        json['repair_items']?.toString() ?? json['repairItems']?.toString();
    final rootCause =
        json['root_cause']?.toString() ?? json['rootCause']?.toString();
    final completionNote =
        json['completion_note']?.toString() ??
        json['completionNote']?.toString() ??
        json['cost_description']?.toString() ??
        json['costDescription']?.toString();
    final totalCost =
        _asNum(json['actual_cost'] ?? json['actualCost']) ??
        _asNum(json['cost_amount'] ?? json['costAmount']) ??
        _asNum(json['charge_amount'] ?? json['chargeAmount']);
    final completedAt = DateTime.tryParse(
      json['completed_at']?.toString() ?? json['completedAt']?.toString() ?? '',
    );

    if ((workerName == null || workerName.trim().isEmpty) &&
        (repairItems == null || repairItems.trim().isEmpty) &&
        (rootCause == null || rootCause.trim().isEmpty) &&
        (completionNote == null || completionNote.trim().isEmpty) &&
        totalCost == null &&
        completedAt == null) {
      return const TicketRepairInfo();
    }

    return TicketRepairInfo(
      workerName: workerName,
      repairmanPhone:
          json['repairman_phone']?.toString() ??
          json['repairmanPhone']?.toString(),
      rootCause: rootCause,
      repairItems: repairItems,
      completionNote: completionNote,
      totalCost: totalCost,
      costCategory:
          json['cost_description']?.toString() ??
          json['costDescription']?.toString(),
      costResponsibility:
          json['cost_responsibility']?.toString() ??
          json['costResponsibility']?.toString(),
      completedAt: completedAt,
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

  factory TicketReview.fromJson(Map<String, dynamic> json) {
    return TicketReview(
      rating: _asNum(json['rating'])?.toDouble() ?? 0,
      comment: json['comment']?.toString() ?? json['feedback']?.toString(),
      createdAt:
          DateTime.tryParse(
            json['created_at']?.toString() ??
                json['createdAt']?.toString() ??
                '',
          ) ??
          DateTime.now(),
    );
  }
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

  factory TicketTimelineEvent.fromJson(Map<String, dynamic> json) {
    final action = json['action']?.toString() ?? '';
    final toStatus =
        json['to_status']?.toString() ??
        json['toStatus']?.toString() ??
        json['status']?.toString() ??
        '';
    return TicketTimelineEvent(
      status: toStatus,
      title: action.isEmpty ? TicketStatus.fromBackend(toStatus).label : action,
      description: json['note']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(
            json['created_at']?.toString() ??
                json['createdAt']?.toString() ??
                '',
          ) ??
          DateTime.now(),
    );
  }
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

bool canReportNotFixed(TicketUserRole role, TicketStatus status) {
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
  tenantRoom('TENANT_ROOM'),
  commonArea('COMMON_AREA'),
  propertyOperation('PROPERTY_OPERATION');

  const TicketScope(this.key);

  final String key;

  static TicketScope fromBackend(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized == 'ROOM') {
      return TicketScope.tenantRoom;
    }
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
  high('HIGH'),
  urgent('URGENT');

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
  equipment('FURNITURE', 'Thiết bị trong phòng'),
  electricity('ELECTRICITY', 'Điện'),
  water('WATER', 'Nước'),
  airConditioner('AIR_CONDITIONER', 'Điều hòa'),
  internet('INTERNET', 'Wifi'),
  doorLock('SECURITY', 'Cửa / khóa'),
  cleaningDrainage('SANITARY', 'Vệ sinh / thoát nước'),
  other('OTHER', 'Khác');

  const TicketCategory(this.key, this.label);

  final String key;
  final String label;

  static TicketCategory fromBackend(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized == 'EQUIPMENT' ||
        normalized == 'ROOM_EQUIPMENT' ||
        normalized == 'THIẾT BỊ') {
      return TicketCategory.equipment;
    }
    if (normalized == 'WIFI') {
      return TicketCategory.internet;
    }
    if (normalized == 'CLEANING_DRAINAGE') {
      return TicketCategory.cleaningDrainage;
    }
    if (normalized == 'DOOR_LOCK') {
      return TicketCategory.doorLock;
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

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

num? _asNum(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) return const [];
  return value.map(_asMap).where((item) => item.isNotEmpty).toList();
}

String _resolveFileUrl(String rawUrl, int? fileId) {
  final url = rawUrl.trim();
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  final apiRoot = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
  if (url.startsWith('/api/v1')) {
    return '$apiRoot$url';
  }
  if (url.startsWith('/')) {
    return '${ApiConfig.baseUrl}$url';
  }
  if (url.isNotEmpty) {
    return '${ApiConfig.baseUrl}/$url';
  }
  if (fileId != null && fileId > 0) {
    return '${ApiConfig.baseUrl}/files/download/$fileId';
  }
  return '';
}
