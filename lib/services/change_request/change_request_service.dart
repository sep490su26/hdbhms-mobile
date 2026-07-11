import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/change_request/change_request_model.dart';
import 'package:hdbhms_mobile/services/authenticated_client.dart';

class ChangeRequestException implements Exception {
  const ChangeRequestException(this.message);
  final String message;
}

/// Service for change request (tenant-facing endpoints).
class ChangeRequestService {
  const ChangeRequestService({http.Client? client}) : _client = client;

  final http.Client? _client;
  http.Client get _effectiveClient => _client ?? AuthenticatedClient();
  static const _timeout = Duration(seconds: 20);

  // ── List (tenant's own requests, or filtered) ─────────────────────────────

  /// GET /api/v1/change-requests/my
  Future<List<ChangeRequest>> getMyRequests({
    ChangeRequestType? type,
    ChangeRequestStatus? status,
    String? search,
    int page = 0,
    int size = 50,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      'sort': 'createdAt,desc',
    };
    if (type != null) query['type'] = type.key;
    if (status != null) query['status'] = status.key;
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final json = await _getJson(_uri('/change-requests/my', query));
    final list = _extractList(json);
    return list
        .map(ChangeRequest.fromJson)
        .toList(growable: false);
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  /// GET /api/v1/change-requests/stats
  Future<ChangeRequestStats> getStats() async {
    final json = await _getJson(_uri('/change-requests/stats'));
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return ChangeRequestStats.fromJson(data);
    }
    return const ChangeRequestStats(
      pending: 0,
      approvedToday: 0,
      rejectedToday: 0,
      thisMonth: 0,
    );
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

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
        'Không thể tải danh sách yêu cầu.';
    throw ChangeRequestException(message);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> json) {
    Object? candidate = json['data'];
    if (candidate is Map) {
      candidate =
          candidate['data'] ?? candidate['items'] ?? candidate['content'];
    }
    candidate ??= json['items'] ?? json['content'];
    if (candidate is! List) return const [];
    return candidate
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}

class ChangeRequestStats {
  const ChangeRequestStats({
    required this.pending,
    required this.approvedToday,
    required this.rejectedToday,
    required this.thisMonth,
    this.breakdownByType = const {},
  });

  final int pending;
  final int approvedToday;
  final int rejectedToday;
  final int thisMonth;
  final Map<String, int> breakdownByType;

  factory ChangeRequestStats.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['breakdownByType'];
    final breakdown = <String, int>{};
    if (breakdownRaw is Map) {
      breakdownRaw.forEach((k, v) {
        breakdown[k.toString()] = v is int ? v : int.tryParse(v.toString()) ?? 0;
      });
    }
    return ChangeRequestStats(
      pending: json['pending'] is int ? json['pending'] as int : 0,
      approvedToday: json['approvedToday'] is int ? json['approvedToday'] as int : 0,
      rejectedToday: json['rejectedToday'] is int ? json['rejectedToday'] as int : 0,
      thisMonth: json['thisMonth'] is int ? json['thisMonth'] as int : 0,
      breakdownByType: breakdown,
    );
  }
}
