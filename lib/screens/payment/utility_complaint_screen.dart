import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

import '../../models/payment/tenant_invoice_model.dart';
import '../../services/payment/tenant_invoice_service.dart';
import '../../widgets/app_top_bar.dart';

/// Màn hình khiếu nại chỉ số điện – full-screen thay bottom sheet cũ.
class UtilityComplaintScreen extends StatefulWidget {
  const UtilityComplaintScreen({
    super.key,
    required this.invoice,
    required this.invoiceService,
  });

  final TenantInvoice invoice;
  final TenantInvoiceService invoiceService;

  @override
  State<UtilityComplaintScreen> createState() => _UtilityComplaintScreenState();
}

class _UtilityComplaintScreenState extends State<UtilityComplaintScreen> {
  late final List<TenantInvoiceLine> _lines;
  TenantInvoiceLine? _selectedLine;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _detailController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _lines = widget.invoice.reviewableUtilityLines
        .where((line) => line.lineType == 'ELECTRICITY')
        .toList(growable: false);
    _selectedLine = _lines.isEmpty ? null : _lines.first;
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  String _formatReading(double? value) {
    if (value == null) return '--';
    final asInt = value.truncateToDouble() == value;
    return asInt ? value.toInt().toString() : value.toStringAsFixed(2);
  }

  String _formatAmount(int amount) {
    final raw = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write('.');
      buffer.write(raw[i]);
    }
    final result = buffer.toString();
    return '${amount < 0 ? '-' : ''}$resultđ';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _snack('Vui lòng hoàn thành các trường bắt buộc');
      return;
    }
    final invoiceId = widget.invoice.id;
    final selectedLine = _selectedLine;
    final lineId = selectedLine?.id;
    if (invoiceId == null || lineId == null) {
      _snack('Dữ liệu hóa đơn không hợp lệ. Vui lòng thử lại.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.invoiceService.submitMeterReadingReview(
        invoiceId: invoiceId,
        lineId: lineId,
        reportedCurrentValue: selectedLine?.currentValue ?? 0,
        description: _detailController.text.trim(),
      );
      if (!mounted) return;
      _snack(
        'Đã gửi khiếu nại. Theo dõi tiến trình tại màn Yêu cầu; kết quả sẽ được gửi qua thông báo.',
      );
      Navigator.of(context).pop(true);
    } on TenantInvoiceException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gửi khiếu nại thất bại. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F0FF), AppColors.background],
            stops: [0, 0.28],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            // ── Light background with small top stripe ───────
            children: [
              // ── App bar ──────────────────────────────────
              AppTopBar(
                title: 'Khiếu nại tiền điện',
                onBack: _submitting
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),

              // ── Content ──────────────────────────────────
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      24 + bottomInset + MediaQuery.paddingOf(context).bottom,
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _lines.isEmpty
                        ? const _NoElectricityLineState()
                        : Form(
                            key: _formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Hero card
                                _HeroCard(invoice: widget.invoice),
                                const SizedBox(height: 16),

                                // Form card
                                _FormCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Room number (read-only)
                                      const _FieldLabel('Số phòng'),
                                      const SizedBox(height: 6),
                                      _ReadOnlyField(
                                        value: widget.invoice.roomCode.isEmpty
                                            ? 'Chưa có thông tin phòng'
                                            : 'Phòng ${widget.invoice.roomCode}',
                                        icon: Icons.apartment_rounded,
                                      ),
                                      const SizedBox(height: 16),

                                      const _ElectricityComplaintSummary(),
                                      const SizedBox(height: 16),

                                      // Reading snapshot
                                      _ReadingSnapshotCard(
                                        line: _selectedLine!,
                                        formatReading: _formatReading,
                                        formatAmount: _formatAmount,
                                      ),
                                      const SizedBox(height: 16),

                                      // Detail content
                                      const _FieldLabel(
                                        'Nội dung chi tiết khiếu nại',
                                        required: true,
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _detailController,
                                        enabled: !_submitting,
                                        minLines: 4,
                                        maxLines: 7,
                                        textInputAction:
                                            TextInputAction.newline,
                                        validator: (v) {
                                          if (v == null ||
                                              v.trim().length < 10) {
                                            return 'Vui lòng mô tả rõ hơn (ít nhất 10 ký tự)';
                                          }
                                          return null;
                                        },
                                        decoration: _fieldDecoration(
                                          hintText:
                                              'Mô tả chi tiết lý do khiếu nại, ví dụ: chỉ số trên đồng hồ thực tế thấp hơn số trong hóa đơn...',
                                          prefixIcon: null,
                                        ).copyWith(alignLabelWithHint: true),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Info note
                                const _InfoNote(),
                                const SizedBox(height: 24),

                                // Submit button
                                _SubmitButton(
                                  submitting: _submitting,
                                  onPressed: _submit,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Background
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// App bar
// ─────────────────────────────────────────────────────────────

// ignore: unused_element
class _ComplaintAppBar extends StatelessWidget {
  const _ComplaintAppBar({required this.submitting});
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: submitting
                ? null
                : () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Quay lại',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Khiếu nại tiền điện',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Yêu cầu xem xét lại chỉ số',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hero card
// ─────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.invoice});
  final TenantInvoice invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepBlue, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF451A03),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  invoice.invoiceCode.isEmpty
                      ? 'Phòng ${invoice.roomCode}'
                      : '${invoice.invoiceCode} · Phòng ${invoice.roomCode}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTotalAmount(invoice.totalAmount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Tổng cộng',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTotalAmount(int amount) {
    final raw = amount.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buf.write('.');
      buf.write(raw[i]);
    }
    final s = buf.toString();
    return '$sđ';
  }
}

// ─────────────────────────────────────────────────────────────
// Form card wrapper
// ─────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Field label
// ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: required ? '$text, bắt buộc' : text,
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.danger),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Read-only field
// ─────────────────────────────────────────────────────────────

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value, required this.icon});
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.bodyText, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.hintText,
            size: 16,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reading snapshot card
