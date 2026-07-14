import 'package:flutter/material.dart';

import '../../models/payment/tenant_invoice_model.dart';
import '../home/home_screen.dart';
import 'payment_history_page.dart';

class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage({
    super.key,
    this.invoice,
    this.transactionCode = '#TXN-882910',
    this.completedAt,
  });

  final TenantInvoice? invoice;
  final String transactionCode;
  final DateTime? completedAt;

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _badgeScale;
  late final Animation<double> _haloScale;
  late final Animation<double> _haloOpacity;
  late final Animation<double> _checkProgress;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentOffset;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    _badgeScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.46, curve: Curves.elasticOut),
    );
    _haloScale = Tween<double>(begin: 0.72, end: 1.42).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.62, curve: Curves.easeOutCubic),
      ),
    );
    _haloOpacity = Tween<double>(begin: 0.42, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.68, curve: Curves.easeOut),
      ),
    );
    _checkProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.64, curve: Curves.easeOutCubic),
    );
    _contentOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 1, curve: Curves.easeOut),
    );
    _contentOffset =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.42, 1, curve: Curves.easeOutCubic),
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationStarted) return;
    _animationStarted = true;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _SuccessData.from(
      invoice: widget.invoice,
      transactionCode: widget.transactionCode,
      completedAt: widget.completedAt,
    );
    final theme = _SuccessTheme.fromInvoice(widget.invoice);

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          Positioned.fill(child: _SuccessBackground(theme: theme)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _SuccessHeader(theme: theme)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      sliver: SliverList.list(
                        children: [
                          _AnimatedSuccessHero(
                            theme: theme,
                            badgeScale: _badgeScale,
                            haloScale: _haloScale,
                            haloOpacity: _haloOpacity,
                            checkProgress: _checkProgress,
                          ),
                          const SizedBox(height: 20),
                          FadeTransition(
                            opacity: _contentOpacity,
                            child: SlideTransition(
                              position: _contentOffset,
                              child: Column(
                                children: [
                                  _TransactionCard(data: data, theme: theme),
                                  const SizedBox(height: 16),
                                  _ConfirmationNote(theme: theme),
                                  const SizedBox(height: 20),
                                  _SuccessActions(theme: theme),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader({required this.theme});

  final _SuccessTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(true),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Quay lại',
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xác nhận thanh toán',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Giao dịch đã được ghi nhận an toàn',
                  style: TextStyle(
                    color: Color(0xBFFFFFFF),
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
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: theme.accent, size: 15),
                const SizedBox(width: 5),
                const Text(
                  'Thành công',
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

class _AnimatedSuccessHero extends StatelessWidget {
  const _AnimatedSuccessHero({
    required this.theme,
    required this.badgeScale,
    required this.haloScale,
    required this.haloOpacity,
    required this.checkProgress,
  });

  final _SuccessTheme theme;
  final Animation<double> badgeScale;
  final Animation<double> haloScale;
  final Animation<double> haloOpacity;
  final Animation<double> checkProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 126,
          height: 126,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FadeTransition(
                opacity: haloOpacity,
                child: ScaleTransition(
                  scale: haloScale,
                  child: Container(
                    width: 94,
                    height: 94,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.accent,
                    ),
                  ),
                ),
              ),
              ScaleTransition(
                scale: badgeScale,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [theme.accent, theme.accentEnd],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.54),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.accent.withValues(alpha: 0.42),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: checkProgress,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _CheckPainter(
                          progress: checkProgress.value,
                          color: theme.checkColor,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Thanh toán thành công!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cảm ơn bạn. Khoản thanh toán đã được hệ thống xác nhận.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.76),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final first = Offset(size.width * 0.27, size.height * 0.52);
    final middle = Offset(size.width * 0.44, size.height * 0.68);
    final last = Offset(size.width * 0.74, size.height * 0.35);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final firstLength = (middle - first).distance;
    final secondLength = (last - middle).distance;
    final totalLength = firstLength + secondLength;
    final visibleLength = totalLength * progress.clamp(0.0, 1.0).toDouble();
    final path = Path()..moveTo(first.dx, first.dy);

    if (visibleLength <= firstLength) {
      final point = Offset.lerp(first, middle, visibleLength / firstLength)!;
      path.lineTo(point.dx, point.dy);
    } else {
      path.lineTo(middle.dx, middle.dy);
      final secondProgress = (visibleLength - firstLength) / secondLength;
      final point = Offset.lerp(
        middle,
        last,
        secondProgress.clamp(0.0, 1.0).toDouble(),
      )!;
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.data, required this.theme});

  final _SuccessData data;
  final _SuccessTheme theme;

  @override
  Widget build(BuildContext context) {
    return _LightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.softAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(theme.icon, color: theme.primary, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.paymentTitle,
                      style: TextStyle(
                        color: theme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.invoiceCode,
                      style: TextStyle(
                        color: theme.mutedInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.softAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'ĐÃ THANH TOÁN',
                  style: TextStyle(
                    color: theme.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: theme.softSurface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  'TỔNG TIỀN THANH TOÁN',
                  style: TextStyle(
                    color: theme.mutedInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _formatAmount(data.totalAmount),
                  style: TextStyle(
                    color: theme.ink,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _InfoRow(
            label: 'Mã giao dịch',
            value: data.transactionCode,
            icon: Icons.tag_rounded,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Ngày thanh toán',
            value: _formatDate(data.completedAt),
            icon: Icons.calendar_today_rounded,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Thời gian',
            value: '${_formatTime(data.completedAt)} GMT+7',
            icon: Icons.schedule_rounded,
            theme: theme,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: Color(0xFFE7EAEE)),
          ),
          Text(
            'DANH SÁCH ĐÃ THANH TOÁN',
            style: TextStyle(
              color: theme.mutedInk,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < data.items.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            _PaidItem(item: data.items[index], theme: theme),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.theme,
  });

  final String label;
  final String value;
  final IconData icon;
  final _SuccessTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: theme.primary, size: 19),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: theme.mutedInk,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: theme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaidItem extends StatelessWidget {
  const _PaidItem({required this.item, required this.theme});

  final _PaidItemData item;
  final _SuccessTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.softAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: theme.primary, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.mutedInk,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatAmount(item.amount),
            style: TextStyle(
              color: theme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationNote extends StatelessWidget {
  const _ConfirmationNote({required this.theme});

  final _SuccessTheme theme;

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
          Icon(Icons.notifications_active_outlined, color: theme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Thông báo xác nhận đã được gửi đến chủ trọ và quản lý. Bạn có thể xem lại giao dịch trong lịch sử thanh toán.',
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

class _SuccessActions extends StatelessWidget {
  const _SuccessActions({required this.theme});

  final _SuccessTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PaymentHistoryPage(),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: theme.checkColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Xem lịch sử thanh toán'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Quay lại trang chủ'),
          ),
        ),
      ],
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
        color: const Color(0xFFFDFEFF).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF071426).withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SuccessBackground extends StatelessWidget {
  const _SuccessBackground({required this.theme});

  final _SuccessTheme theme;

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
            top: -100,
            right: -80,
            child: _GlowOrb(color: theme.accent, size: 240),
          ),
          Positioned(
            top: 390,
            left: -110,
            child: _GlowOrb(color: theme.secondary, size: 260),
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
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _SuccessData {
  const _SuccessData({
    required this.transactionCode,
    required this.invoiceCode,
    required this.paymentTitle,
    required this.totalAmount,
    required this.completedAt,
    required this.items,
  });

  final String transactionCode;
  final String invoiceCode;
  final String paymentTitle;
  final int totalAmount;
  final DateTime completedAt;
  final List<_PaidItemData> items;

  factory _SuccessData.from({
    required TenantInvoice? invoice,
    required String transactionCode,
    required DateTime? completedAt,
  }) {
    if (invoice == null) {
      return _SuccessData(
        transactionCode: transactionCode,
        invoiceCode: 'Hóa đơn tiện ích tháng 12/2025',
        paymentTitle: 'Điện nước & dịch vụ',
        totalAmount: 800000,
        completedAt: completedAt ?? DateTime(2025, 12, 22, 14, 32, 5),
        items: const [
          _PaidItemData(
            icon: Icons.flash_on_rounded,
            title: 'Điện',
            subtitle: 'Đã sử dụng: 215 kWh',
            amount: 700000,
          ),
          _PaidItemData(
            icon: Icons.water_drop_rounded,
            title: 'Nước',
            subtitle: 'Đã sử dụng: 5 m³',
            amount: 100000,
          ),
        ],
      );
    }

    final items = invoice.lines.isEmpty
        ? [
            _PaidItemData(
              icon: _invoiceIcon(invoice.invoiceType),
              title: invoice.title,
              subtitle: invoice.roomCode.isEmpty
                  ? invoice.billingPeriod
                  : 'Phòng ${invoice.roomCode}',
              amount: invoice.totalAmount,
            ),
          ]
        : invoice.lines
              .map(
                (line) => _PaidItemData(
                  icon: _lineIcon(line.lineType),
                  title: _lineTitle(line),
                  subtitle: _lineSubtitle(line),
                  amount: line.amount,
                ),
              )
              .toList();

    final rawTransactionCode = invoice.providerOrderCode.isNotEmpty
        ? invoice.providerOrderCode
        : invoice.paymentLinkId.isNotEmpty
        ? invoice.paymentLinkId
        : transactionCode;

    return _SuccessData(
      transactionCode: rawTransactionCode.startsWith('#')
          ? rawTransactionCode
          : '#$rawTransactionCode',
      invoiceCode: invoice.invoiceCode.isEmpty
          ? 'Hóa đơn ${invoice.billingPeriod}'
          : 'Mã hóa đơn: ${invoice.invoiceCode}',
      paymentTitle: invoice.invoiceType.toUpperCase() == 'RENT'
          ? 'Tiền phòng'
          : 'Điện nước & dịch vụ',
      totalAmount: invoice.totalAmount,
      completedAt: completedAt ?? invoice.paidAt ?? DateTime.now().toLocal(),
      items: items,
    );
  }
}

class _PaidItemData {
  const _PaidItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int amount;
}

class _SuccessTheme {
  const _SuccessTheme({
    required this.icon,
    required this.background,
    required this.backgroundEnd,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.accentEnd,
    required this.checkColor,
    required this.ink,
    required this.mutedInk,
    required this.softAccent,
    required this.softSurface,
  });

  final IconData icon;
  final Color background;
  final Color backgroundEnd;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color accentEnd;
  final Color checkColor;
  final Color ink;
  final Color mutedInk;
  final Color softAccent;
  final Color softSurface;

  factory _SuccessTheme.fromInvoice(TenantInvoice? invoice) {
    final isRent = invoice?.invoiceType.toUpperCase() == 'RENT';
    if (isRent) {
      return const _SuccessTheme(
        icon: Icons.apartment_rounded,
        background: Color(0xFF081426),
        backgroundEnd: Color(0xFF172A4B),
        primary: Color(0xFF173B6C),
        secondary: Color(0xFF8B5CF6),
        accent: Color(0xFFFBBF24),
        accentEnd: Color(0xFFFDE68A),
        checkColor: Color(0xFF352100),
        ink: Color(0xFF10233F),
        mutedInk: Color(0xFF607089),
        softAccent: Color(0xFFFFF6D8),
        softSurface: Color(0xFFF5F7FB),
      );
    }
    return const _SuccessTheme(
      icon: Icons.bolt_rounded,
      background: Color(0xFF061827),
      backgroundEnd: Color(0xFF12345C),
      primary: Color(0xFF1D4ED8),
      secondary: Color(0xFF60A5FA),
      accent: Color(0xFF93C5FD),
      accentEnd: Color(0xFFDBEAFE),
      checkColor: Color(0xFF061827),
      ink: Color(0xFF10233F),
      mutedInk: Color(0xFF607089),
      softAccent: Color(0xFFE0F2FE),
      softSurface: Color(0xFFF5F7FB),
    );
  }
}

IconData _invoiceIcon(String invoiceType) {
  return invoiceType.toUpperCase() == 'RENT'
      ? Icons.apartment_rounded
      : Icons.receipt_long_rounded;
}

IconData _lineIcon(String type) {
  return switch (type.toUpperCase()) {
    'RENT' => Icons.apartment_rounded,
    'ELECTRICITY' => Icons.flash_on_rounded,
    'WATER' => Icons.water_drop_rounded,
    'VIOLATION_FINE' => Icons.gavel_rounded,
    'MAINTENANCE_COMPENSATION' => Icons.handyman_rounded,
    _ => Icons.receipt_long_rounded,
  };
}

String _lineTitle(TenantInvoiceLine line) {
  return switch (line.lineType.toUpperCase()) {
    'RENT' => 'Tiền phòng',
    'ELECTRICITY' => 'Điện',
    'WATER' => 'Nước',
    'VIOLATION_FINE' => 'Phạt vi phạm nội quy',
    'MAINTENANCE_COMPENSATION' => 'Bồi thường bảo trì',
    _ => line.description.isEmpty ? 'Khoản thanh toán' : line.description,
  };
}

String _lineSubtitle(TenantInvoiceLine line) {
  final utilityQuantity = _lineUtilityQuantity(line);
  if (utilityQuantity != null) return 'Số lượng: $utilityQuantity';
  if (line.description.isNotEmpty) return line.description;
  if (line.quantity > 0) return 'Số lượng: ${line.quantity}';
  return '';
}

String? _lineUtilityQuantity(TenantInvoiceLine line) {
  final unit = switch (line.lineType.toUpperCase()) {
    'ELECTRICITY' => 'kWh',
    'WATER' => 'm³',
    _ => null,
  };
  if (unit == null) return null;
  final amount =
      line.usageAmount ?? (line.quantity > 0 ? line.quantity.toDouble() : null);
  if (amount == null) return null;
  return '${_formatReading(amount)} $unit';
}

String _formatReading(double value) {
  return value.truncateToDouble() == value
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
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
  return '${amount < 0 ? '-' : ''}${buffer.toString()} đ';
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _formatTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';
}
