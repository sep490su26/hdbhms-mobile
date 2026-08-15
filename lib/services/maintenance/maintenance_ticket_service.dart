import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/maintenance/file_metadata_model.dart';
import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';
import 'package:hdbhms_mobile/services/file_service.dart';

class MaintenanceTicketService {
  const MaintenanceTicketService({
    http.Client? client,
    FileService fileService = const FileService(),
  }) : _client = client,
       _fileService = fileService;

  final http.Client? _client;
  final FileService _fileService;

  static const Duration _timeout = Duration(seconds: 20);

  http.Client get _effectiveClient => _client ?? AuthenticatedClient();

  Future<List<MaintenanceTicketModel>> getTickets({
    String? keyword,
    String? status,
    String? category,
    int? roomId,
  }) async {
    final query = <String, String>{
      'page': '0',
      'size': '100',
      'sort': 'createdAt,desc',
    };
    final normalizedKeyword = keyword?.trim();
    if (normalizedKeyword != null && normalizedKeyword.isNotEmpty) {
      query['code'] = normalizedKeyword.replaceAll('#', '');
    }

    final statusValue = _statusQueryValue(status);
    if (statusValue != null) {
      query['status'] = statusValue;
    }

    final categoryValue = _categoryQueryValue(category);
    if (categoryValue != null) {
      query['category'] = categoryValue;
    }
    if ((roomId ?? 0) > 0) {
      query['roomId'] = roomId.toString();
    }

    final json = await _getJson(_uri('/maintenance/tickets/my', query));
    final tickets = _extractList(
      json,
    ).map(MaintenanceTicketModel.fromJson).toList(growable: false);
    final sorted = [...tickets]..sort(_sortTicketForTenantList);
    return List.unmodifiable(sorted);
  }

  Future<MaintenanceTicketModel> createTicket(
    CreateMaintenanceTicketRequest request,
  ) async {
    final attachmentIds = await _uploadAttachments(request.attachments);
    final json = await _postJson(_uri('/maintenance/tickets'), {
      'roomId': request.roomId,
      'category': request.category.key,
      'title': request.title,
      'description': request.description,
      'repairRequested': request.repairRequested,
      'ticketScope': request.ticketScope.key,
      'scope': request.ticketScope.key,
      'priority': request.priority.key,
      'severity': request.priority.key,
      'attachmentIds': attachmentIds,
    });
    return MaintenanceTicketModel.fromJson(_extractObject(json));
  }

  Future<MaintenanceTicketDetail> getTicketDetail(int ticketId) async {
    final json = await _getJson(_uri('/maintenance/tickets/$ticketId'));
    return MaintenanceTicketDetail.fromJson(_extractObject(json));
  }

  Future<void> acceptTicket(int ticketId) async {
    await _postJson(_uri('/maintenance/tickets/$ticketId/approve'), {});
  }

  Future<void> rejectTicket(int ticketId, String reason) async {
    await _postJson(_uri('/maintenance/tickets/$ticketId/decline'), {
      'reason': reason.trim(),
    });
  }

  Future<void> decideRepair(
    int ticketId, {
    required bool approved,
    String? reason,
  }) async {
    await _postJson(_uri('/maintenance/tickets/$ticketId/repair-decision'), {
      'approved': approved,
      if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim(),
    });
  }

  Future<void> updateRepairInfo(
    int ticketId, {
    required String workerName,
    required String repairItems,
    required num amount,
    String? repairmanPhone,
    String? rootCause,
    String? costResponsibility,
  }) async {
    await _patchJson(_uri('/maintenance/tickets/$ticketId/repair-info'), {
      'workerName': workerName.trim(),
      'repairmanName': workerName.trim(),
      'repairmanPhone': repairmanPhone?.trim(),
      'rootCause': rootCause?.trim(),
      'repairItems': repairItems.trim(),
      'amount': amount.round(),
      'actualCost': amount.round(),
      'costDescription': repairItems.trim(),
      'costResponsibility': costResponsibility,
    });
  }

  Future<void> updateProgress(
    int ticketId, {
    required String workerName,
    required String repairItems,
    DateTime? expectedCompletionDate,
    String? note,
  }) async {
    await _postJson(_uri('/maintenance/tickets/$ticketId/progress'), {
      'workerName': workerName.trim(),
      'repairmanName': workerName.trim(),
      'repairItems': repairItems.trim(),
      if (expectedCompletionDate != null)
        'expectedCompletionDate': _dateOnly(expectedCompletionDate),
      if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
    });
  }

