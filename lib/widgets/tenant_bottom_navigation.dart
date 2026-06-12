import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

enum TenantBottomNavTab { home, bills, support, requests, profile }

class TenantBottomNavigation extends StatelessWidget {
  const TenantBottomNavigation({
    super.key,
    required this.activeTab,
    this.onHomeTap,
    this.onSupportTap,
    this.onBillsTap,
    this.onRequestsTap,
    this.onProfileTap,
  });

  final TenantBottomNavTab activeTab;
  final VoidCallback? onHomeTap;
  final VoidCallback? onSupportTap;
  final VoidCallback? onBillsTap;
  final VoidCallback? onRequestsTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Container(
          height: 74,
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
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
                icon: Icons.assignment_outlined,
                label: 'Yêu cầu',
                isSelected: activeTab == TenantBottomNavTab.requests,
                onTap: onRequestsTap,
              ),
              _BottomNavItem(
                icon: Icons.person_outline,
                label: 'Hồ sơ',
                isSelected: activeTab == TenantBottomNavTab.profile,
                onTap: onProfileTap,
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
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.deepBlue;
    const inactiveColor = AppColors.bodyText;
    const activeBg = Color(0xFFA7B4FF);

    final color = isSelected ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 58,
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
                    Icon(icon, color: activeColor, size: 20),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: activeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 13 / 9,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 21),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 13 / 9,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
