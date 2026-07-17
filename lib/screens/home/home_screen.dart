// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/providers/home_provider.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/utils/display_formatters.dart';
import 'package:hdbhms_mobile/widgets/app_action_tile.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/widgets/app_skeleton.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/payment/payment_preview_page.dart';
import 'package:hdbhms_mobile/screens/payment/qr_payment_page.dart';
import 'package:hdbhms_mobile/screens/contract/contract_hub_screen.dart';
import 'package:hdbhms_mobile/screens/auth/login_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/rules/property_rules_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';
import 'package:hdbhms_mobile/screens/tenant_overview/tenant_overview_screen.dart';
import 'package:hdbhms_mobile/screens/web_view_screen.dart';
import 'package:hdbhms_mobile/screens/contract/room_amenities_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.homeService = const HomeService(),
    this.authService = const AuthService(),
    this.profileService = const TenantProfileService(),
    this.leaseContractService = const LeaseContractService(),
    this.tenantInvoiceService = const TenantInvoiceService(),
    this.initialRoom,
  });

  final HomeService homeService;
  final AuthService authService;
  final TenantProfileService profileService;
  final LeaseContractService leaseContractService;
  final TenantInvoiceService tenantInvoiceService;
  final ActiveRoomItem? initialRoom;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = HomeProvider(
      homeService: widget.homeService,
      leaseContractService: widget.leaseContractService,
      tenantInvoiceService: widget.tenantInvoiceService,
      initialRoom: widget.initialRoom,
    )..addListener(_handleProviderChanged);
    _provider.load();
  }

  @override
  void dispose() {
    _provider.removeListener(_handleProviderChanged);
    _provider.dispose();
    super.dispose();
  }

  void _handleProviderChanged() {
    if (!_provider.sessionExpired || !mounted) {
      return;
    }

    AuthService.clearLocalSession();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Phiên đăng nhập đã hết hạn')),
      );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => LoginPage(
          authService: widget.authService,
          homeService: widget.homeService,
          tenantInvoiceService: widget.tenantInvoiceService,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _refresh() => _provider.load();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _provider,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(child: _buildBody()),
          bottomNavigationBar: _HomeBottomNavigation(
            authService: widget.authService,
            homeService: widget.homeService,
            profileService: widget.profileService,
            tenantInvoiceService: widget.tenantInvoiceService,
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_provider.isLoading && _provider.summary == null) {
      return const _HomeLoadingState();
    }

    if (_provider.errorMessage != null && _provider.summary == null) {
      return _HomeErrorState(
        message: _provider.errorMessage!,
        onRetry: _provider.load,
      );
    }

    final summary = _provider.summary;
    if (summary == null) {
      return _HomeErrorState(
        message: 'Không tải được dữ liệu Home',
        onRetry: _provider.load,
      );
    }

    return AppScreenShell(
      header: _HomeHeader(
        summary: summary,
        provider: _provider,
        onChangeRoom: _openRoomOverview,
      ),
      child: RefreshIndicator(
        color: AppColors.deepBlue,
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Greeting(user: summary.user),
              const SizedBox(height: 17),
              _PaymentStatusCard(
                invoiceSummary: _provider.invoiceSummary,
                onPay: _openPayment,
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 18),
              const _SectionHeading('Điện & Nước'),
              const SizedBox(height: 17),
              _UtilitiesSection(summary: summary),
              const SizedBox(height: 17),
              const _SectionHeading('Thao tác nhanh'),
              const SizedBox(height: 17),
              _QuickActions(contractId: summary.contract?.id),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPayment() async {
    final invoices = _provider.payableInvoices;
    if (invoices.isEmpty) {
      return;
    }

    if (invoices.length == 1) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QrPaymentPage(
            invoice: invoices.first,
            invoiceService: widget.tenantInvoiceService,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              BillSelectionPage(invoiceService: widget.tenantInvoiceService),
        ),
      );
    }

    if (mounted) {
      await _provider.load();
    }
  }

  void _openRoomOverview() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => TenantOverviewScreen(
          authService: widget.authService,
          homeService: widget.homeService,
          leaseContractService: widget.leaseContractService,
          profileService: widget.profileService,
          tenantInvoiceService: widget.tenantInvoiceService,
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.deepBlue,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.inputText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.summary,
    required this.provider,
    required this.onChangeRoom,
  });

  final HomeSummary summary;
  final HomeProvider provider;
  final VoidCallback onChangeRoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppColors.topBarHeight,
      padding: const EdgeInsets.fromLTRB(16, 0, 15, 0),
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
          _RoomSelector(summary: summary, provider: provider),
          const Spacer(),
          IconButton(
            onPressed: onChangeRoom,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(
              Icons.swap_horiz_rounded,
              color: AppColors.topBarIconColor,
              size: 24,
            ),
            tooltip: 'Chọn phòng khác',
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: AppNotificationBell(
              initialUnreadCount: summary.notificationSummary.unreadCount,
            ),
            tooltip: 'Thông báo',
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 28),
      children: const [
        Row(
          children: [
            AppSkeleton(width: 132, height: 32),
            Spacer(),
            AppSkeleton(width: 36, height: 36, borderRadius: 18),
            SizedBox(width: 6),
            AppSkeleton(width: 36, height: 36, borderRadius: 18),
          ],
        ),
        SizedBox(height: 24),
        AppSkeleton(width: 80, height: 14),
        SizedBox(height: 7),
        AppSkeleton(width: 196, height: 28),
        SizedBox(height: 18),
        AppSkeleton(width: double.infinity, height: 190, borderRadius: 16),
        SizedBox(height: 20),
        AppSkeleton(width: 112, height: 20),
        SizedBox(height: 17),
        Row(
          children: [
            Expanded(child: AppSkeleton(width: double.infinity, height: 116)),
            SizedBox(width: 12),
            Expanded(child: AppSkeleton(width: double.infinity, height: 116)),
          ],
        ),
        SizedBox(height: 20),
        AppSkeleton(width: 112, height: 20),
        SizedBox(height: 17),
        AppSkeleton(width: double.infinity, height: 72, borderRadius: 12),
        SizedBox(height: 10),
        AppSkeleton(width: double.infinity, height: 72, borderRadius: 12),
      ],
    );
  }
}