// ─────────────────────────────────────────────────────────────

class _ReadingSnapshotCard extends StatelessWidget {
  const _ReadingSnapshotCard({
    required this.line,
    required this.formatReading,
    required this.formatAmount,
  });

  final TenantInvoiceLine line;
  final String Function(double?) formatReading;
  final String Function(int) formatAmount;

  @override
  Widget build(BuildContext context) {
    final isElec = line.lineType == 'ELECTRICITY';
    final accentColor = isElec ? AppColors.warning : const Color(0xFF0EA5E9);
    final bgColor = isElec ? AppColors.warningSurface : AppColors.infoSurface;
    final unit = isElec ? 'kWh' : 'm³';
    String withUnit(double? value) {
      if (value == null) return '--';
      return '${formatReading(value)} $unit';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isElec ? Icons.bolt_rounded : Icons.water_drop_rounded,
                color: accentColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Thông tin chỉ số ${isElec ? 'điện' : 'nước'}',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SnapshotRow(label: 'Chỉ số cũ', value: withUnit(line.previousValue)),
          const SizedBox(height: 6),
          _SnapshotRow(
            label: 'Chỉ số trong hóa đơn',
            value: withUnit(line.currentValue),
            highlight: true,
          ),
          const SizedBox(height: 6),
          _SnapshotRow(
            label: 'Sản lượng tính tiền',
            value: withUnit(line.usageAmount),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          _SnapshotRow(
            label: 'Thành tiền',
            value: formatAmount(line.amount),
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight
                ? AppColors.danger
                : bold
                ? AppColors.inputText
                : AppColors.inputText,
            fontSize: 13,
            fontWeight: bold || highlight ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Info note
// ─────────────────────────────────────────────────────────────

class _InfoNote extends StatelessWidget {
  const _InfoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Khiếu nại sẽ được gửi đến quản lý để xem xét. Khi có kết quả xử lý, hệ thống sẽ gửi thông báo cho bạn.',
              style: TextStyle(
                color: Color(0xFF0C4A6E),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Submit button
// ─────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.submitting, required this.onPressed});
  final bool submitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.deepBlue, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: FilledButton.icon(
        onPressed: submitting ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        icon: submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, size: 20),
        label: Text(submitting ? 'Đang gửi...' : 'GỬI KHIẾU NẠI'),
      ),
    );
  }
}

class _NoElectricityLineState extends StatelessWidget {
  const _NoElectricityLineState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 56),
    child: Column(
      children: [
        Icon(Icons.bolt_outlined, color: AppColors.bodyText, size: 40),
        SizedBox(height: 12),
        Text(
          'Không có chỉ số điện để khiếu nại',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.inputText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Chỉ số nước vẫn được hiển thị trong hóa đơn nhưng không hỗ trợ khiếu nại.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.bodyText, fontSize: 13),
        ),
      ],
    ),
  );
}

class _ElectricityComplaintSummary extends StatelessWidget {
  const _ElectricityComplaintSummary();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warningSurface,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      border: Border.all(color: AppColors.warning.withValues(alpha: .3)),
    ),
    child: const Row(
      children: [
        Icon(Icons.bolt_rounded, color: AppColors.warning, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Khiếu nại tiền điện',
                style: TextStyle(
                  color: AppColors.warningText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Kiểm tra chỉ số điện của hóa đơn này',
                style: TextStyle(color: AppColors.bodyText, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Input decoration helper
// ─────────────────────────────────────────────────────────────

InputDecoration _fieldDecoration({String? hintText, IconData? prefixIcon}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppColors.radiusSm),
    borderSide: const BorderSide(color: AppColors.cardBorder),
  );
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: Colors.white,
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, color: AppColors.bodyText, size: 20)
        : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.deepBlue, width: 1.5),
    ),
    errorBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
    ),
    hintStyle: const TextStyle(
      color: AppColors.hintText,
      fontSize: 13,
      fontWeight: FontWeight.w400,
    ),
  );
}
