import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/payment/tenant_invoice_model.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_primary_gradient_button.dart';
import '../../widgets/app_screen_shell.dart';
import '../../widgets/app_top_bar.dart';

class QrReceiptPreviewPage extends StatefulWidget {
  const QrReceiptPreviewPage({super.key, required this.invoice});

  final TenantInvoice invoice;

  @override
  State<QrReceiptPreviewPage> createState() => _QrReceiptPreviewPageState();
}

class _QrReceiptPreviewPageState extends State<QrReceiptPreviewPage> {
  bool _saving = false;

  Future<void> _download() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await downloadQrReceipt(context, widget.invoice);
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu ảnh QR thanh toán.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu ảnh QR. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          contentDecoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8F0FF), AppColors.background],
              stops: [0, 0.32],
            ),
          ),
          header: AppTopBar(
            title: 'Mẫu QR thanh toán',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
            children: [
              const Text('Ảnh QR để tải', style: AppTypography.pageTitle),
              const SizedBox(height: 6),
              const Text(
                'Ảnh này giữ nguyên đầy đủ thông tin chuyển khoản để bạn lưu hoặc gửi đi.',
                style: AppTypography.body,
              ),
              const SizedBox(height: 18),
              Center(
                child: FittedBox(
                  child: QrReceiptTemplate(invoice: widget.invoice),
                ),
              ),
              const SizedBox(height: 20),
              AppPrimaryGradientButton(
                onPressed: _saving ? null : _download,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_saving)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      const Icon(Icons.download_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(_saving ? 'Đang tạo ảnh...' : 'Tải ảnh QR'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> downloadQrReceipt(
  BuildContext context,
  TenantInvoice invoice,
) async {
  final overlay = Overlay.of(context);
  final receiptKey = GlobalKey();
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (overlayContext) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: RepaintBoundary(
              key: receiptKey,
              child: Material(
                color: Colors.transparent,
                child: QrReceiptTemplate(invoice: invoice),
              ),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF001734),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppColors.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text(
                        'Đang tạo ảnh QR...',
                        style: TextStyle(
                          color: Color(0xFF10233F),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(entry);
  try {
    final qrValue = invoice.qrCode.trim();
    if (qrValue.startsWith('http://') || qrValue.startsWith('https://')) {
      await precacheImage(NetworkImage(qrValue), context);
    }

    // Chờ 2 frame để widget render hoàn toàn (hoạt động cả debug lẫn release)
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final boundary =
        receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Không tạo được ảnh QR.');
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Không tạo được dữ liệu ảnh QR.');
    }

    final invoiceCode = invoice.invoiceCode
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final fileName = invoiceCode.isEmpty
        ? 'HDBHMS_QR_THANH_TOAN'
        : 'HDBHMS_QR_$invoiceCode';

    final pngBytes = byteData.buffer.asUint8List();

    if (kIsWeb) {
      // Web: kích hoạt tải file về trình duyệt
      final savedPath = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: pngBytes,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );
      return savedPath.isNotEmpty;
    } else {
      // Android / iOS: lưu vào bộ sưu tập ảnh
      await Gal.putImageBytes(pngBytes);
      return true;
    }
  } catch (error, stackTrace) {
    debugPrint('QR receipt download failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  } finally {
    entry.remove();
  }
}

class QrReceiptTemplate extends StatelessWidget {
  const QrReceiptTemplate({super.key, required this.invoice});

  final TenantInvoice invoice;

  static const _primary = AppColors.primary;
  static const _ink = AppColors.inputText;
  static const _surface = AppColors.inputFill;
  static const _border = AppColors.cardBorder;

  @override
  Widget build(BuildContext context) {
    final isRent = invoice.invoiceType.toUpperCase() == 'RENT';
    final typeLabel = isRent
        ? 'THANH TOÁN TIỀN PHÒNG'
        : 'THANH TOÁN TIỀN ĐIỆN & DỊCH VỤ';

    final infoRows = <({String label, String value, bool highlight})>[
      (label: 'Ngân hàng', value: invoice.bankShortName, highlight: false),
      (
        label: 'Số tài khoản',
        value: invoice.displayAccountNumber,
        highlight: false,
      ),
      (label: 'Chủ tài khoản', value: invoice.accountName, highlight: false),
      (
        label: 'Nội dung CK',
        value: invoice.transferDescription,
        highlight: true,
      ),
    ].where((r) => r.value.trim().isNotEmpty).toList();

    return Container(
      width: 390,
      clipBehavior: Clip.none,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── GRADIENT HEADER ───────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF071424),
                  Color(0xFF0F2460),
                  Color(0xFF1D4ED8),
                ],
              ),
            ),
            child: Column(
              children: [
                // Top bar: logo + badge
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusMd,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: _primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HDBHMS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Hệ thống quản lý nhà trọ',
                              style: TextStyle(
                                color: Color(0xA0FFFFFF),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            AppColors.radiusPill,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'PHIẾU QR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Amount block
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      Text(
                        typeLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_formatAmount(invoice.remainingAmount)} VND',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Curved white separator
                Container(
                  height: 22,
                  decoration: const BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── BODY ──────────────────────────────────────────────
          Container(
            color: _surface,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            child: Column(
              children: [
                // QR card with gradient border
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1D4ED8),
                        Color(0xFF6366F1),
                        AppColors.accentViolet,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppColors.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppColors.radiusLg),
                    ),
                    child: Column(
                      children: [
                        // Title row
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              color: _primary,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Quét mã QR để thanh toán',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // QR image with corner brackets
                        SizedBox(
                          width: 182,
                          height: 182,
                          child: Stack(
                            children: [
                              Positioned(
                                top: 0,
                                left: 0,
                                child: _CornerBracket(
                                  corner: _CornerPos.topLeft,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: _CornerBracket(
                                  corner: _CornerPos.topRight,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                child: _CornerBracket(
                                  corner: _CornerPos.bottomLeft,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: _CornerBracket(
                                  corner: _CornerPos.bottomRight,
                                ),
                              ),
                              Center(
                                child: SizedBox(
                                  width: 152,
                                  height: 152,
                                  child: _ReceiptQrImage(
                                    qrCode: invoice.qrCode,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Hint pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.infoSurface,
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusPill,
                            ),
                          ),
                          child: const Text(
                            'Mở app ngân hàng hoặc ví điện tử  →  Quét mã QR',
                            style: TextStyle(
                              color: _primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Info card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppColors.radiusLg),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < infoRows.length; i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Divider(height: 1, color: _border),
                          ),
                        _InfoRow(
                          label: infoRows[i].label,
                          value: infoRows[i].value,
                          highlight: infoRows[i].highlight,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Warning banner
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9EC),
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFD97706),
                        size: 15,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sau khi chuyển khoản thành công, hệ thống sẽ tự động xác nhận.',
                          style: TextStyle(
                            color: AppColors.warningText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Tạo bởi ứng dụng HDBHMS',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Row ────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: highlight
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF0F172A),
                fontSize: highlight ? 11 : 10,
                fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Corner Bracket ─────────────────────────────────────────────
enum _CornerPos { topLeft, topRight, bottomLeft, bottomRight }

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.corner});

  final _CornerPos corner;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _CornerPainter(corner: corner)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.corner});

  final _CornerPos corner;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    const arm = 0.62; // fraction of side used for each arm

    switch (corner) {
      case _CornerPos.topLeft:
        canvas.drawLine(Offset(0, h * arm), const Offset(0, 0), paint);
        canvas.drawLine(const Offset(0, 0), Offset(w * arm, 0), paint);
      case _CornerPos.topRight:
        canvas.drawLine(Offset(w * (1 - arm), 0), Offset(w, 0), paint);
        canvas.drawLine(Offset(w, 0), Offset(w, h * arm), paint);
      case _CornerPos.bottomLeft:
        canvas.drawLine(Offset(0, h * (1 - arm)), Offset(0, h), paint);
        canvas.drawLine(Offset(0, h), Offset(w * arm, h), paint);
      case _CornerPos.bottomRight:
        canvas.drawLine(Offset(w, h * (1 - arm)), Offset(w, h), paint);
        canvas.drawLine(Offset(w, h), Offset(w * (1 - arm), h), paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

class _ReceiptQrImage extends StatelessWidget {
  const _ReceiptQrImage({required this.qrCode});

  final String qrCode;

  @override
  Widget build(BuildContext context) {
    final value = qrCode.trim();
    if (value.isEmpty) return const _QrUnavailable();

    if (_looksLikeImageUrl(value)) {
      return Image.network(
        value,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const _QrUnavailable(),
      );
    }

    final bytes = _decodeQrBytes(value);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const _QrUnavailable(),
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

class _QrUnavailable extends StatelessWidget {
  const _QrUnavailable();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF1F5F9),
      child: Center(
        child: Text(
          'Mã QR chưa sẵn sàng',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Uint8List? _decodeQrBytes(String value) {
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

String _formatAmount(int amount) {
  final raw = amount.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(raw[index]);
  }
  return '${amount < 0 ? '-' : ''}${buffer.toString()}';
}
