import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/models/tenant_invoice_model.dart' as legacy;

void main() {
  test('tenant invoice uses qrPayload when qrCode is missing', () {
    final invoice = TenantInvoice.fromJson({
      'id': 503,
      'invoiceCode': 'SEED-INV-503-TRANSFER-OUT-ISSUED',
      'invoiceType': 'UTILITY',
      'status': 'ISSUED',
      'remainingAmount': 480000,
      'qrPayload': '00020101021238570010A000000727',
      'transferDescription': 'SEED-INV-503-TRANSFER-OUT-ISSUED',
    });

    expect(invoice.qrCode, '00020101021238570010A000000727');
    expect(invoice.payosQrValue, '00020101021238570010A000000727');
  });

  test('invoice line parses backend readingDate in both mobile models', () {
    final json = {
      'id': 1,
      'lineType': 'ELECTRICITY',
      'readingDate': '2026-05-31',
    };

    expect(TenantInvoiceLine.fromJson(json).readingDate, DateTime(2026, 5, 31));
    expect(
      legacy.TenantInvoiceLine.fromJson(json).readingDate,
      DateTime(2026, 5, 31),
    );
  });

  test('tenant invoice parses the creation date', () {
    final invoice = TenantInvoice.fromJson({
      'issueDate': '2026-08-11T09:30:00',
    });

    expect(invoice.issueDate, DateTime(2026, 8, 11, 9, 30));
  });

  test('normalizes production and legacy rent/service line types', () {
    const productionRent = TenantInvoiceLine(
      id: 1,
      lineType: 'ROOM_RENT',
      description: '',
      quantity: 1,
      unitPrice: 1,
      amount: 1,
    );
    const legacyRent = TenantInvoiceLine(
      id: 2,
      lineType: 'RENT',
      description: '',
      quantity: 1,
      unitPrice: 1,
      amount: 1,
    );
    const productionService = TenantInvoiceLine(
      id: 3,
      lineType: 'SERVICE_FEE',
      description: '',
      quantity: 1,
      unitPrice: 1,
      amount: 1,
    );
    const legacyService = TenantInvoiceLine(
      id: 4,
      lineType: 'SERVICE',
      description: '',
      quantity: 1,
      unitPrice: 1,
      amount: 1,
    );

    expect(productionRent.normalizedLineType, 'RENT');
    expect(legacyRent.normalizedLineType, 'RENT');
    expect(productionService.normalizedLineType, 'SERVICE');
    expect(legacyService.normalizedLineType, 'SERVICE');
  });
}
