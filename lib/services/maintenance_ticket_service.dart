import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/file_metadata_model.dart';
import '../models/maintenance_ticket_model.dart';
import 'authenticated_client.dart';
import 'file_service.dart';

class MaintenanceTicketService {
  const MaintenanceTicketService({
    http.Client? client,
    FileService fileService = const FileService(),
  }) : _client = client,
       _fileService = fileService;

  final http.Client? _client;
  final FileService _fileService;
  http.Client get _effectiveClient => _client ?? AuthenticatedClient();

  static const _timeout = Duration(seconds: 15);

  Future<List<MaintenanceTicketModel>> getTickets({
    String? keyword,
    String? status,
    String? category,
  }) async {
    final query = <String, String>{
      'page': '0',
      'size': '100',
      'sort': 'createdAt,desc',
    };
    final code = keyword?.trim() ?? '';
    if (code.isNotEmpty) {
      query['code'] = code;
    }
    final statusValue = _statusFilter(status);
    if (statusValue != null) {
      query['status'] = statusValue;
    }
    final categoryValue = _categoryFilter(category);
    if (categoryValue != null) {
      query['category'] = categoryValue;
    }

    final body = await _request('GET', '/maintenance/tickets/my', query: query);
    final rows = _rows(_apiData(body));
    final tickets = rows.map(MaintenanceTicketModel.fromJson).toList();
    tickets.sort(_sortTicketForTenantList);
    return List.unmodifiable(tickets);
  }

  Future<MaintenanceTicketModel> createTicket(
    CreateMaintenanceTicketRequest request,
  ) async {
    final attachmentIds = await _uploadAttachments(request.attachments);
    final body = await _request(
      'POST',
      '/maintenance/tickets',
      body: {
        'roomId': request.roomId,
        'category': request.category.key,
        'title': request.title,
        'description': request.description,
        'ticketScope': request.ticketScope.key,
        'scope': request.ticketScope.key,
        'priority': request.priority.key,
        'severity': request.priority.key,
        'attachmentIds': attachmentIds,
      },
    );
    return MaintenanceTicketModel.fromJson(_asMap(_apiData(body)));
  }

  Future<MaintenanceTicketDetail> getTicketDetail(int ticketId) async {
    final body = await _request('GET', '/maintenance/tickets/$ticketId');
    return MaintenanceTicketDetail.fromJson(_asMap(_apiData(body)));
  }

  Future<void> acceptTicket(int ticketId) async {
    await _request('POST', '/maintenance/tickets/$ticketId/approve');
  }

  Future<void> rejectTicket(int ticketId, String reason) async {
    await _request(
      'POST',
      '/maintenance/tickets/$ticketId/decline',
      body: {'reason': reason.trim()},
    );
  }

  Future<void> updateProgress(
    int ticketId, {
    required String workerName,
    required String repairItems,
    DateTime? expectedCompletionDate,
    String? note,
  }) async {
    await _request(
      'POST',
      '/maintenance/tickets/$ticketId/progress',
      body: {
        'workerName': workerName.trim(),
        'repairmanName': workerName.trim(),
        'repairItems': repairItems.trim(),
        'note': note?.trim(),
      },
    );
  }

  Future<void> completeTicket(
    int ticketId, {
    required String completionNote,
    required String costDescription,
    required num amount,
    required String paidBy,
    List<MaintenanceAttachment> afterAttachments = const [],
  }) async {
    final attachmentIds = await _uploadAttachments(afterAttachments);
    await _request(
      'POST',
      '/maintenance/tickets/$ticketId/complete',
      body: {
        'repairItems': costDescription.trim(),
        'costDescription': costDescription.trim(),
        'actualCost': amount.round(),
        'costResponsibility': _costResponsibility(paidBy),
        'completionNote': completionNote.trim(),
        'attachmentIds': attachmentIds,
        'attachmentPhase': 'AFTER',
      },
    );
  }

  Future<void> confirmTicket(int ticketId, {String? satisfactionNote}) async {
    await _request('POST', '/maintenance/tickets/$ticketId/confirm');
  }

  Future<void> reportNotFixed(int ticketId, {String? note}) async {
    await _request(
      'POST',
      '/maintenance/tickets/$ticketId/report-not-fixed',
      body: {'note': note?.trim()},
    );
  }

  Future<TicketReview> reviewTicket(
    int ticketId, {
    required double rating,
    required String comment,
  }) async {
    final body = await _request(
      'POST',
      '/maintenance/tickets/$ticketId/review',
      body: {
        'rating': rating.round(),
        'comment': comment.trim(),
        'feedback': comment.trim(),
      },
    );
    final detail = MaintenanceTicketDetail.fromJson(_asMap(_apiData(body)));
    return detail.review ??
        TicketReview(
          rating: rating,
          comment: comment.trim().isEmpty ? null : comment.trim(),
          createdAt: DateTime.now(),
        );
  }

