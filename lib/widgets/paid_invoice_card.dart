import 'package:flutter/material.dart';

import '../models/payment/tenant_invoice_model.dart';
import '../theme/app_colors.dart';

/// Shared paid-invoice card used by the bill list and payment history.
class PaidInvoiceCard extends StatelessWidget {
  const PaidInvoiceCard({super.key, required this.invoice, this.onTap});

  final TenantInvoice invoice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amount = invoice.paidAmount > 0
        ? invoice.paidAmount
        : invoice.totalAmount;
    final createdDate =
        invoice.issueDate ??
        invoice.issuedAt ??
        invoice.paidAt ??
        invoice.dueDate ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.success, Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(AppColors.radiusLg),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEFFF),
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      ),
                      child: Icon(
                        _invoiceIcon(invoice),
                        color: AppColors.deepBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.inputText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 20 / 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (invoice.roomCode.isNotEmpty)
                                'Phòng ${invoice.roomCode}',
                              _formatDate(createdDate),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.bodyText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 17 / 12,
                            ),
                          ),
                          if (invoice.invoiceCode.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              invoice.invoiceCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.hintText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 15 / 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const _PaidStatusPill(),
                              _InvoiceTypePill(invoice: invoice),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_formatAmount(amount)}đ',
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 21 / 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      child: card,
    );
  }
}

class _PaidStatusPill extends StatelessWidget {
  const _PaidStatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD7FBE4),
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.successText,
            size: 12,
          ),
          SizedBox(width: 4),
          Text(
            'ĐÃ THANH TOÁN',
            style: TextStyle(
              color: Color(0xFF15803D),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 13 / 10,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTypePill extends StatelessWidget {
  const _InvoiceTypePill({required this.invoice});

  final TenantInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final color = _invoiceTypeColor(invoice);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_invoiceTypeIcon(invoice), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            invoice.invoiceTypeLabel,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 14 / 10,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _invoiceTypeIcon(TenantInvoice invoice) {
  if (invoice.isRentType) return Icons.apartment_rounded;
  if (invoice.isUtilityType) return Icons.bolt_rounded;
  return Icons.more_horiz_rounded;
}

IconData _invoiceIcon(TenantInvoice invoice) {
  final lineTypes = invoice.lines.map((line) => line.lineType).toSet();
  if (lineTypes.contains('VIOLATION_FINE')) return Icons.gavel_rounded;
  if (lineTypes.contains('MAINTENANCE_COMPENSATION')) {
    return Icons.construction_rounded;
  }
  if (invoice.isUtilityType) return Icons.flash_on_outlined;
  if (invoice.isRentType) return Icons.receipt_long_outlined;
  return Icons.payments_outlined;
}

Color _invoiceTypeColor(TenantInvoice invoice) {
  if (invoice.isRentType) return AppColors.deepBlue;
  if (invoice.isUtilityType) return const Color(0xFF0EA5E9);
  return const Color(0xFF64748B);
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatAmount(int amount) {
  final raw = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index += 1) {
    if (index > 0 && (raw.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(raw[index]);
  }
  return '${amount < 0 ? '-' : ''}${buffer.toString()}';
}
