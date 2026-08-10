import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/payment/tenant_invoice_model.dart';
import '../../services/notification/notification_service.dart';
import '../../services/payment/tenant_invoice_service.dart';
import '../../widgets/app_top_bar.dart';
import 'payment_success_page.dart';
import 'qr_receipt_download_page.dart';

class QrPaymentPage extends StatefulWidget {
  const QrPaymentPage({
    super.key,
    required this.invoice,
    this.invoiceService = const TenantInvoiceService(),
    this.pollInterval = const Duration(seconds: 4),
    this.onPaymentConfirmed,
  });

  final TenantInvoice invoice;
  final TenantInvoiceService invoiceService;
  final Duration pollInterval;
  final Future<void> Function()? onPaymentConfirmed;

  @override
  State<QrPaymentPage> createState() => _QrPaymentPageState();
}

class _QrPaymentPageState extends State<QrPaymentPage> {
  late TenantInvoice _invoice;
  Timer? _pollTimer;
  bool _checking = false;
  bool _completed = false;
  bool _downloadingQr = false;
  final NotificationService _notificationService = const NotificationService();

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    unawaited(_markInvoiceNotificationsRead());
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

  Future<void> _markInvoiceNotificationsRead() async {
    final invoiceId = _invoice.id;
    if (invoiceId == null || invoiceId <= 0) return;
    try {
      await _notificationService.markTargetAsRead(
        targetType: 'INVOICE',
        targetId: invoiceId,
      );
    } catch (_) {
      // Best-effort read sync; payment flow should not be blocked.
    }
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
          try {
            await widget.onPaymentConfirmed?.call();
          } catch (_) {
            // Payment success must still be shown even if the caller refresh fails.
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Thanh toán đã được xác nhận.')),
            );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PaymentSuccessPage(
                invoice: updated,
                invoiceService: widget.invoiceService,
              ),
            ),
            result: true,
          );
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

  Future<void> _downloadQr() async {
    if (_downloadingQr) return;
    setState(() => _downloadingQr = true);
    try {
      final saved = await downloadQrReceipt(context, _invoice);
      if (!mounted || !saved) return;
      final msg = kIsWeb
          ? 'Đã tải ảnh QR về máy.'
          : 'Đã lưu ảnh QR vào bộ sưu tập.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Không thể tải ảnh QR. Vui lòng thử lại.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _downloadingQr = false);
    }
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(
              title: theme.title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _DecoratedBackground(theme: theme)),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            sliver: SliverList.list(
                              children: [
                                _PaymentHero(invoice: _invoice, theme: theme),
                                const SizedBox(height: 18),
                                _QrCard(
                                  qrCode: _invoice.qrCode,
                                  theme: theme,
                                  downloading: _downloadingQr,
                                  onDownload: _downloadQr,
                                ),
                                if (fields.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  _InformationCard(
                                    fields: fields,
                                    theme: theme,
                                  ),
                                ],
                                const SizedBox(height: 18),
                                _SecurityNote(theme: theme),
                                const SizedBox(height: 20),
                                _ConfirmButton(
                                  theme: theme,
                                  checking: _checking,
                                  onPressed: () => _checkPaymentStatus(
                                    showPendingMessage: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  theme.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepBlue, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.deepBlue),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: theme.accent,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              boxShadow: [
                BoxShadow(
                  color: theme.accent.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
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
                    letterSpacing: 0,
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
  const _QrCard({
    required this.qrCode,
    required this.theme,
    required this.downloading,
    required this.onDownload,
  });

  final String qrCode;
  final _PaymentVisualTheme theme;
  final bool downloading;
  final VoidCallback onDownload;

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
                'Quét mã QR',
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
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: theme.primary, size: 16),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Tự động đối soát sau khi chuyển khoản',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: downloading ? null : onDownload,
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: theme.primary.withValues(alpha: 0.55),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              icon: downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(downloading ? 'Đang tải ảnh...' : 'Tải ảnh QR'),
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
    if (_looksLikeImageUrl(value)) {
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
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: InkWell(
          onTap: () => _copyValue(context, field.value),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.softAccent,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder),
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
                color: AppColors.bodyText,
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
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.deepBlue, AppColors.primary],
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        child: FilledButton.icon(
          onPressed: checking ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: theme.iconColor,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: theme.iconColor.withValues(alpha: 0.75),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder),
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
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F0FF), AppColors.background],
          stops: [0, 0.3],
        ),
      ),
    );
  }
}

// ignore: unused_element
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
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
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
        background: AppColors.background,
        backgroundEnd: AppColors.background,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        accent: AppColors.primary,
        iconColor: Colors.white,
        ink: AppColors.inputText,
        mutedInk: AppColors.bodyText,
        softAccent: AppColors.primaryLight,
        softSurface: AppColors.inputFill,
      );
    }
    return const _PaymentVisualTheme(
      title: 'Thanh toán tiền điện & dịch vụ',
      subtitle: 'Chi phí tiện ích trong kỳ',
      icon: Icons.bolt_rounded,
      background: AppColors.background,
      backgroundEnd: AppColors.background,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      accent: AppColors.primary,
      iconColor: Colors.white,
      ink: AppColors.inputText,
      mutedInk: AppColors.bodyText,
      softAccent: AppColors.primaryLight,
      softSurface: AppColors.inputFill,
    );
  }
}

Uint8List? _decodeQrBytes(String value) {
  if (value.isEmpty) return null;
  final normalized = value.trim();
  final hasDataImagePrefix = normalized.toLowerCase().startsWith('data:image/');
  final looksLikeBase64Image =
      normalized.startsWith('iVBOR') ||
      normalized.startsWith('/9j/') ||
      normalized.startsWith('UklGR');
  if (!hasDataImagePrefix && !looksLikeBase64Image) return null;

  try {
    final encoded = hasDataImagePrefix
        ? normalized.substring(normalized.indexOf(',') + 1)
        : normalized;
    final bytes = base64Decode(encoded);
    return _looksLikeImage(bytes) ? bytes : null;
  } on FormatException {
    return null;
  }
}

bool _looksLikeImageUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  final path = uri.path.toLowerCase();
  return path.endsWith('.png') ||
      path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.webp');
}

bool _looksLikeImage(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true;
  }
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return true;
  }
  return bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
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
