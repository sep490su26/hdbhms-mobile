import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../models/payment/tenant_invoice_model.dart';
import '../authenticated_client.dart';

class TenantInvoiceException implements Exception {
  const TenantInvoiceException(this.message);

  final String message;
}

class TenantInvoiceService {
  const TenantInvoiceService({http.Client? client}) : _client = client;

  final http.Client? _client;
  http.Client get _effectiveClient => _client ?? AuthenticatedClient();
  static const _timeout = Duration(seconds: 15);

  Future<List<TenantInvoice>> fetchMyInvoices() async {
    final client = _effectiveClient;
    try {
      final response = await client
          .get(Uri.parse('${ApiConfig.baseUrl}/tenant/invoices'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final decoded = _decodeBody(response.body);
        final data = decoded['data'];
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map(TenantInvoice.fromJson)
              .toList();
        }
        return const [];
      }
      throw TenantInvoiceException(_messageForError(response));
    } on TimeoutException {
      throw const TenantInvoiceException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const TenantInvoiceException('Không kết nối được máy chủ');
    } on FormatException {
      throw const TenantInvoiceException('Dữ liệu hóa đơn không hợp lệ');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<void> submitMeterReadingReview({
    required int invoiceId,
    required int lineId,
    required double reportedCurrentValue,
    required String description,
  }) async {
    final client = _effectiveClient;
    try {
      final response = await client
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/tenant/invoices/$invoiceId/lines/$lineId/meter-reading-reviews',
            ),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'reportedCurrentValue': reportedCurrentValue,
              'description': description,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      throw TenantInvoiceException(_messageForError(response));
    } on TimeoutException {
      throw const TenantInvoiceException('Không kết nối được máy chủ');
    } on http.ClientException {
      throw const TenantInvoiceException('Không kết nối được máy chủ');
    } on FormatException {
      throw const TenantInvoiceException('Dữ liệu phản hồi không hợp lệ');
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  String _messageForError(http.Response response) {
    try {
      final data = _decodeBody(response.body);
      final message = data['message'] ?? data['details'] ?? data['error'];
      if (message != null && message.toString().isNotEmpty) {
        return message.toString();
      }
    } on FormatException {
      // Fall through
    }
    return 'Lỗi tải hóa đơn (${response.statusCode})';
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }
}
