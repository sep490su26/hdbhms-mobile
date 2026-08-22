// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/models/home/electricity_consumption_entry.dart';
import 'package:hdbhms_mobile/providers/home_provider.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/notification/notification_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/utils/display_formatters.dart';
import 'package:hdbhms_mobile/widgets/app_action_tile.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';
import 'package:hdbhms_mobile/widgets/app_skeleton.dart';
import 'package:hdbhms_mobile/widgets/app_top_bar.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/payment/payment_preview_page.dart';
import 'package:hdbhms_mobile/screens/contract/contract_hub_screen.dart';
import 'package:hdbhms_mobile/screens/auth/login_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/rules/property_rules_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';
import 'package:hdbhms_mobile/screens/tenant_overview/tenant_overview_screen.dart';
import 'package:hdbhms_mobile/screens/web_view_screen.dart';
import 'package:hdbhms_mobile/screens/contract/room_amenities_screen.dart';
import 'package:hdbhms_mobile/screens/home/electricity_consumption_history_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.homeService = const HomeService(),
    this.authService = const AuthService(),
    this.profileService = const TenantProfileService(),
    this.leaseContractService = const LeaseContractService(),
    this.tenantInvoiceService = const TenantInvoiceService(),
    this.notificationService = const NotificationService(),
    this.initialRoom,
  });

  final HomeService homeService;
  final AuthService authService;
  final TenantProfileService profileService;
  final LeaseContractService leaseContractService;
  final TenantInvoiceService tenantInvoiceService;
  final NotificationService notificationService;
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
      tenantProfileService: widget.profileService,
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
            roomContext: _provider.selectedRoom,
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
      return HomeAccessErrorState(
        message: _provider.errorMessage!,
        onRetry: _provider.load,
        title: _homeErrorTitle(_provider.selectedRoom),
        onOpenRoomOverview: _openRoomOverview,
      );
    }

    final summary = _provider.summary;
    if (summary == null) {
      return HomeAccessErrorState(
        message: 'Không tải được dữ liệu Home',
        onRetry: _provider.load,
        title: _homeErrorTitle(_provider.selectedRoom),
        onOpenRoomOverview: _openRoomOverview,
      );
    }

    final selectedRoom = _provider.selectedRoom;
    final selectedRoomCode = selectedRoom?.roomCode.trim() ?? '';
    final quickActionContractId =
        selectedRoom != null && selectedRoom.contractId > 0
        ? selectedRoom.contractId
        : summary.contract?.id;
    final quickActionRoomId = selectedRoom != null && selectedRoom.roomId > 0
        ? selectedRoom.roomId
        : summary.room?.id;
    final quickActionRoomCode = selectedRoomCode.isNotEmpty
        ? selectedRoomCode
        : summary.room?.roomCode;

    return AppScreenShell(
      header: _HomeHeader(
        summary: summary,
        provider: _provider,
        notificationService: widget.notificationService,
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
              const _SectionHeading('Tiêu thụ điện'),
              const SizedBox(height: 17),
              _UtilitiesSection(
                utilities: _provider.roomUtilitySummary,
                electricityTrend: _provider.electricityTrend,
                electricityEntries: _provider.electricityConsumptionEntries,
                roomLabel: _provider.electricityRoomLabel,
                occupancyStart: _provider.electricityOccupancyStart,
                notificationService: widget.notificationService,
              ),
              const SizedBox(height: 17),
              const _SectionHeading('Thao tác nhanh'),
              const SizedBox(height: 17),
              _QuickActions(
                contractId: quickActionContractId,
                roomId: quickActionRoomId,
                roomCode: quickActionRoomCode,
              ),
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BillSelectionPage(
          invoiceService: widget.tenantInvoiceService,
          roomId: _provider.selectedRoom?.roomId,
          roomCode: _provider.selectedRoom?.roomCode ?? '',
        ),
      ),
    );

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
          notificationService: widget.notificationService,
        ),
      ),
    );
  }
}