  Future<List<int>> _uploadAttachments(
    List<MaintenanceAttachment> attachments,
  ) async {
    if (attachments.isEmpty) {
      return const [];
    }
    final ids = <int>[];
    for (final attachment in attachments) {
      if (attachment.type != MaintenanceAttachmentType.image) {
        throw const MaintenanceTicketException(
          'MVP chỉ hỗ trợ đính kèm ảnh jpg, jpeg, png hoặc webp',
        );
      }
      final bytes = _attachmentBytes(attachment);
      final uploaded = await _fileService.uploadSingle(
        bytes: bytes,
        fileName: attachment.name,
        category: FileCategory.TICKET_ATTACHMENT,
        isSensitive: false,
      );
      if (uploaded.fileId > 0) {
        ids.add(uploaded.fileId);
      }
    }
    return ids;
  }

  Uint8List _attachmentBytes(MaintenanceAttachment attachment) {
    final bytes = attachment.previewBytes;
    if (bytes == null || bytes.isEmpty) {
      throw const MaintenanceTicketException(
        'Không đọc được ảnh đính kèm. Vui lòng chọn lại ảnh.',
      );
    }
    return Uint8List.fromList(bytes);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final client = _effectiveClient;
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}$path',
      ).replace(queryParameters: query);
      final encodedBody = body == null ? null : jsonEncode(_stripNulls(body));
      late final http.Response response;
      switch (method) {
        case 'GET':
          response = await client.get(uri).timeout(_timeout);
          break;
        case 'POST':
          response = await client
              .post(uri, body: encodedBody)
              .timeout(_timeout);
          break;
        case 'PATCH':
          response = await client
              .patch(uri, body: encodedBody)
              .timeout(_timeout);
          break;
        default:
          throw MaintenanceTicketException('HTTP method không hỗ trợ: $method');
      }

      final decoded = _decodeBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MaintenanceTicketException(_messageForError(decoded));
      }
      if (decoded.containsKey('code')) {
        final code = _asInt(decoded['code']) ?? 0;
        if (code != 0 && (code < 200 || code >= 300)) {
          throw MaintenanceTicketException(_messageForError(decoded));
        }
      }
      return decoded;
    } on MaintenanceTicketException {
      rethrow;
    } on TimeoutException {
      throw const MaintenanceTicketException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const MaintenanceTicketException('Không kết nối được máy chủ');
    } on FormatException {
      throw const MaintenanceTicketException(
        'Không đọc được dữ liệu phiếu sự cố',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Invalid maintenance response');
  }

  Object? _apiData(Map<String, dynamic> body) {
    if (body.containsKey('code') && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  List<Map<String, dynamic>> _rows(Object? payload) {
    if (payload is List) {
      return payload.map(_asMap).where((item) => item.isNotEmpty).toList();
    }
    final map = _asMap(payload);
    for (final key in ['data', 'content', 'items']) {
      final value = map[key];
      if (value is List) {
        return value.map(_asMap).where((item) => item.isNotEmpty).toList();
      }
    }
    return const [];
  }

  Map<String, dynamic> _stripNulls(Map<String, dynamic> body) {
    final result = <String, dynamic>{};
    body.forEach((key, value) {
      if (value != null) {
        result[key] = value;
      }
    });
    return result;
  }

  String? _statusFilter(String? status) {
    final value = status?.trim() ?? '';
    if (value.isEmpty || value == 'Tất cả') {
      return null;
    }
    return TicketStatus.fromBackend(value).key;
  }

  String? _categoryFilter(String? category) {
    final value = category?.trim() ?? '';
    if (value.isEmpty || value == 'Tất cả') {
      return null;
    }
    return TicketCategory.fromBackend(value).key;
  }

  String _costResponsibility(String paidBy) {
    final normalized = paidBy.trim().toUpperCase();
    if (normalized.contains('KHÁCH') || normalized.contains('TENANT')) {
      return 'TENANT';
    }
    if (normalized.contains('VẬN HÀNH') || normalized.contains('MANAGER')) {
      return 'OPERATION';
    }
    if (normalized.contains('CHỦ') || normalized.contains('OWNER')) {
      return 'OWNER';
    }
    return 'UNDECIDED';
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

  String _messageForError(Map<String, dynamic> body) {
    final message =
        body['message']?.toString() ??
        body['details']?.toString() ??
        body['error']?.toString();
    if (message != null && message.trim().isNotEmpty) {
      return message.trim();
    }
    return 'Không xử lý được phiếu sự cố';
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class MaintenanceTicketException implements Exception {
  const MaintenanceTicketException(this.message);

  final String message;
}
