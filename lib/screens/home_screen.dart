import 'package:flutter/material.dart';

import 'bill_selection_page.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                const _HomeHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Greeting(),
                        SizedBox(height: 14),
                        _PaymentSummaryCard(),
                        SizedBox(height: 16),
                        _SectionHeading('\u0110i\u1EC7n & N\u01B0\u1EDBc'),
                        SizedBox(height: 12),
                        _UtilityReadingCard(
                          icon: Icons.flash_on_outlined,
                          iconColor: Color(0xFFE6A200),
                          iconBackground: Color(0xFFFFF8E7),
                          title: '\u0110i\u1EC7n',
                          value: '245 kWh',
                          change: '-2.4% v\u1EDBi th\u00E1ng tr\u01B0\u1EDBc',
                          changeColor: Color(0xFF16A34A),
                        ),
                        SizedBox(height: 10),
                        _UtilityReadingCard(
                          icon: Icons.water_drop_outlined,
                          iconColor: Color(0xFF2563EB),
                          iconBackground: Color(0xFFEFF6FF),
                          title: 'N\u01B0\u1EDBc',
                          value: '12.5 m\u00B3',
                          change: '+1.2% v\u1EDBi th\u00E1ng tr\u01B0\u1EDBc',
                          changeColor: Color(0xFFDC2626),
                        ),
                        SizedBox(height: 18),
                        _SectionHeading('Thao t\u00E1c nhanh'),
                        SizedBox(height: 12),
                        _QuickActions(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _HomeBottomNavigation(),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

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
          const Icon(Icons.menu_rounded, color: AppColors.deepBlue, size: 24),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nh\u00E0 tr\u1ECD H\u1EA3i \u0110\u0103ng',
                  style: TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 18 / 15,
                  ),
                ),
                SizedBox(height: 1),
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
          const SizedBox(width: 7),
          const _UserAvatar(),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF0F172A)],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 19),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'XIN CH\u00C0O,',
          style: TextStyle(
            color: AppColors.deepBlue,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 16 / 12,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Nguy\u1EC5n V\u0103n A',
          style: TextStyle(
            color: AppColors.inputText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 28 / 24,
          ),
        ),
      ],
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Tr\u1EA1ng th\u00E1i thanh to\u00E1n',
                  style: TextStyle(
                    color: AppColors.inputText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 20 / 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDFBE8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Ch\u01B0a thanh to\u00E1n',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 15 / 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'H\u1EA1n: 01/01/2023',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 18 / 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    '2.200.000',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 36 / 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text(
                  '/ th\u00E1ng',
                  style: TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 18 / 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BillSelectionPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Thanh to\u00E1n ngay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 20 / 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.inputText,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        height: 24 / 19,
      ),
    );
  }
}

class _UtilityReadingCard extends StatelessWidget {
  const _UtilityReadingCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.value,
    required this.change,
    required this.changeColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String value;
  final String change;
  final Color changeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7E7EF)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 78,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 22 / 17,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    change,
                    maxLines: 1,
                    style: TextStyle(
                      color: changeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 15 / 11,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '\u0110ang \u0111\u1ECDc',
                  style: TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
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

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.warning_amber_rounded,
            label: 'B\u00E1o c\u00E1o s\u1EF1 c\u1ED1',
          ),
        ),
        SizedBox(width: 6),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.description_outlined,
            label: 'Xem h\u1EE3p \u0111\u1ED3ng',
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.deepBlue, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 16 / 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBottomNavigation extends StatelessWidget {
  const _HomeBottomNavigation();

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
            border: Border(
              top: BorderSide(
                color: AppColors.cardBorder.withValues(alpha: 0.7),
              ),
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
              const _BottomNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: true,
              ),
              _BottomNavItem(
                icon: Icons.receipt_long_outlined,
                label: 'Bills',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const BillSelectionPage(),
                    ),
                  );
                },
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