  Future<void> completeTicket(
    int ticketId, {
    required String completionNote,
    String? workerName,
    String? repairmanPhone,
    String? repairItems,
    String? rootCause,
    String? costDescription,
    num? amount,
    String? paidBy,
    String? costResponsibility,
    String? collectionMethod,
    String? billingPeriod,
    List<MaintenanceAttachment> afterAttachments = const [],
  }) async {
    final normalizedPaidBy = paidBy == null ? null : _paidByValue(paidBy);
    final chargeToTenant = normalizedPaidBy == 'TENANT' ||
        costResponsibility?.trim().toUpperCase() == 'TENANT';
    final attachmentIds = await _uploadAttachments(afterAttachments);
    await _postJson(_uri('/maintenance/tickets/$ticketId/complete'), {
      'completionNote': completionNote.trim(),
      if (workerName?.trim().isNotEmpty == true) 'workerName': workerName!.trim(),
      if (repairmanPhone?.trim().isNotEmpty == true)
        'repairmanPhone': repairmanPhone!.trim(),
      if (repairItems?.trim().isNotEmpty == true) 'repairItems': repairItems!.trim(),
      if (rootCause?.trim().isNotEmpty == true) 'rootCause': rootCause!.trim(),
      if (costDescription?.trim().isNotEmpty == true)
        'costDescription': costDescription!.trim(),
      if (amount != null) ...{
        'amount': amount.round(),
        'actualCost': amount.round(),
      },
      'paidBy': ?normalizedPaidBy,
      if (costResponsibility?.trim().isNotEmpty == true)
        'costResponsibility': costResponsibility!.trim().toUpperCase(),
      if (paidBy != null || costResponsibility != null)
        'chargeToTenant': chargeToTenant,
      if (chargeToTenant) 'lineType': 'MAINTENANCE_COMPENSATION',
      if (collectionMethod?.trim().isNotEmpty == true)
        'collectionMethod': collectionMethod!.trim().toUpperCase(),
      if (billingPeriod?.trim().isNotEmpty == true)
        'billingPeriod': billingPeriod!.trim(),
      'attachmentPhase': 'AFTER',
      'attachmentIds': attachmentIds,
    });
  }

  Future<void> confirmTicket(int ticketId, {String? satisfactionNote}) async {
    await _postJson(_uri('/maintenance/tickets/$ticketId/confirm'), {
      if (satisfactionNote?.trim().isNotEmpty == true)
        'note': satisfactionNote!.trim(),
    });
  }

  Future<TicketReview> reviewTicket(
    int ticketId, {
    required double rating,
    required String comment,
  }) async {
    final json = await _postJson(
      _uri('/maintenance/tickets/$ticketId/review'),
      {'rating': rating.round(), 'comment': comment.trim()},
    );
    final detail = MaintenanceTicketDetail.fromJson(_extractObject(json));
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

    final fileIds = <int>[];
    for (final attachment in attachments.take(3)) {
      final bytes = await _readAttachmentBytes(attachment);
      final uploaded = await _fileService.uploadSingle(
        bytes: bytes,
        fileName: attachment.name,
        category: FileCategory.maintenance,
      );
      if (uploaded.fileId > 0) {
        fileIds.add(uploaded.fileId);
      }
    }
    return fileIds;
  }

  Future<Uint8List> _readAttachmentBytes(
    MaintenanceAttachment attachment,
  ) async {
    final previewBytes = attachment.previewBytes;
    if (previewBytes != null && previewBytes.isNotEmpty) {
      return Uint8List.fromList(previewBytes);
    }

    final path = attachment.path.trim();
    if (path.isEmpty) {
      throw const MaintenanceTicketException('Không đọc được tệp đính kèm.');
    }
    return File(path).readAsBytes();
  }

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

  Future<Map<String, dynamic>> _patchJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .patch(uri, body: jsonEncode(_withoutNulls(body)))
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
        'Không thể tải dữ liệu phiếu sự cố.';
    throw MaintenanceTicketException(message);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
  }

  Map<String, dynamic> _extractObject(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return json;
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> json) {
    Object? candidate = json['data'];
    if (candidate is Map) {
      candidate =
          candidate['data'] ?? candidate['items'] ?? candidate['content'];
    }
    candidate ??= json['items'] ?? json['content'];
    if (candidate is! List) {
      return const [];
    }
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

  String? _statusQueryValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty || normalized == 'Tất cả') {
      return null;
    }
    return TicketStatus.fromBackend(normalized).key;
  }

  String? _categoryQueryValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty || normalized == 'Tất cả') {
      return null;
    }
    return TicketCategory.fromBackend(normalized).key;
  }

  String _paidByValue(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.contains('TENANT') || normalized.contains('KHÁCH')) {
      return 'TENANT';
    }
    if (normalized.contains('MANAGER') || normalized.contains('QUẢN')) {
      return 'MANAGER';
    }
    if (normalized.contains('OTHER') || normalized.contains('KHÁC')) {
      return 'OTHER';
    }
    return 'LANDLORD';
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
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
      TicketStatus.waitingTenantDecision => 1,
      TicketStatus.accepted => 2,
      TicketStatus.inProgress => 3,
      TicketStatus.waitingConfirmation => 4,
      TicketStatus.completed => 5,
      TicketStatus.rejected => 6,
      TicketStatus.cancelled => 7,
    };
  }
}

class MaintenanceTicketException implements Exception {
  const MaintenanceTicketException(this.message);

  final String message;
}
