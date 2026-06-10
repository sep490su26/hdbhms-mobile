import 'package:flutter/material.dart';
import 'notification_list_screen.dart';
import 'tenant_request_screen.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/tenant_bottom_navigation.dart';
import 'login_page.dart';
import 'maintenance_ticket_list_screen.dart';
import 'payment_history_page.dart';
import 'qr_payment_page.dart';
import 'tenant_profile_screen.dart';

class BillSelectionPage extends StatefulWidget {
  const BillSelectionPage({super.key});

  @override
  State<BillSelectionPage> createState() => _BillSelectionPageState();
}

class _BillSelectionPageState extends State<BillSelectionPage> {
  _BillFilter _activeFilter = _BillFilter.all;

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
                        _BillSectionHeader(
                          onHistoryTap: () => _openPaymentHistory(context),
                        ),
                        const SizedBox(height: 14),
                        _BillFilterBar(
                          active: _activeFilter,
                          onChanged: (filter) {
                            setState(() => _activeFilter = filter);
                          },
                        ),
                        const SizedBox(height: 18),
                        ..._buildFilteredBills(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.bills,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onBillsTap: () {},
        onSupportTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const MaintenanceTicketListScreen(),
            ),
          );
        },
        onProfileTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const TenantProfileScreen(),
            ),
          );
        },
        onRequestsTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TenantRequestScreen(),
              ),
            ),
      ),
    );
  }

  void _openPayment(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const QrPaymentPage()));
  }

  void _openPaymentHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PaymentHistoryPage(),
      ),
    );
  }

  List<Widget> _buildFilteredBills(BuildContext context) {
    final pendingBills = [
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
    ];

    const paidBills = [
      _PaidBillCard(
        title: 'Tiền phòng',
        amount: '2.200.000',
        date: 'Ngày: 15/12/2022',
      ),
      SizedBox(height: 12),
      _PaidBillCard(
        title: 'Điện & Nước',
        amount: '800.000',
        date: 'Ngày: 15/12/2022',
      ),
    ];

    return switch (_activeFilter) {
      _BillFilter.all => [
          ...pendingBills,
          const SizedBox(height: 28),
          const _PaidDivider(),
          const SizedBox(height: 22),
          ...paidBills,
        ],
      _BillFilter.unpaid => pendingBills,
      _BillFilter.paid => paidBills,
    };
  }
}

enum _BillFilter { all, unpaid, paid }

class _BillSectionHeader extends StatelessWidget {
  const _BillSectionHeader({required this.onHistoryTap});

  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Tất cả hoá đơn',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 30 / 24,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _HistoryShortcutButton(onTap: onHistoryTap),
      ],
    );
  }
}

class _HistoryShortcutButton extends StatelessWidget {
  const _HistoryShortcutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.deepBlue,
        backgroundColor: AppColors.deepBlue.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.history_rounded, size: 17),
      label: const Text(
        'Lịch sử',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          height: 16 / 12,
        ),
      ),
    );
  }
}

class _BillFilterBar extends StatelessWidget {
  const _BillFilterBar({
    required this.active,
    required this.onChanged,
  });

  final _BillFilter active;
  final ValueChanged<_BillFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _BillFilterChip(
            label: 'Tất cả',
            icon: Icons.list_rounded,
            isActive: active == _BillFilter.all,
            onTap: () => onChanged(_BillFilter.all),
          ),
          const SizedBox(width: 8),
          _BillFilterChip(
            label: 'Chưa thanh toán',
            icon: Icons.pending_actions_rounded,
            isActive: active == _BillFilter.unpaid,
            onTap: () => onChanged(_BillFilter.unpaid),
          ),
          const SizedBox(width: 8),
          _BillFilterChip(
            label: 'Đã thanh toán',
            icon: Icons.task_alt_rounded,
            isActive: active == _BillFilter.paid,
            onTap: () => onChanged(_BillFilter.paid),
          ),
        ],
      ),
    );
  }
}

class _BillFilterChip extends StatelessWidget {
  const _BillFilterChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.deepBlue.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? AppColors.deepBlue
                : AppColors.cardBorder.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? AppColors.deepBlue : AppColors.bodyText,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.deepBlue : AppColors.bodyText,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillHeader extends StatelessWidget {
  const _BillHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppColors.topBarHeight,
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
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text(
              'Hóa đơn',
              style: AppColors.topBarTitleStyle,
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
              color: AppColors.topBarIconColor,
              size: 24,
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

