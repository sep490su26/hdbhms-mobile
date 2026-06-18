import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';

class MaintenanceTicketService {
  const MaintenanceTicketService();

  // Future API endpoint:
  // GET /api/v1/tenants/{tenantId}/tickets
  Future<List<MaintenanceTicketModel>> getTickets({
    String? keyword,
    String? status,
    String? category,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final normalizedKeyword = keyword?.trim().toLowerCase() ?? '';
    final normalizedStatus = status?.trim();
    final normalizedCategory = category?.trim();

    final filtered = _mockTickets.where((ticket) {
      final matchesKeyword =
          normalizedKeyword.isEmpty ||
          ticket.code.toLowerCase().contains(normalizedKeyword) ||
          ticket.code
              .toLowerCase()
              .replaceAll('#', '')
              .contains(normalizedKeyword.replaceAll('#', ''));
      final matchesStatus =
          normalizedStatus == null ||
          normalizedStatus.isEmpty ||
          normalizedStatus == 'Tất cả' ||
          ticket.status.label == normalizedStatus ||
          ticket.status.key == normalizedStatus;
      final matchesCategory =
          normalizedCategory == null ||
          normalizedCategory.isEmpty ||
          normalizedCategory == 'Tất cả' ||
          ticket.category.label == normalizedCategory ||
          ticket.category.key == normalizedCategory;

      return matchesKeyword && matchesStatus && matchesCategory;
    }).toList();

    filtered.sort(_sortTicketForTenantList);
    return List.unmodifiable(filtered);
  }

  // Future API endpoint:
  // POST /api/v1/tenants/{tenantId}/tickets
  Future<MaintenanceTicketModel> createTicket(
    CreateMaintenanceTicketRequest request,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final ticket = MaintenanceTicketModel(
      id: _mockTickets.length + 1,
      code: '#${_generateTicketCode()}',
      category: request.category,
      title: request.title,
      description: request.description,
      createdDate: DateTime.now(),
      status: TicketStatus.pending,
      roomId: request.roomId,
      roomCode: '201',
      priority: request.priority,
      ticketScope: request.ticketScope,
    );
    _mockTickets.insert(0, ticket);
    _mockDetails[ticket.id] = MaintenanceTicketDetail.fromTicket(ticket);
    return ticket;
  }

  // Future API endpoint:
  // GET /api/v1/tenants/{tenantId}/tickets/{ticketId}
  Future<MaintenanceTicketDetail> getTicketDetail(int ticketId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final detail = _mockDetails[ticketId];
    if (detail != null) {
      return detail;
    }

    MaintenanceTicketModel? ticket;
    for (final item in _mockTickets) {
      if (item.id == ticketId) {
        ticket = item;
        break;
      }
    }
    if (ticket == null) {
      throw const MaintenanceTicketException('Không tìm thấy phiếu sự cố');
    }

    final created = MaintenanceTicketDetail.fromTicket(ticket);
    _mockDetails[ticketId] = created;
    return created;
  }

  // Future API endpoint:
  // POST /api/v1/tenants/{tenantId}/tickets/{ticketId}/accept
  Future<void> acceptTicket(int ticketId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final detail = await getTicketDetail(ticketId);
    final updated = detail.copyWith(
      status: TicketStatus.accepted,
      events: [
        ...detail.events,
        TicketTimelineEvent(
          status: TicketStatus.accepted.key,
          title: 'Đã tiếp nhận',
          description: 'Ban quản lý đã xác nhận yêu cầu',
          createdAt: DateTime.now(),
        ),
      ],
    );
    _saveDetail(updated);
  }

  // Future API endpoint:
  // POST /api/v1/tenants/{tenantId}/tickets/{ticketId}/reject
  Future<void> rejectTicket(int ticketId, String reason) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final detail = await getTicketDetail(ticketId);
    final updated = detail.copyWith(
      status: TicketStatus.rejected,
      events: [
        ...detail.events,
        TicketTimelineEvent(
          status: TicketStatus.rejected.key,
          title: 'Từ chối',
          description: reason.trim(),
          createdAt: DateTime.now(),
        ),
      ],
    );
    _saveDetail(updated);
  }

