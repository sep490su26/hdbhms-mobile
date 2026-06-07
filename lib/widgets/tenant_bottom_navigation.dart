import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum TenantBottomNavTab { home, bills, support, profile, logout }

class TenantBottomNavigation extends StatelessWidget {
  const TenantBottomNavigation({
    super.key,
    required this.activeTab,
    this.onHomeTap,
    this.onSupportTap,
    this.onBillsTap,
    this.onProfileTap,
    this.onLogoutTap,
  });

  final TenantBottomNavTab activeTab;
  final VoidCallback? onHomeTap;
  final VoidCallback? onSupportTap;
  final VoidCallback? onBillsTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Container(
          height: 74,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: AppColors.cardBorder.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                icon: Icons.home_rounded,
                label: 'Trang chủ',
                isSelected: activeTab == TenantBottomNavTab.home,
                onTap: onHomeTap,
              ),
              _BottomNavItem(
                icon: Icons.receipt_long_outlined,
                label: 'Hóa đơn',
                isSelected: activeTab == TenantBottomNavTab.bills,
                onTap: onBillsTap,
              ),
              _BottomNavItem(
                icon: Icons.support_agent_outlined,
                label: 'Hỗ trợ',
                isSelected: activeTab == TenantBottomNavTab.support,
                onTap: onSupportTap,
              ),
              _BottomNavItem(
                icon: Icons.person_outline,
                label: 'Hồ sơ',
                isSelected: activeTab == TenantBottomNavTab.profile,
                onTap: onProfileTap,
              ),
              _BottomNavItem(
                icon: Icons.logout_rounded,
                label: 'Đăng xuất',
                isSelected: activeTab == TenantBottomNavTab.logout,
                onTap: onLogoutTap,
                isDestructive: true,
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
    required this.isSelected,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final Color activeColor =
        isDestructive ? const Color(0xFFDC2626) : AppColors.deepBlue;
    final Color inactiveColor =
        isDestructive ? const Color(0xFFDC2626).withValues(alpha: 0.6) : AppColors.bodyText;
    final Color activeBg =
        isDestructive ? const Color(0xFFFFD8D5) : const Color(0xFFA7B4FF);

    final color = isSelected ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 62,
        child: isSelected
            ? Container(
                height: 50,
                decoration: BoxDecoration(
                  color: activeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: activeColor, size: 21),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 14 / 10,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 14 / 10,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