/// Widget hiển thị tên phòng/số phòng, khi bấm mở dropdown các phòng đã thuê.
class _RoomSelector extends StatelessWidget {
  const _RoomSelector({required this.summary, required this.provider});

  final HomeSummary summary;
  final HomeProvider provider;

  String get _roomLabel {
    final selected = provider.selectedRoom;
    if (selected != null) {
      return selected.displayLabel;
    }
    final room = summary.room;
    if (room == null) return 'Chưa có phòng';
    final name = room.name.trim();
    final code = room.roomCode.trim();
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return 'Phòng $code';
    return 'Chưa có phòng';
  }

  String get _roomSubLabel {
    final selected = provider.selectedRoom;
    if (selected != null && selected.roomCode.isNotEmpty) {
      return selected.propertyName.isNotEmpty
          ? formatPropertyName(selected.propertyName)
          : 'Phòng ${selected.roomCode}';
    }
    final room = summary.room;
    if (room != null &&
        room.roomCode.isNotEmpty &&
        room.name.trim().isNotEmpty) {
      return 'Phòng ${room.roomCode}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showRoomDropdown(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF1FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.meeting_room_outlined,
                color: AppColors.deepBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatTopBarTitle(_roomLabel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppColors.topBarTitleStyle,
                ),
                if (_roomSubLabel.isNotEmpty)
                  Text(
                    formatTopBarTitle(_roomSubLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.bodyText,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 15 / 11,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.bodyText,
              size: 18,
            ),
            const SizedBox(width: 3),
            /*Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Äá»•i phÃ²ng',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 14 / 11,
                  ),
                ),
              ),*/
          ],
        ),
      ),
    );
  }

  void _showRoomDropdown(BuildContext context) {
    final rooms = provider.activeRooms;
    final selectedRoom = provider.selectedRoom;

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(const Offset(0, 0), ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    // Build header item
    final List<PopupMenuEntry<int>> items = [
      const PopupMenuItem<int>(
        enabled: false,
        height: 32,
        child: Text(
          'PHÒNG ĐANG THUÊ',
          style: TextStyle(
            color: AppColors.bodyText,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
      const PopupMenuDivider(height: 1),
    ];

    if (rooms.isEmpty) {
      // Rooms not loaded yet — show the summary room as a selectable item
      final fallbackRoom = summary.room;
      items.add(
        PopupMenuItem<int>(
          value: -1,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF1FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.meeting_room_outlined,
                  color: AppColors.deepBlue,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fallbackRoom != null
                      ? (fallbackRoom.name.isNotEmpty
                            ? fallbackRoom.name
                            : 'Phòng ${fallbackRoom.roomCode}')
                      : 'Chưa có phòng',
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.check_rounded,
                color: AppColors.deepBlue,
                size: 18,
              ),
            ],
          ),
        ),
      );
    } else {
      for (final room in rooms) {
        final isSelected =
            selectedRoom?.contractId == room.contractId ||
            (selectedRoom == null && room.roomId == summary.room?.id);
        items.add(
          PopupMenuItem<int>(
            value: room.contractId,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFEFF1FF)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.meeting_room_outlined,
                    color: isSelected ? AppColors.deepBlue : AppColors.bodyText,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.displayLabel,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.deepBlue
                              : AppColors.inputText,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (room.propertyName.isNotEmpty)
                        Text(
                          formatPropertyName(room.propertyName),
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_rounded,
                    color: AppColors.deepBlue,
                    size: 18,
                  ),
              ],
            ),
          ),
        );
      }
    }

    showMenu<int>(
      context: context,
      position: position,
      items: items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 8,
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 310),
    ).then((selectedContractId) {
      if (selectedContractId == null || selectedContractId == -1) return;
      if (rooms.isEmpty) return;
      final room = rooms.firstWhere(
        (r) => r.contractId == selectedContractId,
        orElse: () => rooms.first,
      );
      provider.selectRoom(room);
    });
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});

  final HomeUser user;

  @override
  Widget build(BuildContext context) {
    final name = user.fullName.isEmpty ? user.email : user.fullName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'XIN CHÀO,',
          style: TextStyle(
            color: AppColors.deepBlue,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 16 / 12,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 28 / 24,
          ),
        ),
      ],
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard({required this.invoiceSummary, required this.onPay});

  final InvoiceSummary invoiceSummary;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final hasUnpaid =
        invoiceSummary.unpaidCount > 0 || invoiceSummary.totalUnpaidAmount > 0;
    final unpaidCount = invoiceSummary.unpaidCount;
    final hasMultipleBills = unpaidCount > 1;
    final dueText = invoiceSummary.nearestDueDate == null
        ? 'Chưa có hạn thanh toán'
        : 'Gần nhất: ${_formatDate(invoiceSummary.nearestDueDate!)}';
    final helperText = !hasUnpaid
        ? 'Phòng hiện tại không có khoản cần thanh toán.'
        : hasMultipleBills
        ? 'Có $unpaidCount khoản đang chờ. Bấm để chọn hóa đơn cần thanh toán.'
        : 'Thanh toán khoản đang đến hạn của phòng hiện tại.';
    final actionLabel = hasMultipleBills
        ? 'Chọn khoản thanh toán'
        : 'Thanh toán ngay';

    final cardGradient = hasUnpaid
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF061827), AppColors.deepBlue, AppColors.primary],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF0F7F4)],
          );
    final mainTextColor = hasUnpaid ? Colors.white : AppColors.inputText;
    final mutedTextColor = hasUnpaid
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.bodyText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasUnpaid
              ? Colors.white.withValues(alpha: 0.18)
              : AppColors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: (hasUnpaid ? AppColors.accent : AppColors.inputText)
                .withValues(alpha: hasUnpaid ? 0.22 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasMultipleBills
                      ? 'Tổng cần thanh toán'
                      : 'Trạng thái thanh toán',
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 20 / 15,
                  ),
                ),
              ),
              _PaymentBadge(isUnpaid: hasUnpaid, unpaidCount: unpaidCount),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            dueText,
            style: TextStyle(
              color: mutedTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 19 / 14,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  '${_formatAmount(invoiceSummary.totalUnpaidAmount)}đ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mainTextColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 38 / 32,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: hasUnpaid
                  ? Colors.white.withValues(alpha: 0.13)
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasUnpaid
                    ? Colors.white.withValues(alpha: 0.14)
                    : AppColors.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasMultipleBills
                      ? Icons.fact_check_outlined
                      : Icons.receipt_long_outlined,
                  color: hasUnpaid ? Colors.white : AppColors.bodyText,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    helperText,
                    style: TextStyle(
                      color: hasUnpaid ? Colors.white : AppColors.bodyText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 17 / 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: hasUnpaid ? onPay : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasUnpaid ? Colors.white : AppColors.primary,
                disabledBackgroundColor: AppColors.deepBlue.withValues(
                  alpha: 0.42,
                ),
                foregroundColor: hasUnpaid ? AppColors.deepBlue : Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
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

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.isUnpaid, required this.unpaidCount});

  final bool isUnpaid;
  final int unpaidCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      decoration: BoxDecoration(
        color: isUnpaid
            ? AppColors.accentWarm.withValues(alpha: 0.16)
            : AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isUnpaid
              ? AppColors.accentWarm.withValues(alpha: 0.34)
              : AppColors.success.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        isUnpaid
            ? (unpaidCount > 1 ? '$unpaidCount khoản' : 'Chưa thanh toán')
            : 'Đã thanh toán',
        style: TextStyle(
          color: isUnpaid ? const Color(0xFFB42318) : AppColors.success,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 16 / 12,
        ),
      ),
    );
  }
}