  // Future API endpoint:
  // POST /api/v1/tenants/{tenantId}/tickets/{ticketId}/update-progress
  Future<void> updateProgress(
    int ticketId, {
    required String workerName,
    required String repairItems,
    DateTime? expectedCompletionDate,
    String? note,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final detail = await getTicketDetail(ticketId);
    final currentRepair = detail.repairInfo ?? const TicketRepairInfo();
    final updatedRepair = currentRepair.copyWith(
      workerName: workerName.trim().isEmpty ? null : workerName.trim(),
      repairItems: repairItems.trim().isEmpty ? null : repairItems.trim(),
      expectedCompletionDate: expectedCompletionDate,
    );
    final updated = detail.copyWith(
      status: TicketStatus.inProgress,
      repairInfo: updatedRepair,
      events: [
        ...detail.events,
        TicketTimelineEvent(
          status: TicketStatus.inProgress.key,
          title: 'Đang sửa chữa',
          description: note?.trim().isNotEmpty == true
              ? note!.trim()
              : 'Kỹ thuật viên đang có mặt tại căn hộ',
          createdAt: DateTime.now(),
        ),
      ],
    );
    _saveDetail(updated);
  }

  // Future API endpoint:
  // POST /api/v1/tenants/{tenantId}/tickets/{ticketId}/complete
  Future<void> completeTicket(
    int ticketId, {
    required String completionNote,
    required String costDescription,
    required num amount,
    required String paidBy,
    List<TicketAttachment> afterAttachments = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final detail = await getTicketDetail(ticketId);
    final currentRepair = detail.repairInfo ?? const TicketRepairInfo();
    final updatedRepair = currentRepair.copyWith(
      completionNote: completionNote.trim(),
      costCategory: costDescription.trim().isEmpty
          ? currentRepair.costCategory
          : costDescription.trim(),
      totalCost: amount <= 0 ? currentRepair.totalCost : amount,
      completedAt: DateTime.now(),
    );
    final attachments = afterAttachments.isEmpty
        ? _defaultAfterAttachments(ticketId)
        : afterAttachments;
    final updated = detail.copyWith(
      status: TicketStatus.waitingConfirmation,
      repairInfo: updatedRepair,
      afterAttachments: attachments,
      events: [
        ...detail.events,
        TicketTimelineEvent(
          status: TicketStatus.waitingConfirmation.key,
          title: 'Chờ xác nhận',
          description: paidBy.trim().isEmpty
              ? 'Sự cố đã được xử lý, chờ khách xác nhận'
              : 'Sự cố đã được xử lý, chi phí do ${paidBy.trim()} thanh toán',
          createdAt: DateTime.now(),
        ),
      ],
    );
    _saveDetail(updated);
  }

  // Future API endpoint:
  // POST /api/v1/tenants/{tenantId}/tickets/{ticketId}/confirm
  Future<void> confirmTicket(int ticketId, {String? satisfactionNote}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final detail = await getTicketDetail(ticketId);
    if (detail.status == TicketStatus.completed) {
      return;
    }
    final updated = detail.copyWith(
      status: TicketStatus.completed,
      events: [
        ...detail.events,
        TicketTimelineEvent(
          status: TicketStatus.completed.key,
          title: 'Hoàn tất',
          description: satisfactionNote?.trim().isNotEmpty == true
              ? satisfactionNote!.trim()
              : 'Khách thuê đã xác nhận sự cố được xử lý xong',
          createdAt: DateTime.now(),
        ),
      ],
    );
    _saveDetail(updated);
  }

  // Future API endpoint:
  // POST /api/v1/tenants/{tenantId}/tickets/{ticketId}/review
  Future<TicketReview> reviewTicket(
    int ticketId, {
    required double rating,
    required String comment,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final detail = await getTicketDetail(ticketId);
    final review = TicketReview(
      rating: rating,
      comment: comment.trim().isEmpty ? null : comment.trim(),
      createdAt: DateTime.now(),
    );
    final updated = detail.copyWith(review: review);
    _saveDetail(updated);
    return review;
  }

  void _saveDetail(MaintenanceTicketDetail detail) {
    _mockDetails[detail.id] = detail;
    final index = _mockTickets.indexWhere((ticket) => ticket.id == detail.id);
    if (index == -1) {
      return;
    }
    _mockTickets[index] = _mockTickets[index].copyWith(status: detail.status);
  }

  int _sortTicketForTenantList(
    MaintenanceTicketModel first,
    MaintenanceTicketModel second,
  ) {
    final priority = _statusSortWeight(
      first.status,
    ).compareTo(_statusSortWeight(second.status));
    if (priority != 0) {
      return priority;
    }
    return second.createdDate.compareTo(first.createdDate);
  }

  int _statusSortWeight(TicketStatus status) {
    return switch (status) {
      TicketStatus.pending => 0,
      TicketStatus.inProgress => 1,
      TicketStatus.accepted => 2,
      TicketStatus.waitingConfirmation => 3,
      TicketStatus.completed => 4,
      TicketStatus.rejected => 5,
      TicketStatus.cancelled => 6,
    };
  }

  String _generateTicketCode() {
    final year = DateTime.now().year;
    final next = (_mockTickets.length + 1).toString().padLeft(4, '0');
    return 'SC-$year-$next';
  }

  static final List<MaintenanceTicketModel> _mockTickets = [
    MaintenanceTicketModel(
      id: 4,
      code: '#SC-2026-0004',
      category: TicketCategory.electricity,
      title: 'Điện trong phòng chập chờn',
      description: 'Ổ điện gần bàn học lúc có lúc mất nguồn.',
      createdDate: DateTime(2026, 5, 18),
      status: TicketStatus.pending,
      roomId: 1,
      roomCode: '201',
    ),
    MaintenanceTicketModel(
      id: 5,
      code: '#SC-2026-0005',
      category: TicketCategory.airConditioner,
      title: 'Điều hòa đang được kiểm tra',
      description: 'Điều hòa phòng ngủ vẫn kêu to sau khi bật khoảng 10 phút.',
      createdDate: DateTime(2026, 5, 17),
      status: TicketStatus.inProgress,
      roomId: 1,
      roomCode: '201',
    ),
    MaintenanceTicketModel(
      id: 6,
      code: '#SC-2026-0006',
      category: TicketCategory.cleaningDrainage,
      title: 'Vòi sen đã sửa, chờ xác nhận',
      description: 'Vòi sen trong nhà tắm đã được thợ xử lý.',
      createdDate: DateTime(2026, 5, 16),
      status: TicketStatus.waitingConfirmation,
      roomId: 1,
      roomCode: '201',
    ),
    MaintenanceTicketModel(
      id: 1,
      code: '#SC-2825',
      category: TicketCategory.equipment,
      title: 'Máy lạnh phòng ngủ không lạnh',
      description: 'Máy lạnh phòng ngủ không lạnh, kêu to khi hoạt động.',
      createdDate: DateTime(2023, 10, 5),
      status: TicketStatus.completed,
      roomId: 1,
      roomCode: '201',
    ),
    MaintenanceTicketModel(
      id: 2,
      code: '#SC-2810',
      category: TicketCategory.other,
      title: 'Sơn lại tường phòng khách',
      description: 'Sơn lại tường phòng khách theo yêu cầu cá nhân.',
      createdDate: DateTime(2023, 10, 1),
      status: TicketStatus.rejected,
      roomId: 1,
      roomCode: '201',
    ),
    MaintenanceTicketModel(
      id: 3,
      code: '#SC-2805',
      category: TicketCategory.water,
      title: 'Nước chảy yếu tại vòi sen',
      description: 'Nước chảy yếu tại vòi sen tắm.',
      createdDate: DateTime(2023, 9, 28),
      status: TicketStatus.accepted,
      roomId: 1,
      roomCode: '201',
    ),
  ];

  static final Map<int, MaintenanceTicketDetail> _mockDetails = {
    4: MaintenanceTicketDetail(
      id: 4,
      ticketCode: '#SC-2026-0004',
      status: TicketStatus.pending,
      roomId: 1,
      roomCode: '201',
      category: TicketCategory.electricity,
      categoryName: 'Hệ thống điện & Chiếu sáng',
      title: 'Điện trong phòng chập chờn',
      description: 'Ổ điện gần bàn học lúc có lúc mất nguồn.',
      priority: TicketPriority.medium,
      createdAt: DateTime(2026, 5, 18, 9, 20),
      beforeAttachments: _beforeElectricalAttachments,
      events: [
        TicketTimelineEvent(
          status: TicketStatus.pending.key,
          title: 'Yêu cầu mới',
          description: 'Đã gửi báo cáo sự cố',
          createdAt: DateTime(2026, 5, 18, 9, 20),
        ),
      ],
    ),
    5: MaintenanceTicketDetail(
      id: 5,
      ticketCode: '#SC-2026-0005',
      status: TicketStatus.inProgress,
      roomId: 1,
      roomCode: '201',
      category: TicketCategory.airConditioner,
      categoryName: 'Điều hòa',
      title: 'Điều hòa đang được kiểm tra',
      description: 'Điều hòa phòng ngủ vẫn kêu to sau khi bật khoảng 10 phút.',
      priority: TicketPriority.medium,
      createdAt: DateTime(2026, 5, 17, 14, 30),
      beforeAttachments: _airConditionerAttachments,
      repairInfo: const TicketRepairInfo(
        workerName: 'Thợ Hùng - 0987654321',
        repairItems: 'Kiểm tra block máy lạnh',
        totalCost: 0,
      ),
      events: [
        TicketTimelineEvent(
          status: TicketStatus.pending.key,
          title: 'Yêu cầu mới',
          description: 'Đã gửi báo cáo sự cố',
          createdAt: DateTime(2026, 5, 17, 14, 30),
        ),
        TicketTimelineEvent(
          status: TicketStatus.accepted.key,
          title: 'Đã tiếp nhận',
          description: 'Ban quản lý đã xác nhận yêu cầu',
          createdAt: DateTime(2026, 5, 17, 15, 0),
        ),
        TicketTimelineEvent(
          status: TicketStatus.inProgress.key,
          title: 'Đang sửa chữa',
          description: 'Kỹ thuật viên đang có mặt tại căn hộ',
          createdAt: DateTime(2026, 5, 17, 15, 25),
        ),
      ],
    ),
    1: MaintenanceTicketDetail(
      id: 1,
      ticketCode: '#SC-2825',
      status: TicketStatus.completed,
      roomId: 1,
      roomCode: '201',
      category: TicketCategory.equipment,
      categoryName: 'Hệ thống điện & Chiếu sáng',
      title: 'Máy lạnh phòng ngủ không lạnh',
      description:
          'Đèn trần tại khu vực phòng khách có hiện tượng nhấp nháy liên tục sau đó tắt hẳn. Đã thử thay bóng mới nhưng vẫn không hoạt động. Có mùi khét nhẹ gần ổ cắm điện.',
      priority: TicketPriority.medium,
      createdAt: DateTime(2023, 10, 24, 14, 30),
      beforeAttachments: _beforeElectricalAttachments,
      afterAttachments: _defaultAfterAttachments(1),
      repairInfo: TicketRepairInfo(
        workerName: 'Thợ Hùng - 0987654321',
        repairItems: 'Thay tụ điện & Bóng LED',
        completionNote: 'Đã thay tụ điện, kiểm tra lại nguồn và đèn trần.',
        totalCost: 450000,
        costCategory: 'Thay tụ điện & Bóng LED',
        completedAt: DateTime(2023, 10, 25, 10, 45),
      ),
      review: TicketReview(
        rating: 5,
        comment:
            'Thợ đến đúng giờ, xử lý rất chuyên nghiệp và gọn gàng. Tôi rất hài lòng với chất lượng phục vụ của ban quản lý.',
        createdAt: DateTime(2023, 10, 25, 16, 5),
      ),
      events: [
        TicketTimelineEvent(
          status: TicketStatus.pending.key,
          title: 'Yêu cầu mới',
          description: 'Đã gửi báo cáo sự cố',
          createdAt: DateTime(2023, 10, 24, 14, 30),
        ),
        TicketTimelineEvent(
          status: TicketStatus.accepted.key,
          title: 'Đã tiếp nhận',
          description: 'Ban quản lý đã xác nhận yêu cầu',
          createdAt: DateTime(2023, 10, 24, 15, 0),
        ),
        TicketTimelineEvent(
          status: TicketStatus.inProgress.key,
          title: 'Đang sửa chữa',
          description: 'Kỹ thuật viên đang có mặt tại căn hộ',
          createdAt: DateTime(2023, 10, 25, 9, 15),
        ),
        TicketTimelineEvent(
          status: TicketStatus.completed.key,
          title: 'Hoàn tất',
          description: 'Sự cố đã được xử lý xong',
          createdAt: DateTime(2023, 10, 25, 10, 45),
        ),
      ],
    ),
    6: MaintenanceTicketDetail(
      id: 6,
      ticketCode: '#SC-2026-0006',
      status: TicketStatus.waitingConfirmation,
      roomId: 1,
      roomCode: '201',
      category: TicketCategory.cleaningDrainage,
      categoryName: 'Vệ sinh / thoát nước',
      title: 'Vòi sen đã sửa, chờ xác nhận',
      description: 'Vòi sen trong nhà tắm đã được thợ xử lý.',
      priority: TicketPriority.medium,
      createdAt: DateTime(2026, 5, 16, 8, 15),
      beforeAttachments: const [],
      afterAttachments: const [],
      repairInfo: TicketRepairInfo(
        workerName: 'Thợ Minh - 0912345678',
        repairItems: 'Sửa chữa vòi sen',
        completionNote: 'Đã thay ron cao su và kiểm tra lại áp lực nước.',
        totalCost: 120000,
        costCategory: 'Sửa chữa vòi sen',
        completedAt: DateTime(2026, 5, 16, 14, 10),
      ),
      events: [
        TicketTimelineEvent(
          status: TicketStatus.pending.key,
          title: 'Yêu cầu mới',
          description: 'Đã gửi báo cáo sự cố',
          createdAt: DateTime(2026, 5, 16, 8, 15),
        ),
        TicketTimelineEvent(
          status: TicketStatus.accepted.key,
          title: 'Đã tiếp nhận',
          description: 'Ban quản lý đã xác nhận yêu cầu',
          createdAt: DateTime(2026, 5, 16, 8, 45),
        ),
        TicketTimelineEvent(
          status: TicketStatus.inProgress.key,
          title: 'Đang sửa chữa',
          description: 'Kỹ thuật viên đang sửa vòi sen',
          createdAt: DateTime(2026, 5, 16, 13, 20),
        ),
        TicketTimelineEvent(
          status: TicketStatus.waitingConfirmation.key,
          title: 'Chờ xác nhận',
          description: 'Sự cố đã được xử lý, chờ khách xác nhận',
          createdAt: DateTime(2026, 5, 16, 14, 10),
        ),
      ],
    ),
  };
}

class MaintenanceTicketException implements Exception {
  const MaintenanceTicketException(this.message);

  final String message;
}

const _beforeElectricalAttachments = [
  TicketAttachment(
    id: 1,
    url:
        'https://images.unsplash.com/photo-1509391366360-2e959784a276?auto=format&fit=crop&w=900&q=80',
    mimeType: 'image/jpeg',
    phase: TicketAttachmentPhase.before,
    sortOrder: 1,
    name: 'den-tran-loi.jpg',
  ),
  TicketAttachment(
    id: 2,
    url:
        'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=900&q=80',
    mimeType: 'image/jpeg',
    phase: TicketAttachmentPhase.before,
    sortOrder: 2,
    name: 'o-dien.jpg',
  ),
  TicketAttachment(
    id: 3,
    url: 'mock-video-before',
    mimeType: 'video/mp4',
    phase: TicketAttachmentPhase.before,
    sortOrder: 3,
    name: 'video-hien-trang.mp4',
  ),
];

const _airConditionerAttachments = [
  TicketAttachment(
    id: 4,
    url:
        'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=900&q=80',
    mimeType: 'image/jpeg',
    phase: TicketAttachmentPhase.before,
    sortOrder: 1,
    name: 'dieu-hoa.jpg',
  ),
];

List<TicketAttachment> _defaultAfterAttachments(int ticketId) {
  return [
    TicketAttachment(
      id: 1000 + ticketId,
      url:
          'https://images.unsplash.com/photo-1518005020951-eccb494ad742?auto=format&fit=crop&w=900&q=80',
      mimeType: 'image/jpeg',
      phase: TicketAttachmentPhase.after,
      sortOrder: 1,
      name: 'sau-sua-chua.jpg',
    ),
  ];
}
