// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/contract/deposit_contract_list_screen.dart';
import 'package:hdbhms_mobile/screens/contract/lease_contract_list_screen.dart';
import 'package:hdbhms_mobile/screens/auth/login_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';

/// Màn hub "Hợp Đồng" – chứa 2 tab: HĐ thuê + HĐ cọc.
class ContractHubScreen extends StatefulWidget {
  const ContractHubScreen({
    super.key,
    this.initialTab = 0,
    this.roomId,
    this.roomCode,
  });

  /// 0 = HĐ thuê, 1 = HĐ cọc
  final int initialTab;
  final int? roomId;
  final String? roomCode;

  @override
  State<ContractHubScreen> createState() => _ContractHubScreenState();
}

class _ContractHubScreenState extends State<ContractHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await const AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: _buildHeader(),
          child: Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _LeaseContractTab(
                      roomId: widget.roomId,
                      roomCode: widget.roomCode,
                    ),
                    _DepositContractTab(
                      roomId: widget.roomId,
                      roomCode: widget.roomCode,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.home,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onBillsTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const BillSelectionPage()),
          );
        },
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
          MaterialPageRoute(builder: (context) => const TenantRequestScreen()),
        ),
      ),
    );
  }

  Widget _buildLegacyHeader() {
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
            child: Text('Hợp đồng', style: AppColors.topBarTitleStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AppTopBar(
      title: 'Hợp đồng',
      onBack: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.bodyText,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          gradient: const LinearGradient(
            colors: [AppColors.deepBlue, AppColors.primary],
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(
            icon: Icon(Icons.description_outlined, size: 18),
            text: 'HĐ thuê',
          ),
          Tab(
            icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
            text: 'HĐ cọc',
          ),
        ],
      ),
    );
  }
}

/// Tab HĐ thuê – nhúng nội dung LeaseContractListScreen ở chế độ embedded.
class _LeaseContractTab extends StatelessWidget {
  const _LeaseContractTab({this.roomId, this.roomCode});

  final int? roomId;
  final String? roomCode;

  @override
  Widget build(BuildContext context) {
    return LeaseContractListScreen(
      embeddedMode: true,
      roomId: roomId,
      roomCode: roomCode,
    );
  }
}

/// Tab HĐ cọc – nhúng nội dung DepositContractListScreen ở chế độ embedded.
class _DepositContractTab extends StatelessWidget {
  const _DepositContractTab({this.roomId, this.roomCode});

  final int? roomId;
  final String? roomCode;

  @override
  Widget build(BuildContext context) {
    return DepositContractListScreen(
      embeddedMode: true,
      roomId: roomId,
      roomCode: roomCode,
    );
  }
}
