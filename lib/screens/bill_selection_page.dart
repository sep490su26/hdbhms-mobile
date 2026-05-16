import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'payment_history_page.dart';
import 'qr_payment_page.dart';

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
                    padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hóa đơn',
                          style: TextStyle(
                            color: AppColors.deepBlue,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 30 / 24,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _PendingBillCard(
                          title: 'Tiền phòng',
                          amount: '2.200.000',
                          dueDate: 'Hạn: 15/01/2023',
                          onTap: () => _openPayment(context),
                        ),
                        const SizedBox(height: 16),
                        _PendingBillCard(
                          title: 'Điện & Nước',
                          amount: '800.000',
                          dueDate: 'Hạn: 15/01/2023',
                          onTap: () => _openPayment(context),
                        ),
                        const SizedBox(height: 28),
                        const _PaidDivider(),
                        const SizedBox(height: 22),
                        const _PaidBillCard(
                          title: 'Tiền phòng',
                          amount: '2.200.000',
                          date: 'Ngày: 15/12/2022',
                        ),
                        const SizedBox(height: 12),
                        const _PaidBillCard(
                          title: 'Điện & Nước',
                          amount: '800.000',
                          date: 'Ngày: 15/12/2022',
                        ),
                        const SizedBox(height: 18),
                        _ViewHistoryButton(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PaymentHistoryPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _BillBottomNavigation(),
    );
  }

  void _openPayment(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const QrPaymentPage()));
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
              'Nhà Trọ Hải Đăng',
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
            tooltip: 'Thông báo',
          ),
        ],
      ),
    );
  }
}

class _PendingBillCard extends StatelessWidget {
  const _PendingBillCard({
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.onTap,
  });

  final String title;
  final String amount;
  final String dueDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 98),
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
                      padding: const EdgeInsets.fromLTRB(22, 18, 18, 16),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 20 / 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                amount,
                                style: const TextStyle(
                                  color: AppColors.deepBlue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  height: 21 / 16,
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
                                  'CHỜ THANH TOÁN',
                                  style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    height: 14 / 10,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  dueDate,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.bodyText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    height: 15 / 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Icon(
                                Icons.apartment_rounded,
                                color: AppColors.bodyText,
                                size: 14,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Phòng 302',
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaidDivider extends StatelessWidget {
  const _PaidDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFD7D7E0), height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'HÓA ĐƠN ĐÃ THANH TOÁN',
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
  const _PaidBillCard({
    required this.title,
    required this.amount,
    required this.date,
  });

  final String title;
  final String amount;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.48,
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.fromLTRB(22, 16, 18, 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: Color(0xFF8096FF))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.inputText,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 20 / 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        amount,
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 20 / 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
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
                          'ĐÃ THANH TOÁN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 12 / 9,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          date,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 15 / 11,
                          ),
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
    );
  }
}

class _ViewHistoryButton extends StatelessWidget {
  const _ViewHistoryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF1EFEF),
          foregroundColor: AppColors.deepBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        ),
        child: const Text(
          'View All Historical Data',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 18 / 13,
          ),
        ),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BottomNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              const _BottomNavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Bills',
                isSelected: true,
              ),
              const _BottomNavItem(
                icon: Icons.support_agent_outlined,
                label: 'Support',
              ),
              const _BottomNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
              ),
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.deepBlue : AppColors.bodyText;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFA7B4FF)
                    : Colors.transparent,
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
      ),
    );
  }
}
