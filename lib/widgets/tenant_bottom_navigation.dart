import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum TenantBottomNavTab { home, support, bills, profile }

class TenantBottomNavigation extends StatelessWidget {
  const TenantBottomNavigation({
    super.key,
    required this.activeTab,
    this.onHomeTap,
    this.onSupportTap,
    this.onBillsTap,
    this.onProfileTap,
  });

  final TenantBottomNavTab activeTab;
  final VoidCallback? onHomeTap;
  final VoidCallback? onSupportTap;
  final VoidCallback? onBillsTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Container(
          height: 74,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: activeTab == TenantBottomNavTab.home,
                onTap: onHomeTap,
              ),
              _BottomNavItem(
                icon: Icons.support_agent_outlined,
                label: 'Support',
                isSelected: activeTab == TenantBottomNavTab.support,
                onTap: onSupportTap,
              ),
              _BottomNavItem(
                icon: Icons.receipt_long_outlined,
                label: 'Bills',
                isSelected: activeTab == TenantBottomNavTab.bills,
                onTap: onBillsTap,
              ),
              _BottomNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
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
    final color = isSelected ? AppColors.deepBlue : AppColors.bodyText;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: isSelected
            ? Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFA7B4FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 21),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        height: 14 / 12,
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
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 14 / 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
