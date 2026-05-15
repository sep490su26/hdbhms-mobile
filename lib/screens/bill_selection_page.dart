import 'package:flutter/material.dart';

import 'qr_payment_page.dart';
import '../theme/app_colors.dart';

class BillSelectionPage extends StatelessWidget {
  const BillSelectionPage({super.key});

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
                const _BillHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 22, 14, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Ch\u1ECDn h\u00F3a \u0111\u01A1n',
                          style: TextStyle(
                            color: AppColors.deepBlue,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 30 / 24,
                          ),
                        ),
                        SizedBox(height: 26),
                        _BillToolbar(),
                        SizedBox(height: 14),
                        _SelectableBillCard(
                          title: 'Ti\u1EC1n ph\u00F2ng',
                          amount: '2.200.000',
                          dueDate: 'H\u1EA1n: 15/01/2023',
                          isSelected: true,
                        ),
                        SizedBox(height: 16),
                        _SelectableBillCard(
                          title: '\u0110i\u1EC7n & N\u01B0\u1EDBc',
                          amount: '800.000',
                          dueDate: 'H\u1EA1n: 15/01/2023',
                        ),
                        SizedBox(height: 34),
                        _PaidDivider(),
                        SizedBox(height: 28),
                        _PaidBillCard(),
                      ],
                    ),
                  ),
                ),
                const _PaymentSummaryBar(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _BillBottomNavigation(),
    );
  }
}

class _BillHeader extends StatelessWidget {
  const _BillHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
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
          const Icon(Icons.menu_rounded, color: AppColors.deepBlue, size: 24),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Nh\u00E0 Tr\u1ECD H\u1EA3i \u0110\u0103ng',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 18 / 14,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.inputText,
              size: 23,
            ),
            tooltip: 'Th\u00F4ng b\u00E1o',
          ),
        ],
      ),
    );
  }
}

class _BillToolbar extends StatelessWidget {
  const _BillToolbar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_box_rounded,
          color: AppColors.deepBlue,
          size: 22,
        ),
        const SizedBox(width: 12),
        const Text(
          'SELECT ALL PENDING',
          style: TextStyle(
            color: AppColors.deepBlue,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 15 / 11,
            letterSpacing: 0.7,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            foregroundColor: AppColors.deepBlue,
            padding: EdgeInsets.zero,
            minimumSize: const Size(34, 24),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'L\u1ECC C',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 15 / 11,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectableBillCard extends StatelessWidget {
  const _SelectableBillCard({
    required this.title,
    required this.amount,
    required this.dueDate,
    this.isSelected = false,
  });

  final String title;
  final String amount;
  final String dueDate;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 122),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 3,
              decoration: const BoxDecoration(
                color: AppColors.deepBlue,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 20, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: AppColors.deepBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    color: AppColors.inputText,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    height: 22 / 17,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                amount,
                                style: const TextStyle(
                                  color: AppColors.deepBlue,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  height: 22 / 17,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD6D6),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'CH\u1EDC THANH TO\u00C1N',
                                  style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    height: 14 / 10,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  dueDate,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.bodyText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 16 / 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Icon(
                                Icons.apartment_rounded,
                                color: AppColors.bodyText,
                                size: 15,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Ph\u00F2ng 302',
                                style: TextStyle(
                                  color: AppColors.bodyText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 16 / 12,
                                ),
                              ),
                            ],
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
    );
  }
}

class _PaidDivider extends StatelessWidget {
  const _PaidDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: Color(0xFFD7D7E0), height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'PAID LAST MONTH',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 14 / 10,
              letterSpacing: 0.9,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFD7D7E0), height: 1)),
      ],
    );
  }
}

class _PaidBillCard extends StatelessWidget {
  const _PaidBillCard();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.42,
      child: Container(
        height: 116,
        padding: const EdgeInsets.fromLTRB(22, 22, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF8096FF)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Expanded(
                        child: Text(
                          'Ti\u1EC1n ph\u00F2ng',
                          style: TextStyle(
                            color: AppColors.inputText,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 22 / 17,
                          ),
                        ),
                      ),
                      Text(
                        '2.200.000',
                        style: TextStyle(
                          color: AppColors.inputText,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 22 / 17,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8096FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '\u0110\u00C3 THANH TO\u00C1N',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 14 / 10,
                        letterSpacing: 0.4,
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

class _PaymentSummaryBar extends StatelessWidget {
  const _PaymentSummaryBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.45)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'T\u1ED4NG (1)',
                  style: TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 14 / 11,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '2.200.000',
                  style: TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 28 / 23,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 126,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const QrPaymentPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: AppColors.deepBlue.withValues(alpha: 0.28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Text(
                'Thanh to\u00E1n',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillBottomNavigation extends StatelessWidget {
  const _BillBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.7),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BottomNavItem(icon: Icons.home_outlined, label: 'Home'),
              _BottomNavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Bills',
                isSelected: true,
              ),
              _BottomNavItem(
                icon: Icons.support_agent_outlined,
                label: 'Support',
              ),
              _BottomNavItem(icon: Icons.person_outline, label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.deepBlue : AppColors.bodyText;

    return SizedBox(
      width: 62,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 28,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFA7B4FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              height: 14 / 11,
            ),
          ),
        ],
      ),
    );
  }
}
