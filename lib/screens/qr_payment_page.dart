import 'package:flutter/material.dart';
import 'notification_list_screen.dart';

import 'payment_success_page.dart';
import '../theme/app_colors.dart';

class QrPaymentPage extends StatelessWidget {
  const QrPaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                const _QrHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                    child: Column(
                      children: const [
                        _TotalPaymentCard(),
                        SizedBox(height: 18),
                        _QrMethodCard(),
                        SizedBox(height: 14),
                        _TransferContentCard(),
                        SizedBox(height: 14),
                        _BankInfoCard(),
                        SizedBox(height: 22),
                        _PaidButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QrHeader extends StatelessWidget {
  const _QrHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 38),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Quay l\u1EA1i',
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Thanh to\u00E1n h\u00F3a \u0111\u01A1n',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 26 / 20,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Th\u00F4ng b\u00E1o',
          ),
        ],
      ),
    );
  }
}

class _TotalPaymentCard extends StatelessWidget {
  const _TotalPaymentCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'T\u1ED4NG THANH TO\u00C1N',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 18 / 13,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '2.450.000\u0111',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 35,
              fontWeight: FontWeight.w900,
              height: 42 / 35,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 284),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EF),
                border: Border.all(color: const Color(0xFFFFB5AE)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFFDC2626),
                      size: 17,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'H\u1EBFt h\u1EA1n trong 14:59',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 18 / 14,
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

class _QrMethodCard extends StatelessWidget {
  const _QrMethodCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: const [
          _PaymentTabs(),
          SizedBox(height: 24),
          _QrDecorationRow(),
          SizedBox(height: 16),
          _QrFrame(),
          SizedBox(height: 16),
          _DownloadQrButton(),
          SizedBox(height: 18),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'Chuy\u1EC3n kho\u1EA3n \u0111\u00FAng s\u1ED1 ti\u1EC1n v\u00E0 n\u1ED9i dung\nb\u00EAn d\u01B0\u1EDBi \u0111\u1EC3 h\u1EC7 th\u1ED1ng t\u1EF1 \u0111\u1ED9ng ghi nh\u1EADn',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inputText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 22 / 14,
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PaymentTabs extends StatelessWidget {
  const _PaymentTabs();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _PaymentTab(label: 'VietQR', isSelected: true)),
        Expanded(child: _PaymentTab(label: 'MoMo')),
        Expanded(child: _PaymentTab(label: 'ZaloPay')),
      ],
    );
  }
}

class _PaymentTab extends StatelessWidget {
  const _PaymentTab({required this.label, this.isSelected = false});

  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.surface : const Color(0xFFFBFBFD),
        border: Border(
          bottom: BorderSide(
            color: isSelected ? AppColors.deepBlue : const Color(0xFFE8E8EF),
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.deepBlue : AppColors.inputText,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 18 / 13,
          ),
        ),
      ),
    );
  }
}

class _QrDecorationRow extends StatelessWidget {
  const _QrDecorationRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 38),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [_MiniQrImage(), _MiniQrImage()],
      ),
    );
  }
}

class _MiniQrImage extends StatelessWidget {
  const _MiniQrImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF64748B), Color(0xFF0F172A)],
        ),
      ),
      child: const Icon(
        Icons.landscape_outlined,
        color: Colors.white,
        size: 12,
      ),
    );
  }
}

class _QrFrame extends StatelessWidget {
  const _QrFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      height: 244,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDADCEB), width: 2),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(8),
              color: const Color(0xFFF1F4F9),
              child: CustomPaint(painter: _QrPlaceholderPainter()),
            ),
          ),
          const Positioned(top: 0, left: 0, child: _CornerMark()),
          const Positioned(top: 0, right: 0, child: _CornerMark(turns: 1)),
          const Positioned(bottom: 0, right: 0, child: _CornerMark(turns: 2)),
          const Positioned(bottom: 0, left: 0, child: _CornerMark(turns: 3)),
          Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppColors.deepBlue,
                size: 29,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerMark extends StatelessWidget {
  const _CornerMark({this.turns = 0});

  final int turns;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: turns,
      child: CustomPaint(size: const Size(38, 38), painter: _CornerPainter()),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.deepBlue
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset.zero, Offset(size.width * 0.62, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height * 0.62), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QrPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFC5CADF);
    final cell = size.width / 9;
    const filled = <int>{
      10,
      11,
      12,
      14,
      15,
      16,
      19,
      21,
      23,
      25,
      28,
      29,
      32,
      34,
      38,
      40,
      41,
      43,
      47,
      49,
      50,
      52,
      55,
      57,
      59,
      61,
      64,
      65,
      66,
      68,
      70,
    };

    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        final index = row * 9 + col;
        if (!filled.contains(index)) continue;
        canvas.drawRect(
          Rect.fromLTWH(col * cell, row * cell, cell * 0.82, cell * 0.82),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DownloadQrButton extends StatelessWidget {
  const _DownloadQrButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('T\u1EA3i m\u00E3 QR'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepBlue,
        side: const BorderSide(color: Color(0xFFD3D8F2), width: 2),
        minimumSize: const Size(140, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _TransferContentCard extends StatelessWidget {
  const _TransferContentCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'N\u1ED9i dung chuy\u1EC3n kho\u1EA3n',
                  style: TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 16 / 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'RESIDENT_99283_JULY',
                  style: TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 22 / 17,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.copy_rounded, color: AppColors.deepBlue),
            tooltip: 'Sao ch\u00E9p',
          ),
        ],
      ),
    );
  }
}

class _BankInfoCard extends StatelessWidget {
  const _BankInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        children: [
          _BankInfoRow(label: 'Ng\u00E2n h\u00E0ng', value: 'Agribank'),
          SizedBox(height: 16),
          _BankInfoRow(
            label: 'S\u1ED1 t\u00E0i kho\u1EA3n',
            value: '3213888869999',
            canCopy: true,
          ),
          SizedBox(height: 16),
          _BankInfoRow(
            label: 'Ch\u1EE7 t\u00E0i kho\u1EA3n',
            value: '\u0110\u1EB7ng V\u0103n Nhu\u1EADn',
          ),
        ],
      ),
    );
  }
}

class _BankInfoRow extends StatelessWidget {
  const _BankInfoRow({
    required this.label,
    required this.value,
    this.canCopy = false,
  });

  final String label;
  final String value;
  final bool canCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 18 / 13,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 18 / 13,
            ),
          ),
        ),
        if (canCopy) ...[
          const SizedBox(width: 6),
          const Icon(Icons.copy_rounded, color: AppColors.deepBlue, size: 18),
        ],
      ],
    );
  }
}

class _PaidButton extends StatelessWidget {
  const _PaidButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PaymentSuccessPage()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'T\u00F4i \u0111\u00E3 thanh to\u00E1n',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 24 / 18,
          ),
        ),
      ),
    );
  }
}