class _UtilitiesSection extends StatelessWidget {
  const _UtilitiesSection({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final utilities = summary.utilitySummary;

    return Column(
      children: [
        _UtilityCard(
          usage: utilities.electricity,
          title: 'Điện',
          unit: 'kWh',
          icon: Icons.bolt_rounded,
          iconColor: AppColors.warning,
          iconBackground: const Color(0xFFFFF7D6),
        ),
        const SizedBox(height: 16),
        _UtilityCard(
          usage: utilities.water,
          title: 'Nước',
          unit: 'm³',
          icon: Icons.water_drop_outlined,
          iconColor: AppColors.accent,
          iconBackground: const Color(0xFFE5FAF6),
        ),
      ],
    );
  }
}

class _UtilityCard extends StatelessWidget {
  const _UtilityCard({
    required this.usage,
    required this.title,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final UtilityUsage? usage;
  final String title;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    final value = usage?.value;
    final percentChange = usage?.percentChange;
    final displayUnit = _normalizeUtilityUnit(
      usage?.unit.isNotEmpty == true ? usage!.unit : unit,
    );
    final status = usage?.status.isNotEmpty == true
        ? usage!.status
        : value == null
        ? 'Chưa có dữ liệu'
        : 'Đang đọc';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 83),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 27),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  usage?.name.isNotEmpty == true ? usage!.name : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 16 / 12,
                  ),
                ),
                const SizedBox(height: 3),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      color: AppColors.inputText,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 24 / 20,
                    ),
                    children: [
                      TextSpan(
                        text: value == null ? '--' : _formatUsageValue(value),
                      ),
                      TextSpan(
                        text: ' $displayUnit',
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (percentChange != null)
                Text(
                  '${percentChange > 0 ? '+' : ''}${_formatSignedPercent(percentChange)} với tháng trước',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: percentChange > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 16 / 12,
                  ),
                ),
              if (percentChange != null) const SizedBox(height: 10),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 17 / 13,
                ),
              ),
            ],
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
    return Text(title, style: AppTypography.sectionTitle);
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({this.contractId});

  final int? contractId;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.62,
      children: [
        _QuickActionButton(
          icon: Icons.rule_rounded,
          accentColor: AppColors.actionBlue,
          label: 'Nội quy nhà trọ',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PropertyRulesScreen(),
              ),
            );
          },
        ),
        _QuickActionButton(
          icon: Icons.description_rounded,
          accentColor: AppColors.accent,
          label: 'Hợp Đồng',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ContractHubScreen(),
              ),
            );
          },
        ),
        _QuickActionButton(
          icon: Icons.weekend_outlined,
          accentColor: AppColors.actionOrange,
          label: 'Tiện ích phòng',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    RoomAmenitiesScreen(contractId: contractId),
              ),
            );
          },
        ),
        _QuickActionButton(
          icon: Icons.add_home_work_rounded,
          accentColor: AppColors.actionRose,
          label: 'Thuê thêm phòng',
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString(AuthService.accessTokenKey) ?? '';
            final sessionId = prefs.getString(AuthService.sessionIdKey) ?? '';
            final userRole = prefs.getString(AuthService.roleKey) ?? '';

            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => WebViewScreen(
                  url: '${ApiConfig.frontendUrl}/api/mobile-auth',
                  title: 'Thuê thêm phòng',
                  postData: {
                    'token': token,
                    'sessionId': sessionId,
                    'userRole': userRole,
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppActionTile(
      icon: icon,
      label: label,
      accentColor: accentColor,
      onTap: onTap,
    );
  }
}

class _HomeBottomNavigation extends StatelessWidget {
  const _HomeBottomNavigation({
    required this.authService,
    required this.homeService,
    required this.profileService,
    required this.tenantInvoiceService,
  });

  final AuthService authService;
  final HomeService homeService;
  final TenantProfileService profileService;
  final TenantInvoiceService tenantInvoiceService;

  Future<void> _handleLogout(BuildContext context) async {
    await authService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => LoginPage(
          authService: authService,
          homeService: homeService,
          tenantInvoiceService: tenantInvoiceService,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TenantBottomNavigation(
      activeTab: TenantBottomNavTab.home,
      onBillsTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                BillSelectionPage(invoiceService: tenantInvoiceService),
          ),
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
            builder: (context) => TenantProfileScreen(
              authService: authService,
              homeService: homeService,
              profileService: profileService,
            ),
          ),
        );
      },
      onRequestsTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const TenantRequestScreen()),
      ),
    );
  }
}

void _showTodo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _normalizeUtilityUnit(String unit) {
  final normalized = unit.trim().toLowerCase();
  if (normalized == 'm3' || normalized == 'm^3' || normalized == 'm³') {
    return 'm³';
  }
  return unit.trim();
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatAmount(num amount) {
  final value = amount.round().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < value.length; i++) {
    final reverseIndex = value.length - i;
    buffer.write(value[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }

  return buffer.toString();
}

String _formatUsageValue(num value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

String _formatSignedPercent(num value) {
  final absolute = value.abs();
  final formatted = absolute == absolute.roundToDouble()
      ? absolute.round().toString()
      : absolute.toStringAsFixed(1);
  return '$formatted%';
}
