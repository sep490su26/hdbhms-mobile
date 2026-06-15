import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/payment/tenant_invoice_model.dart';
import '../../services/payment/tenant_invoice_service.dart';

class QrPaymentPage extends StatefulWidget {
  const QrPaymentPage({
    super.key,
    required this.invoice,
    this.invoiceService = const TenantInvoiceService(),
    this.pollInterval = const Duration(seconds: 4),
  });

  final TenantInvoice invoice;
  final TenantInvoiceService invoiceService;
  final Duration pollInterval;

  @override
  State<QrPaymentPage> createState() => _QrPaymentPageState();
}

class _QrPaymentPageState extends State<QrPaymentPage> {
  late TenantInvoice _invoice;
  Timer? _pollTimer;
  bool _checking = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    if (_invoice.isPaid) return;
    _pollTimer = Timer.periodic(widget.pollInterval, (_) {
      _checkPaymentStatus(showPendingMessage: false);
    });
  }

  Future<void> _checkPaymentStatus({required bool showPendingMessage}) async {
    if (_checking || _completed) return;
    setState(() => _checking = true);
    try {
      final invoices = await widget.invoiceService.fetchMyInvoices();
      final updated = _findUpdatedInvoice(invoices);
      if (!mounted) return;
      if (updated != null) {
        setState(() => _invoice = updated);
        if (updated.isPaid) {
          _completed = true;
          _pollTimer?.cancel();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Thanh toán đã được xác nhận.')),
            );
          Navigator.of(context).pop(true);
          return;
        }
      }
      if (showPendingMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Chưa ghi nhận thanh toán. Hệ thống sẽ tiếp tục tự động kiểm tra.',
              ),
            ),
          );
      }
    } catch (_) {
      if (!mounted) return;
      if (showPendingMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Không kiểm tra được trạng thái. Vui lòng thử lại.',
              ),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  TenantInvoice? _findUpdatedInvoice(List<TenantInvoice> invoices) {
    for (final candidate in invoices) {
      if (_invoice.id != null && candidate.id == _invoice.id) {
        return candidate;
      }
      if (_invoice.paymentIntentId != null &&
          candidate.paymentIntentId == _invoice.paymentIntentId) {
        return candidate;
      }
      if (_invoice.providerOrderCode.isNotEmpty &&
          candidate.providerOrderCode == _invoice.providerOrderCode) {
        return candidate;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = _PaymentVisualTheme.fromInvoice(_invoice);
    final fields = <({String label, String value, IconData icon})>[
      (
        label: 'Ngân hàng',
        value: _invoice.bankShortName,
        icon: Icons.account_balance_rounded,
      ),
      (
        label: 'Số tài khoản',
        value: _invoice.displayAccountNumber,
        icon: Icons.credit_card_rounded,
      ),
      (
        label: 'Chủ tài khoản',
        value: _invoice.accountName,
        icon: Icons.person_outline_rounded,
      ),
      (
        label: 'Số tiền',
        value: '${_formatAmount(_invoice.remainingAmount)} VND',
        icon: Icons.payments_outlined,
      ),
      (
        label: 'Nội dung chuyển khoản',
        value: _invoice.transferDescription,
        icon: Icons.notes_rounded,
      ),
    ].where((field) => field.value.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          Positioned.fill(child: _DecoratedBackground(theme: theme)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _Header(theme: theme)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      sliver: SliverList.list(
                        children: [
                          _PaymentHero(invoice: _invoice, theme: theme),
                          const SizedBox(height: 18),
                          _QrCard(qrCode: _invoice.qrCode, theme: theme),
                          if (fields.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _InformationCard(fields: fields, theme: theme),
                          ],
                          const SizedBox(height: 18),
                          _SecurityNote(theme: theme),
                          const SizedBox(height: 20),
                          _ConfirmButton(
                            theme: theme,
                            checking: _checking,
                            onPressed: () =>
                                _checkPaymentStatus(showPendingMessage: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final _PaymentVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Quay lại',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thanh toán an toàn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  theme.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, color: Colors.white, size: 14),
                SizedBox(width: 5),
                Text(
                  'Bảo mật',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _PaymentHero extends StatelessWidget {
  const _PaymentHero({required this.invoice, required this.theme});

  final TenantInvoice invoice;
  final _PaymentVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: theme.accent,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(theme.icon, color: theme.iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  theme.title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatAmount(invoice.remainingAmount)}đ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                if (invoice.invoiceCode.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Mã hóa đơn: ${invoice.invoiceCode}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.qrCode, required this.theme});

  final String qrCode;
  final _PaymentVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return _LightCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: theme.primary),
              const SizedBox(width: 8),
              Text(
                'Quét mã VietQR',
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mở ứng dụng ngân hàng và quét mã bên dưới',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.mutedInk, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth.clamp(210.0, 256.0).toDouble();
              return RepaintBoundary(
                child: Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.primary.withValues(alpha: 0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withValues(alpha: 0.12),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _QrImage(qrCode: qrCode, theme: theme),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.softAccent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, color: theme.primary, size: 16),
                const SizedBox(width: 5),
                Text(
                  'Tự động đối soát sau khi chuyển khoản',
                  style: TextStyle(
                    color: theme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _QrImage extends StatelessWidget {
  const _QrImage({required this.qrCode, required this.theme});

  final String qrCode;
  final _PaymentVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    final value = qrCode.trim();
    if (value.isEmpty) {
      return _QrFallback(theme: theme);
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _QrFallback(theme: theme),
      );
    }
    final bytes = _decodeQrBytes(value);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _QrFallback(theme: theme),
      );
    }

    return QrImageView(
      data: value,
      backgroundColor: Colors.white,
      padding: EdgeInsets.zero,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
  }
}

class _QrFallback extends StatelessWidget {
  const _QrFallback({required this.theme});

  final _PaymentVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: theme.softAccent,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_rounded, color: theme.primary, size: 92),
            const SizedBox(height: 8),
            Text(
              'Mã QR chưa sẵn sàng',
              style: TextStyle(
                color: theme.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.fields, required this.theme});

  final List<({String label, String value, IconData icon})> fields;
  final _PaymentVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return _LightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thông tin chuyển khoản',
            style: TextStyle(
              color: theme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nhấn biểu tượng sao chép để tránh nhập sai.',
            style: TextStyle(color: theme.mutedInk, fontSize: 12),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < fields.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            _CopyableField(field: fields[index], theme: theme),
          ],
        ],
      ),
    );
  }
}

class _CopyableField extends StatelessWidget {
  const _CopyableField({required this.field, required this.theme});

  final ({String label, String value, IconData icon}) field;
  final _PaymentVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${field.label}: ${field.value}. Nhấn để sao chép.',
      button: true,
      child: Material(
        color: theme.softSurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _copyValue(context, field.value),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.softAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(field.icon, color: theme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.label,
                        style: TextStyle(
                          color: theme.mutedInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      SelectableText(
                        field.value,
                        style: TextStyle(
                          color: theme.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _copyValue(context, field.value),
                  icon: Icon(
                    Icons.copy_rounded,
                    color: theme.primary,
                    size: 20,
                  ),
                  tooltip: 'Sao chép ${field.label}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.theme});

  final _PaymentVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: theme.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Vui lòng chuyển đúng số tiền và nội dung. Không chia sẻ mã OTP hoặc mật khẩu ngân hàng.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.theme,
    required this.checking,
    required this.onPressed,
  });

  final _PaymentVisualTheme theme;
  final bool checking;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: checking ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.accent,
          foregroundColor: theme.iconColor,
          disabledBackgroundColor: theme.accent.withValues(alpha: 0.55),
          disabledForegroundColor: theme.iconColor.withValues(alpha: 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        icon: checking
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.iconColor,
                ),
              )
            : const Icon(Icons.refresh_rounded),
        label: Text(checking ? 'Đang kiểm tra...' : 'Tôi đã chuyển khoản'),
      ),
    );
  }
}

class _LightCard extends StatelessWidget {
  const _LightCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFF).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF071426).withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DecoratedBackground extends StatelessWidget {
  const _DecoratedBackground({required this.theme});

  final _PaymentVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.background, theme.backgroundEnd],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _GlowOrb(color: theme.accent, size: 220),
          ),
          Positioned(
            top: 330,
            left: -100,
            child: _GlowOrb(color: theme.secondary, size: 240),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _PaymentVisualTheme {
  const _PaymentVisualTheme({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.backgroundEnd,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.iconColor,
    required this.ink,
    required this.mutedInk,
    required this.softAccent,
    required this.softSurface,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color backgroundEnd;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color iconColor;
  final Color ink;
  final Color mutedInk;
  final Color softAccent;
  final Color softSurface;

  factory _PaymentVisualTheme.fromInvoice(TenantInvoice invoice) {
    final isRent = invoice.invoiceType.toUpperCase() == 'RENT';
    if (isRent) {
      return const _PaymentVisualTheme(
        title: 'Thanh toán tiền phòng',
        subtitle: 'Khoản thuê phòng định kỳ',
        icon: Icons.apartment_rounded,
        background: Color(0xFF081426),
        backgroundEnd: Color(0xFF172A4B),
        primary: Color(0xFF173B6C),
        secondary: Color(0xFF8B5CF6),
        accent: Color(0xFFFBBF24),
        iconColor: Color(0xFF352100),
        ink: Color(0xFF10233F),
        mutedInk: Color(0xFF607089),
        softAccent: Color(0xFFFFF6D8),
        softSurface: Color(0xFFF5F7FB),
      );
    }
    return const _PaymentVisualTheme(
      title: 'Thanh toán điện nước & dịch vụ',
      subtitle: 'Chi phí tiện ích trong kỳ',
      icon: Icons.bolt_rounded,
      background: Color(0xFF073B4C),
      backgroundEnd: Color(0xFF075E63),
      primary: Color(0xFF087F8C),
      secondary: Color(0xFF22D3EE),
      accent: Color(0xFF5EEAD4),
      iconColor: Color(0xFF073B4C),
      ink: Color(0xFF103A43),
      mutedInk: Color(0xFF5F747A),
      softAccent: Color(0xFFDDFBF6),
      softSurface: Color(0xFFF1F9F8),
    );
  }
}

Uint8List? _decodeQrBytes(String value) {
  if (value.isEmpty) return null;
  try {
    final encoded = value.startsWith('data:image/')
        ? value.substring(value.indexOf(',') + 1)
        : value;
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}

Future<void> _copyValue(BuildContext context, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép thông tin'),
        duration: Duration(seconds: 2),
      ),
    );
}

String _formatAmount(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return amount < 0 ? '-$buffer' : buffer.toString();
}
