import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

class InvoiceTotalSummary extends StatelessWidget {
  const InvoiceTotalSummary({super.key, required this.invoice});

  final TenantInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = invoice.discountAmount > 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.infoSurface, Color(0xFFF0FDF4)],
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Column(
        children: [
          if (hasDiscount) ...[
            _SummaryRow(
              label: 'Tạm tính',
              value: _formatAmount(invoice.resolvedSubtotalAmount),
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Giảm giá',
              value: '-${_formatAmount(invoice.discountAmount)}',
              valueColor: AppColors.successText,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
          ],
          _SummaryRow(
            label: 'Tổng cộng',
            value: _formatAmount(invoice.totalAmount),
            emphasized: true,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Đã thanh toán',
            value: _formatAmount(invoice.paidAmount),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Còn phải trả',
            value: _formatAmount(invoice.remainingAmount),
            valueColor: AppColors.primary,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.inputText,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: emphasized ? 13 : 12,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: valueColor,
          fontSize: emphasized ? 16 : 13,
          fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    ],
  );
}

String _formatAmount(int amount) {
  final raw = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write('.');
    buffer.write(raw[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer đ';
}
