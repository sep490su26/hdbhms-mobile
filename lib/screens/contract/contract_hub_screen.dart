import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/contract/lease_contract_list_screen.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';

/// Compatibility route for the tenant's lease-contract experience.
class ContractHubScreen extends StatefulWidget {
  const ContractHubScreen({
    super.key,
    this.initialTab = 0,
    this.roomId,
    this.roomCode,
  });

  /// Retained for existing callers. Deposit contracts are no longer shown.
  final int initialTab;
  final int? roomId;
  final String? roomCode;

  @override
  State<ContractHubScreen> createState() => _ContractHubScreenState();
}

class _ContractHubScreenState extends State<ContractHubScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: _buildHeader(),
          child: LeaseContractListScreen(
            embeddedMode: true,
            roomId: widget.roomId,
            roomCode: widget.roomCode,
          ),
        ),
      ),
      bottomNavigationBar: TenantBottomNavigation(
        activeTab: TenantBottomNavTab.home,
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onBillsTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BillSelectionPage(
                roomId: widget.roomId,
                roomCode: widget.roomCode ?? '',
              ),
            ),
          );
        },
        onSupportTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MaintenanceTicketListScreen(
                roomId: widget.roomId,
                roomCode: widget.roomCode ?? '',
              ),
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
            builder: (context) => TenantRequestScreen(
              roomId: widget.roomId,
              roomCode: widget.roomCode ?? '',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppTopBar(
      title: 'Hợp đồng',
      onBack: () => Navigator.of(context).maybePop(),
    );
  }
}
