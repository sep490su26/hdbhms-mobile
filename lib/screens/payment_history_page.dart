import 'package:flutter/material.dart';
import 'notification_list_screen.dart';

import '../theme/app_colors.dart';
import 'tenant_profile_screen.dart';

class PaymentHistoryPage extends StatelessWidget {
  const PaymentHistoryPage({super.key});

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
                const _HistoryHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 22, 14, 22),
                    child: Column(
                      children: const [
                        _SearchField(),
                        SizedBox(height: 16),
                        _FilterRow(),
                        SizedBox(height: 24),
                        _HistoryListCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _HistoryBottomNavigation(),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.fromLTRB(4, 0, 15, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder.withValues(alpha: 0.65),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Quay lại',
          ),
          const Expanded(
            child: Text(
              'Lịch sử thanh toán',
              style: TextStyle(
                color: AppColors.deepBlue,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 20 / 16,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            padding: EdgeInsets.zero,
constraints: const BoxConstraints.tightFor(width: 36, height: 36),
icon: const Icon(
Icons.notifications_none_rounded,
              color: AppColors.inputText,
              size: 24,
            ),
            tooltip: 'Thông báo',
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Row(
        children: [
          SizedBox(width: 14),
          Icon(Icons.search_rounded, color: AppColors.bodyText, size: 21),
          SizedBox(width: 12),
          Text(
            'T\u00ECm ki\u1EBFm..',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 22 / 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Th\u00E1ng 2 2023',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 22 / 17,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.deepBlue,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          height: 45,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_rounded, size: 18),
            label: const Text('L\u1ECDc'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA7B4FF),
              foregroundColor: AppColors.deepBlue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 20 / 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryListCard extends StatelessWidget {
  const _HistoryListCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        children: [
          _HistoryItem(
            icon: Icons.receipt_long_outlined,
            title: 'Ti\u1EC1n ph\u00F2ng',
            date: 'Th\u00E1ng 01/02/2023',
            amount: '2.220.000',
          ),
          _HistoryDivider(),
          _HistoryItem(
            icon: Icons.flash_on_outlined,
            title: '\u0110i\u1EC7n & N\u01B0\u1EDBc',
            date: 'Th\u00E1ng 01/02/2023',
            amount: '800.000',
          ),
          _HistoryDivider(),
          _HistoryItem(
            icon: Icons.construction_rounded,
            title: 'S\u1EEDa t\u1EE7 l\u1EA1nh',
            date: 'Th\u00E1ng 15/02/2023',
            amount: '400.000',
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({
    required this.icon,
    required this.title,
    required this.date,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String date;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 16, 19),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFFEDEFFF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.deepBlue, size: 25),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 22 / 17,
                  ),
                ),
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 20 / 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 24 / 20,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7FBE4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '\u0110\u00C3 THANH TO\u00C1N',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 13 / 10,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryDivider extends StatelessWidget {
  const _HistoryDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFFE9E9EF));
  }
}

class _HistoryBottomNavigation extends StatelessWidget {
  const _HistoryBottomNavigation();

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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
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
              _BottomNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TenantProfileScreen(),
                    ),
                  );
                },
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
