/// Model đại diện cho một thông báo trong hệ thống.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.eventType = '',
    this.targetType,
    this.targetId,
    this.data = const {},
    this.readAt,
    this.isRead = false,
    this.type = NotificationType.general,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final String eventType;
  final String? targetType;
  final int? targetId;
  final Map<String, String> data;
  final DateTime? readAt;
  final bool isRead;
  final NotificationType type;

  String get roomCode => (data['roomCode'] ?? data['room_code'] ?? '').trim();

  String get roomLabel => roomCode.isEmpty ? '' : 'Ph\u00f2ng $roomCode';

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt,
      eventType: eventType,
      targetType: targetType,
      targetId: targetId,
      data: data,
      readAt: isRead == true && readAt == null ? DateTime.now() : readAt,
      isRead: isRead ?? this.isRead,
      type: type,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    NotificationType parsedType = NotificationType.general;
    final eventType = json['eventType']?.toString() ?? '';
    final normalizedEventType = eventType.toUpperCase();
    final rawData = json['data'];
    final data = rawData is Map
        ? rawData.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          )
        : <String, String>{};
    final rawTargetType = json['targetType']?.toString().trim();
    final targetType = rawTargetType != null && rawTargetType.isNotEmpty
        ? rawTargetType
        : data['targetType'];
    final targetId =
        _asInt(json['targetId']) ??
        _asInt(data['targetId']) ??
        _asInt(data['transferRequestId']) ??
        _asInt(data['invoiceId']);
    final normalizedTargetType = targetType?.toUpperCase() ?? '';

    if (normalizedEventType.contains('INVOICE') ||
        normalizedEventType.contains('PAYMENT') ||
        normalizedTargetType.contains('INVOICE')) {
      parsedType = NotificationType.invoice;
    } else if (normalizedEventType.contains('CONTRACT') ||
        normalizedEventType.contains('LEASE') ||
        normalizedEventType.contains('ROOM_TRANSFER') ||
        normalizedTargetType.contains('CONTRACT') ||
        normalizedTargetType.contains('ROOM_TRANSFER')) {
      parsedType = NotificationType.contract;
    } else if (normalizedEventType.contains('MAINTENANCE') ||
        normalizedEventType.contains('REPAIR') ||
        normalizedEventType.contains('TICKET') ||
        normalizedTargetType.contains('MAINTENANCE') ||
        normalizedTargetType.contains('TICKET')) {
      parsedType = NotificationType.maintenance;
    }

    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Thông báo',
      content: json['body']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      eventType: eventType,
      targetType: targetType,
      targetId: targetId,
      data: data,
      readAt: json['readAt'] == null
          ? null
          : DateTime.tryParse(json['readAt'].toString()),
      isRead:
          _asBool(json['isRead']) ||
          _asBool(json['read']) ||
          _asBool(json['is_read']) ||
          json['readAt'] != null,
      type: parsedType,
    );
  }

  static int? _asInt(Object? value) => int.tryParse(value?.toString() ?? '');

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
}

enum NotificationType {
  invoice,
  contract,
  maintenance,
  general;

  String get label {
    switch (this) {
      case NotificationType.invoice:
        return 'Hóa đơn';
      case NotificationType.contract:
        return 'Hợp đồng';
      case NotificationType.maintenance:
        return 'Sự cố';
      case NotificationType.general:
        return 'Thông báo';
    }
  }
}

// ---------------------------------------------------------------------------
// Mock data – dùng tạm khi chưa có API
// ---------------------------------------------------------------------------
List<NotificationItem> mockNotifications = [
  NotificationItem(
    id: '1',
    title: '[Hóa Đơn Định Kỳ] INV-HN/Phòng 402/2026/HDSV/901-42026',
    content:
        'Phòng của bạn có hóa đơn định kỳ:\n• Tiền thuê phòng (30 ngày từ 01/06/2026 đến 30/06/2026): 3.500.000 đ\n• Tiền điện: 250.000 đ\n• Tiền nước: 80.000 đ\nVui lòng thanh toán trước ngày 05/06/2026.',
    createdAt: DateTime(2026, 6, 1, 8, 0),
    isRead: false,
    type: NotificationType.invoice,
  ),
  NotificationItem(
    id: '2',
    title: 'Hợp đồng sắp hết hạn — Phòng 402',
    content:
        'Hợp đồng thuê phòng 402 của bạn sẽ hết hạn sau 30 ngày (ngày 01/07/2026). Vui lòng liên hệ quản lý để gia hạn hoặc làm thủ tục trả phòng.',
    createdAt: DateTime(2026, 6, 1, 9, 30),
    isRead: false,
    type: NotificationType.contract,
  ),
  NotificationItem(
    id: '3',
    title: 'Phiếu sự cố #SC-0042 đã được tiếp nhận',
    content:
        'Phiếu báo cáo sự cố điện của bạn đã được quản lý tiếp nhận và đang được xử lý. Dự kiến hoàn thành trong 24 giờ.',
    createdAt: DateTime(2026, 5, 30, 14, 15),
    isRead: true,
    type: NotificationType.maintenance,
  ),
  NotificationItem(
    id: '4',
    title: '[Hóa Đơn Định Kỳ] INV-HN/Phòng 402/2026/HDSV/755-52026',
    content:
        'Phòng của bạn có hóa đơn định kỳ:\n• Tiền thuê phòng (31 ngày từ 01/05/2026 đến 31/05/2026): 3.500.000 đ\n• Tiền điện: 210.000 đ\n• Tiền nước: 75.000 đ',
    createdAt: DateTime(2026, 5, 1, 8, 0),
    isRead: true,
    type: NotificationType.invoice,
  ),
  NotificationItem(
    id: '5',
    title: 'Chào mừng bạn đến với HDBHMS',
    content:
        'Tài khoản của bạn đã được kích hoạt thành công. Bạn có thể bắt đầu sử dụng các tính năng của ứng dụng.',
    createdAt: DateTime(2026, 4, 15, 10, 0),
    isRead: true,
    type: NotificationType.general,
  ),
];