class HomeAccessErrorState extends StatelessWidget {
  const HomeAccessErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    required this.title,
    required this.onOpenRoomOverview,
  });

  final String message;
  final VoidCallback onRetry;
  final String title;
  final VoidCallback onOpenRoomOverview;

  bool get _isRoomAccessUnavailable {
    final normalized = message.toLowerCase();
    return normalized.contains('quyền') ||
        normalized.contains('truy cập') ||
        normalized.contains('phòng này') ||
        normalized.contains('phong nay') ||
        normalized.contains('403') ||
        normalized.contains('forbidden');
  }

  String get _headline => _isRoomAccessUnavailable
      ? 'Quyền truy cập phòng đã kết thúc'
      : 'Không tải được thông tin phòng';

  String get _supportingText => _isRoomAccessUnavailable
      ? 'Phòng này không còn trong danh sách phòng bạn đang thuê. Điều này có thể xảy ra sau khi thanh lý hoặc chuyển phòng.'
      : 'Kiểm tra kết nối của bạn rồi thử tải lại thông tin phòng.';

  @override
  Widget build(BuildContext context) {
    return AppScreenShell(
      header: AppTopBar(
        title: title,
        trailing: Semantics(
          button: true,
          label: 'Danh sách phòng đang thuê',
          child: IconButton(
            onPressed: onOpenRoomOverview,
            constraints: const BoxConstraints.tightFor(
              width: AppColors.minimumTouchTarget,
              height: AppColors.minimumTouchTarget,
            ),
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Danh sách phòng đang thuê',
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 440),
          child: Center(
            child: Container(
              key: const ValueKey('home-error-card'),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                border: Border.all(
                  color: _isRoomAccessUnavailable
                      ? AppColors.warning.withValues(alpha: 0.32)
                      : AppColors.cardBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepBlue.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: _isRoomAccessUnavailable
                          ? AppColors.warningSurface
                          : AppColors.infoSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRoomAccessUnavailable
                            ? AppColors.warning.withValues(alpha: 0.35)
                            : AppColors.primary.withValues(alpha: 0.24),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isRoomAccessUnavailable
                          ? Icons.no_meeting_room_rounded
                          : Icons.cloud_off_rounded,
                      color: _isRoomAccessUnavailable
                          ? AppColors.warningText
                          : AppColors.primary,
                      size: 44,
                      semanticLabel: _headline,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _headline,
                    textAlign: TextAlign.center,
                    style: AppTypography.pageTitle.copyWith(
                      color: AppColors.inputText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _supportingText,
                    textAlign: TextAlign.center,
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isRoomAccessUnavailable
                          ? AppColors.warningSurface
                          : AppColors.inputFill,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _isRoomAccessUnavailable
                              ? AppColors.warningText
                              : AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            key: const ValueKey('home-error-message'),
                            style: AppTypography.body.copyWith(
                              color: AppColors.inputText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryGradientButton(
                      key: const ValueKey('home-error-open-rooms'),
                      onPressed: onOpenRoomOverview,
                      child: const Text('Chọn phòng khác'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey('home-error-retry'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Thử lại'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(48),
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

String _homeErrorTitle(ActiveRoomItem? room) {
  final label = room?.displayLabel.trim() ?? '';
  return label.isEmpty ? 'Tổng quan phòng' : label;
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.summary,
    required this.provider,
    required this.notificationService,
    required this.onChangeRoom,
  });

  final HomeSummary summary;
  final HomeProvider provider;
  final NotificationService notificationService;
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
          Expanded(
            child: _RoomSelector(summary: summary, provider: provider),
          ),
          IconButton(
            onPressed: onChangeRoom,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: Semantics(
              label: 'Trang chủ',
              child: Icon(
                Icons.home_rounded,
                color: AppColors.topBarIconColor,
                size: 24,
              ),
            ),
            tooltip: 'Trang chủ',
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PaymentPreviewPage(),
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: Semantics(
              label: 'Xem tr\u01B0\u1EDBc c\u00E1c m\u00E0n thanh to\u00E1n',
              child: Icon(
                Icons.preview_rounded,
                color: AppColors.topBarIconColor,
                size: 22,
              ),
            ),
            tooltip: 'Xem trước các màn thanh toán',
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NotificationListScreen(
                  roomId: provider.selectedRoom?.roomId ?? summary.room?.id,
                  roomCode:
                      provider.selectedRoom?.roomCode ??
                      summary.room?.roomCode ??
                      '',
                ),
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: Semantics(
              label: 'Th\u00F4ng b\u00E1o',
              child: AppNotificationBell(
                initialUnreadCount: summary.notificationSummary.unreadCount,
                refreshInitialUnreadCount: true,
                roomId: provider.selectedRoom?.roomId ?? summary.room?.id,
                roomCode:
                    provider.selectedRoom?.roomCode ??
                    summary.room?.roomCode ??
                    '',
                notificationService: notificationService,
              ),
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
        AppSkeleton(width: double.infinity, height: 176, borderRadius: 16),
        SizedBox(height: 16),
        AppSkeleton(width: double.infinity, height: 176, borderRadius: 16),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: const Icon(
              Icons.meeting_room_outlined,
              color: AppColors.deepBlue,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
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
                    style: AppTypography.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 15 / 11,
                    ),
                  ),
              ],
            ),
          ),
          /*Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Đổi phòng',
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
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
      for (var index = 0; index < rooms.length; index += 1) {
        final room = rooms[index];
        final isSelected =
            selectedRoom?.roomIdentityKey == room.roomIdentityKey ||
            (selectedRoom == null && room.roomId == summary.room?.id);
        items.add(
          PopupMenuItem<int>(
            value: index,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primarySurface
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      elevation: 8,
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 310),
    ).then((selectedRoomIndex) {
      if (selectedRoomIndex == null || selectedRoomIndex == -1) return;
      if (rooms.isEmpty) return;
      if (selectedRoomIndex < 0 || selectedRoomIndex >= rooms.length) return;
      provider.selectRoom(rooms[selectedRoomIndex]);
    });
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});

  final HomeUser user;

  @override
  Widget build(BuildContext context) {
    final name = user.fullName.isEmpty ? user.email : user.fullName;

    return Row(
      children: [
        _UserAvatar(user: user),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
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
          ),
        ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final HomeUser user;

  @override
  Widget build(BuildContext context) {
    final url = _resolveResourceUrl(user.avatarUrl);
    final initials = _initials(
      user.fullName.isEmpty ? user.email : user.fullName,
    );

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? _AvatarFallback(initials: initials)
          : FutureBuilder<String?>(
              future: _accessToken(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return _AvatarFallback(initials: initials);
                }
                final token = snapshot.data ?? '';
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  headers: {
                    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                    'X-Client-Type': 'mobile',
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      _AvatarFallback(initials: initials),
                );
              },
            ),
    );
  }

  static Future<String?> _accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AuthService.accessTokenKey);
  }

  static String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return _firstChar(parts.first).toUpperCase();
    return '${_firstChar(parts.first)}${_firstChar(parts.last)}'.toUpperCase();
  }

  static String _firstChar(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'U';
    return String.fromCharCode(trimmed.runes.first);
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          height: 22 / 17,
        ),
      ),
    );
  }
}

String _resolveResourceUrl(String url) {
  final value = url.trim();
  if (value.isEmpty) return '';
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return value;
  if (value.startsWith('/api/')) {
    return Uri.parse(ApiConfig.baseUrl).origin + value;
  }
  if (value.startsWith('/')) {
    return '${ApiConfig.baseUrl}$value';
  }
  return '${ApiConfig.baseUrl}/$value';
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
    final dueText = !hasUnpaid || invoiceSummary.nearestDueDate == null
        ? 'Chưa có hạn nộp'
        : hasMultipleBills
        ? 'Hạn nộp gần nhất: ${_formatDate(invoiceSummary.nearestDueDate!)}'
        : 'Hạn nộp: ${_formatDate(invoiceSummary.nearestDueDate!)}';
    final helperText = hasMultipleBills
        ? 'Có $unpaidCount hóa đơn đang chờ thanh toán. Chọn hóa đơn bạn muốn xử lý.'
        : null;
    const actionLabel = 'Xem các hóa đơn';

    final cardGradient = hasUnpaid
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.heroGradientStart,
              AppColors.deepBlue,
              AppColors.primary,
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, AppColors.requirementBackground],
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
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                'Thanh toán nhanh',
                style: AppTypography.button.copyWith(
                  color: mainTextColor,
                  fontWeight: FontWeight.w800,
                ),
              );
              final badge = _PaymentBadge(
                isUnpaid: hasUnpaid,
                unpaidCount: unpaidCount,
              );
              if (constraints.maxWidth < 290) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 8), badge],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  badge,
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            dueText,
            style: AppTypography.body.copyWith(
              color: mutedTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 15),
          if (hasUnpaid) ...[
            Text(
              'Tổng tiền cần thanh toán',
              style: AppTypography.metaLabel.copyWith(color: mutedTextColor),
            ),
            const SizedBox(height: 4),
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
          ] else
            Text(
              'Không có khoản cần thanh toán',
              style: AppTypography.body.copyWith(
                color: mainTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (helperText != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      helperText,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
                ),
              ),
              child: Text(actionLabel, style: AppTypography.button),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isUnpaid
            ? Colors.white.withValues(alpha: 0.16)
            : AppColors.successSurface,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        border: Border.all(
          color: isUnpaid
              ? Colors.white.withValues(alpha: 0.26)
              : AppColors.successText.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUnpaid) ...[
            const Icon(Icons.circle, color: AppColors.warning, size: 7),
            const SizedBox(width: 5),
          ],
          Text(
            isUnpaid
                ? (unpaidCount > 1
                      ? '$unpaidCount hóa đơn chờ'
                      : 'Chưa thanh toán')
                : 'Đã thanh toán',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: isUnpaid ? Colors.white : AppColors.successText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilitiesSection extends StatelessWidget {
  const _UtilitiesSection({
    required this.utilities,
    required this.electricityTrend,
    required this.electricityEntries,
    required this.roomLabel,
    required this.occupancyStart,
    required this.notificationService,
  });

  final UtilitySummary utilities;
  final UtilityInvoiceTrend? electricityTrend;
  final List<ElectricityConsumptionEntry> electricityEntries;
  final String roomLabel;
  final DateTime? occupancyStart;
  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UtilityCard(
          usage: utilities.electricity,
          trend: electricityTrend,
          electricityEntries: electricityEntries,
          roomLabel: roomLabel,
          occupancyStart: occupancyStart,
          notificationService: notificationService,
          title: 'Điện',
          unit: 'kWh',
          icon: Icons.bolt_rounded,
          iconColor: AppColors.warning,
          iconBackground: const Color(0xFFFFF7D6),
        ),
      ],
    );
  }
}

class _UtilityCard extends StatelessWidget {
  const _UtilityCard({
    required this.usage,
    required this.trend,
    required this.electricityEntries,
    required this.roomLabel,
    required this.occupancyStart,
    required this.notificationService,
    required this.title,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final UtilityUsage? usage;
  final UtilityInvoiceTrend? trend;
  final List<ElectricityConsumptionEntry> electricityEntries;
  final String roomLabel;
  final DateTime? occupancyStart;
  final NotificationService notificationService;
  final String title;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    final displayUnit = _normalizeUtilityUnit(
      usage?.unit.isNotEmpty == true ? usage!.unit : unit,
    );
    final activeTrend = trend;
    final currentReading = activeTrend?.currentReading ?? usage?.value;
    final previousReading = activeTrend?.previousReading;
    final utilityPeriod = activeTrend == null
        ? null
        : _resolveUtilityPeriod(
            readingPeriod: activeTrend.line.readingPeriod,
            billingPeriod: activeTrend.invoice.billingPeriod,
          );
    final period =
        utilityPeriod?.headerLabel ??
        (activeTrend == null
            ? ''
            : _utilityPeriodLabel(activeTrend.invoice.billingPeriod));
    final currentReadingLabel = utilityPeriod == null
        ? 'Chỉ số hiện tại'
        : 'Chỉ số ${utilityPeriod.monthLabel}';
    final previousReadingLabel = utilityPeriod == null
        ? 'Chỉ số tháng trước'
        : 'Chỉ số ${utilityPeriod.previous.monthLabel}';
    final consumptionLabel = utilityPeriod == null
        ? 'Tiêu thụ kỳ này'
        : 'Lượng điện tiêu thụ ${utilityPeriod.monthLabel}';
    final amountLabel = utilityPeriod == null
        ? 'Tiền điện kỳ này'
        : 'Tiền điện ${utilityPeriod.monthLabel}';
    final fallbackStatus = usage?.status.isNotEmpty == true
        ? _utilityReadingStatusLabel(usage!.status)
        : currentReading == null
        ? 'Chưa có dữ liệu'
        : 'Đang cập nhật';
    final showFallbackStatus =
        activeTrend == null && !_isConfirmedUtilityReading(usage?.status);

    return Semantics(
      label:
          '$title, $currentReadingLabel '
          '${currentReading == null ? 'chưa có dữ liệu' : '${_formatUsageValue(currentReading)} $displayUnit'}, '
          '$previousReadingLabel '
          '${previousReading == null ? 'chưa có dữ liệu' : '${_formatUsageValue(previousReading)} $displayUnit'}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepBlue.withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usage?.name.isNotEmpty == true ? usage!.name : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 20 / 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (period.isNotEmpty || showFallbackStatus)
                        Text(
                          period.isNotEmpty ? period : fallbackStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.bodyText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 16 / 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _UtilityReadingMetric(
                    label: currentReadingLabel,
                    value: currentReading,
                    unit: displayUnit,
                  ),
                ),
                Container(width: 1, height: 42, color: AppColors.cardBorder),
                const SizedBox(width: 16),
                Expanded(
                  child: _UtilityReadingMetric(
                    label: previousReadingLabel,
                    value: previousReading,
                    unit: displayUnit,
                  ),
                ),
              ],
            ),
            if (activeTrend != null) ...[
              const SizedBox(height: 14),
              Container(height: 1, color: AppColors.cardBorder),
              const SizedBox(height: 10),
              _ElectricityPeriodMetric(
                metricId: 'usage',
                label: consumptionLabel,
                value: activeTrend.currentUsage == null
                    ? '--'
                    : '${_formatUsageValue(activeTrend.currentUsage!)} $displayUnit',
              ),
              const SizedBox(height: 7),
              _ElectricityPeriodMetric(
                metricId: 'amount',
                label: amountLabel,
                value: activeTrend.line.amount == 0
                    ? '--'
                    : '${_formatAmount(activeTrend.line.amount)} đ',
              ),
            ],
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.cardBorder),
            const SizedBox(height: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ElectricityConsumptionHistoryScreen(
                      entries: electricityEntries,
                      roomLabel: roomLabel,
                      occupancyStart: occupancyStart,
                      notificationService: notificationService,
                    ),
                  ),
                ),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Row(
                    children: [
                      Expanded(
                        child: _UtilityTrendDescription(
                          trend: activeTrend,
                          unit: displayUnit,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.bodyText,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElectricityPeriodMetric extends StatelessWidget {
  const _ElectricityPeriodMetric({
    required this.metricId,
    required this.label,
    required this.value,
  });

  final String metricId;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: AppTypography.metaLabel)),
      Text(
        value,
        key: ValueKey('electricity-period-value-$metricId'),
        style: AppTypography.metaValue,
      ),
    ],
  );
}

class _UtilityReadingMetric extends StatelessWidget {
  const _UtilityReadingMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final reading = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 16 / 12,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppColors.inputText,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                height: 25 / 21,
              ),
              children: [
                TextSpan(
                  text: reading == null ? '--' : _formatUsageValue(reading),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UtilityTrendDescription extends StatelessWidget {
  const _UtilityTrendDescription({required this.trend, required this.unit});

  final UtilityInvoiceTrend? trend;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final activeTrend = trend;
    if (activeTrend == null ||
        activeTrend.direction == UtilityTrendDirection.unavailable) {
      return Text(
        'Xem mức tiêu thụ theo tháng',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.bodyText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 16 / 12,
        ),
      );
    }

    final difference = activeTrend.difference;
    final color = switch (activeTrend.direction) {
      UtilityTrendDirection.increase => AppColors.danger,
      UtilityTrendDirection.decrease => AppColors.success,
      UtilityTrendDirection.stable => AppColors.darkBlue,
      UtilityTrendDirection.unavailable => AppColors.bodyText,
    };
    final text = switch (activeTrend.direction) {
      UtilityTrendDirection.increase =>
        'Tiêu thụ tăng ${_formatUsageValue(difference!.abs())} $unit so với tháng trước',
      UtilityTrendDirection.decrease =>
        'Tiêu thụ giảm ${_formatUsageValue(difference!.abs())} $unit so với tháng trước',
      UtilityTrendDirection.stable => 'Tiêu thụ không đổi so với tháng trước',
      UtilityTrendDirection.unavailable => 'Xem mức tiêu thụ theo tháng',
    };

    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 16 / 12,
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
  const _QuickActions({this.contractId, this.roomId, this.roomCode});

  final int? contractId;
  final int? roomId;
  final String? roomCode;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: constraints.maxWidth < 300 ? 1.15 : 1.45,
      children: [
        _QuickActionButton(
          icon: Icons.rule_rounded,
          accentColor: AppColors.actionBlue,
          label: 'Nội quy nhà trọ',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PropertyRulesScreen(
                  roomId: roomId,
                  roomCode: roomCode ?? '',
                ),
              ),
            );
          },
        ),
        _QuickActionButton(
          icon: Icons.description_rounded,
          accentColor: AppColors.accent,
          label: 'Hợp đồng',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    ContractHubScreen(roomId: roomId, roomCode: roomCode),
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
    ),
  );
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
    required this.roomContext,
  });

  final AuthService authService;
  final HomeService homeService;
  final TenantProfileService profileService;
  final TenantInvoiceService tenantInvoiceService;
  final ActiveRoomItem? roomContext;

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
            builder: (context) => BillSelectionPage(
              invoiceService: tenantInvoiceService,
              roomId: roomContext?.roomId,
              roomCode: roomContext?.roomCode ?? '',
            ),
          ),
        );
      },
      onSupportTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MaintenanceTicketListScreen(
              roomId: roomContext?.roomId,
              roomCode: roomContext?.roomCode ?? '',
            ),
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
              roomId: roomContext?.roomId,
              roomCode: roomContext?.roomCode ?? '',
            ),
          ),
        );
      },
      onRequestsTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TenantRequestScreen(
            roomId: roomContext?.roomId,
            roomCode: roomContext?.roomCode ?? '',
          ),
        ),
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

String _utilityReadingStatusLabel(String status) {
  return switch (status.trim().toUpperCase()) {
    'CONFIRMED' => 'Đã chốt chỉ số',
    'VOIDED' => 'Chỉ số đã hủy',
    'DRAFT' => 'Chưa chốt chỉ số',
    'CANCELLED' => 'Đã hủy',
    _ => 'Chưa cập nhật',
  };
}

bool _isConfirmedUtilityReading(String? status) {
  return status?.trim().toUpperCase() == 'CONFIRMED';
}

String _utilityPeriodLabel(String value) {
  final period = value.trim();
  final resolved = _UtilityPeriod.tryParse(period);
  if (resolved != null) return resolved.headerLabel;
  return period.isEmpty ? '' : 'Kỳ $period';
}

_UtilityPeriod? _resolveUtilityPeriod({
  required String readingPeriod,
  required String billingPeriod,
}) =>
    _UtilityPeriod.tryParse(readingPeriod) ??
    _UtilityPeriod.tryParse(billingPeriod);

class _UtilityPeriod {
  const _UtilityPeriod({required this.year, required this.month});

  final int year;
  final int month;

  static _UtilityPeriod? tryParse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;

    final year = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    if (year == null || month == null || month < 1 || month > 12) {
      return null;
    }
    return _UtilityPeriod(year: year, month: month);
  }

  _UtilityPeriod get previous => month == 1
      ? _UtilityPeriod(year: year - 1, month: 12)
      : _UtilityPeriod(year: year, month: month - 1);

  String get monthLabel => 'T$month/$year';

  String get headerLabel =>
      'Kỳ tháng ${month.toString().padLeft(2, '0')}/$year';
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
