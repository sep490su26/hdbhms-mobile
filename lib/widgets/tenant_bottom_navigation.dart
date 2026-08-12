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
          height: 76,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlue.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.home_rounded,
                  label: 'Trang chủ',
                  isSelected: activeTab == TenantBottomNavTab.home,
                  onTap: onHomeTap,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Hóa đơn',
                  isSelected: activeTab == TenantBottomNavTab.bills,
                  onTap: onBillsTap,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.handyman_outlined,
                  label: 'Sự cố',
                  isSelected: activeTab == TenantBottomNavTab.support,
                  onTap: onSupportTap,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.assignment_outlined,
                  label: 'Yêu cầu',
                  isSelected: activeTab == TenantBottomNavTab.requests,
                  onTap: onRequestsTap,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.person_outline,
                  label: 'Hồ sơ',
                  isSelected: activeTab == TenantBottomNavTab.profile,
                  onTap: onProfileTap,
                ),
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
    final color = isSelected ? activeColor : inactiveColor;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.deepBlue, AppColors.primary],
                      )
                    : null,
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : color,
                    size: isSelected ? 22 : 21,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
                      height: 13 / 10,
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
