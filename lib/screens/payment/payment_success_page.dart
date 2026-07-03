import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/screens/home/home_screen.dart';
import 'package:hdbhms_mobile/screens/payment/payment_history_page.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({
    super.key,
    this.invoiceService = const TenantInvoiceService(),
  });

  final TenantInvoiceService invoiceService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                const _SuccessHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 34, 14, 18),
                    child: Column(
                      children: [
                        const _SuccessHero(),
                        const SizedBox(height: 18),
                        const _TransactionDetailCard(),
                        const SizedBox(height: 28),
                        _SuccessActions(invoiceService: invoiceService),
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

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppColors.topBarHeight,
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
            child: Text('Thanh to\u00E1n', style: AppColors.topBarTitleStyle),
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

class _SuccessHero extends StatelessWidget {
  const _SuccessHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: const BoxDecoration(
            color: Color(0xFF16A34A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 22),
        const Text(
          'Thanh to\u00E1n th\u00E0nh c\u00F4ng!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.deepBlue,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            height: 30 / 23,
          ),
        ),
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            'Th\u00F4ng b\u00E1o \u0111\u00E3 \u0111\u01B0\u1EE3c g\u1EEDi \u0111\u1EBFn ch\u1EE7 tr\u1ECD v\u00E0\nqu\u1EA3n l\u00FD.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 22 / 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionDetailCard extends StatelessWidget {
  const _TransactionDetailCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: const [
          _TransactionHeader(),
          Divider(height: 1, color: Color(0xFFE1E3EC)),
          _TransactionTotal(),
          _TransactionDateTime(),
          _PaidBillList(),
        ],
      ),
    );
  }
}

class _TransactionHeader extends StatelessWidget {
  const _TransactionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'CHI TI\u1EBET GIAO D\u1ECACH',
              style: TextStyle(
                color: AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 16 / 12,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEDEFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '#TXN-882910',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 16 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTotal extends StatelessWidget {
  const _TransactionTotal();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 28, 24, 30),
      child: Column(
        children: [
          Text(
            'T\u1ED4NG TI\u1EC0N THANH TO\u00C1N',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 16 / 12,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '800.000 \u0111',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 31,
              fontWeight: FontWeight.w900,
              height: 38 / 31,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionDateTime extends StatelessWidget {
  const _TransactionDateTime();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
      child: Column(
        children: const [
          Divider(height: 1, color: Color(0xFFE8E8EF)),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _DateTimeColumn(label: 'NG\u00C0Y', value: '22/12/2025'),
              ),
              Expanded(
                child: _DateTimeColumn(
                  label: 'GI\u1EDC',
                  value: '14:32:05 GMT+7',
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateTimeColumn extends StatelessWidget {
  const _DateTimeColumn({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 16 / 12,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }
}

class _PaidBillList extends StatelessWidget {
  const _PaidBillList();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DANH S\u00C1CH \u0110\u00C3 THANH TO\u00C1N',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 16 / 12,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 14),
          _PaidBillItem(
            icon: Icons.flash_on_outlined,
            title: '\u0110i\u1EC7n',
            subtitle: '\u0110\u00E3 s\u1EED d\u1EE5ng: 215 kWh',
            amount: '700.000 \u0111',
          ),
          SizedBox(height: 14),
          _PaidBillItem(
            icon: Icons.water_drop_outlined,
            title: 'N\u01B0\u1EDBc',
            subtitle: '\u0110\u00E3 s\u1EED d\u1EE5ng: 5',
            amount: '100.000 \u0111',
          ),
        ],
      ),
    );
  }
}

class _PaidBillItem extends StatelessWidget {
  const _PaidBillItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2F2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4F63D9), size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 18 / 14,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 18 / 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessActions extends StatelessWidget {
  const _SuccessActions({required this.invoiceService});

  final TenantInvoiceService invoiceService;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      PaymentHistoryPage(invoiceService: invoiceService),
                ),
              );
            },
            icon: const Icon(Icons.history_rounded, size: 21),
            label: const Text('Xem l\u1ECBch s\u1EED'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF252A91),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 20 / 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.home_outlined, size: 21),
            label: const Text('Quay l\u1EA1i trang ch\u1EE7'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepBlue,
              side: const BorderSide(color: AppColors.deepBlue, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 20 / 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
