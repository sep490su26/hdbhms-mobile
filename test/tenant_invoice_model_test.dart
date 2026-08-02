import 'package:flutter_test/flutter_test.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';

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
}
