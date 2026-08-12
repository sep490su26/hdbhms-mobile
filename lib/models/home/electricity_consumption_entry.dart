import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';

/// Immutable, tenant-scoped data used by both Home and the electricity history.
///
/// Keeping this as presentation data prevents the two surfaces from selecting
/// different invoice samples for the same rental context.
class ElectricityConsumptionEntry {
  const ElectricityConsumptionEntry({
    required this.invoice,
    required this.line,
    required this.periodKey,
    required this.periodLabel,
    required this.referenceDate,
    required this.previousReading,
    required this.currentReading,
    required this.usage,
    required this.unitPrice,
    required this.amount,
  });

  final TenantInvoice invoice;
  final TenantInvoiceLine line;
  final String periodKey;
  final String periodLabel;
  final DateTime referenceDate;
  final double? previousReading;
  final double? currentReading;
  final double? usage;
  final int unitPrice;
  final int amount;
}
