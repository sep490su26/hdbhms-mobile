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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          height: 78,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 7),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.inputText.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
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
                icon: Icons.handyman_outlined,
                label: 'Sự cố',
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
    const activeColor = AppColors.primary;
    const inactiveColor = AppColors.bodyText;
    const activeBg = AppColors.primaryLight;

    final color = isSelected ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 62,
        child: isSelected
            ? Container(
                height: 54,
                decoration: BoxDecoration(
                  color: activeBg,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: activeColor, size: 21),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: activeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 13 / 10,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 13 / 10,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
