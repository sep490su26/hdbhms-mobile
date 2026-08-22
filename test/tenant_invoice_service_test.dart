import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'fetchElectricityHistory calls the tenant electricity-history endpoint',
    () async {
      late Uri requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 7,
                'invoiceCode': 'INV-7',
                'invoiceType': 'UTILITY',
                'billingPeriod': '2026-07',
                'status': 'PAID',
                'contractId': 42,
                'lines': [
                  {
                    'id': 70,
                    'lineType': 'ELECTRICITY',
                    'description': 'Electricity',
                    'quantity': 30,
                    'unitPrice': 3000,
                    'amount': 90000,
                    'readingPeriod': '2026-07',
                    'previousValue': 120,
                    'currentValue': 150,
                    'usageAmount': 30,
                  },
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final history = await TenantInvoiceService(
        client: client,
      ).fetchElectricityHistory(contractId: 42);

      expect(requestedUri.path, '/api/v1/tenant/invoices/electricity-history');
      expect(requestedUri.queryParameters['contractId'], '42');
      expect(history, hasLength(1));
      expect(history.single.lines.single.usageAmount, 30);
    },
  );
}
