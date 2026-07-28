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
import 'package:hdbhms_mobile/screens/payment/bill_detail_screen.dart';
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
              _UtilitiesSection(
                utilities: _provider.roomUtilitySummary,
                electricityTrend: _provider.electricityTrend,
                waterTrend: _provider.waterTrend,
                invoiceService: widget.tenantInvoiceService,
              ),
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
      final invoice = invoices.first;
      final isUtility = invoice.invoiceType.toUpperCase() == 'UTILITY';
      final canOpenQr =
          invoice.canPay &&
          (invoice.qrCode.isNotEmpty || invoice.transferDescription.isNotEmpty);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            if (isUtility || !canOpenQr) {
              return BillDetailScreen(
                invoice: invoice,
                invoiceService: widget.tenantInvoiceService,
              );
            }
            return QrPaymentPage(
              invoice: invoice,
              invoiceService: widget.tenantInvoiceService,
            );
          },
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BillSelectionPage(
            invoiceService: widget.tenantInvoiceService,
            roomId: _provider.selectedRoom?.roomId,
            roomCode: _provider.selectedRoom?.roomCode ?? '',
          ),
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
          Expanded(
            child: _RoomSelector(summary: summary, provider: provider),
          ),
          IconButton(
            onPressed: onChangeRoom,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: Semantics(
              label: 'Ch\u1ECDn ph\u00F2ng kh\u00E1c',
              child: Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.topBarIconColor,
                size: 24,
              ),
            ),
            tooltip: 'Chọn phòng khác',
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
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: Semantics(
              label: 'Th\u00F4ng b\u00E1o',
              child: AppNotificationBell(
                initialUnreadCount: summary.notificationSummary.unreadCount,
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
        : 'Xem chi tiết hóa đơn';

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
          Row(
            children: [
              Expanded(
                child: Text(
                  hasMultipleBills
                      ? 'Tổng cần thanh toán'
                      : 'Trạng thái thanh toán',
                  style: TextStyle(
                    color: mainTextColor,
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
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
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
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
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
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
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
          color: isUnpaid ? AppColors.dangerText : AppColors.success,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 16 / 12,
        ),
      ),
    );
  }
}

class _UtilitiesSection extends StatelessWidget {
  const _UtilitiesSection({
    required this.utilities,
    required this.electricityTrend,
    required this.waterTrend,
    required this.invoiceService,
  });

  final UtilitySummary utilities;
  final UtilityInvoiceTrend? electricityTrend;
  final UtilityInvoiceTrend? waterTrend;
  final TenantInvoiceService invoiceService;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UtilityCard(
          usage: utilities.electricity,
          trend: electricityTrend,
          invoiceService: invoiceService,
          title: 'Điện',
          unit: 'kWh',
          icon: Icons.bolt_rounded,
          iconColor: AppColors.warning,
          iconBackground: const Color(0xFFFFF7D6),
        ),
        const SizedBox(height: 16),
        _UtilityCard(
          usage: utilities.water,
          trend: waterTrend,
          invoiceService: invoiceService,
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
    required this.trend,
    required this.invoiceService,
    required this.title,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final UtilityUsage? usage;
  final UtilityInvoiceTrend? trend;
  final TenantInvoiceService invoiceService;
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
    final period = activeTrend == null
        ? ''
        : _utilityPeriodLabel(activeTrend.invoice.billingPeriod);
    final fallbackStatus = usage?.status.isNotEmpty == true
        ? _utilityReadingStatusLabel(usage!.status)
        : currentReading == null
        ? 'Chưa có dữ liệu'
        : 'Đang cập nhật';
    final showFallbackStatus =
        activeTrend == null && !_isConfirmedUtilityReading(usage?.status);

    return Semantics(
      label:
          '$title, chỉ số hiện tại '
          '${currentReading == null ? 'chưa có dữ liệu' : '${_formatUsageValue(currentReading)} $displayUnit'}',
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
                if (activeTrend != null) _UtilityTrendBadge(trend: activeTrend),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _UtilityReadingMetric(
                    label: 'Chỉ số hiện tại',
                    value: currentReading,
                    unit: displayUnit,
                  ),
                ),
                Container(width: 1, height: 42, color: AppColors.cardBorder),
                const SizedBox(width: 16),
                Expanded(
                  child: _UtilityReadingMetric(
                    label: 'Chỉ số tháng trước',
                    value: previousReading,
                    unit: displayUnit,
                  ),
                ),
              ],
            ),
            if (activeTrend != null || showFallbackStatus) ...[
              const SizedBox(height: 14),
              Container(height: 1, color: AppColors.cardBorder),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _UtilityTrendDescription(
                      trend: activeTrend,
                      unit: displayUnit,
                      fallbackStatus: fallbackStatus,
                    ),
                  ),
                  if (activeTrend != null)
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => BillDetailScreen(
                            invoice: activeTrend.invoice,
                            invoiceService: invoiceService,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Xem chi tiết'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

class _UtilityTrendBadge extends StatelessWidget {
  const _UtilityTrendBadge({required this.trend});

  final UtilityInvoiceTrend trend;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background, label) = switch (trend.direction) {
      UtilityTrendDirection.increase => (
        Icons.trending_up_rounded,
        AppColors.danger,
        AppColors.dangerSurface,
        'Tăng',
      ),
      UtilityTrendDirection.decrease => (
        Icons.trending_down_rounded,
        AppColors.success,
        AppColors.successSurface,
        'Giảm',
      ),
      UtilityTrendDirection.stable => (
        Icons.trending_flat_rounded,
        AppColors.darkBlue,
        AppColors.primaryLight,
        'Ổn định',
      ),
      UtilityTrendDirection.unavailable => (
        Icons.remove_rounded,
        AppColors.bodyText,
        AppColors.surfaceMuted,
        'Đang so sánh',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 16 / 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityTrendDescription extends StatelessWidget {
  const _UtilityTrendDescription({
    required this.trend,
    required this.unit,
    required this.fallbackStatus,
  });

  final UtilityInvoiceTrend? trend;
  final String unit;
  final String fallbackStatus;

  @override
  Widget build(BuildContext context) {
    final activeTrend = trend;
    if (activeTrend == null) {
      return Text(
        fallbackStatus,
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
      UtilityTrendDirection.unavailable =>
        'Chưa đủ dữ liệu để so sánh tiêu thụ',
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
          label: 'Hợp đồng',
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
  if (RegExp(r'^\d{4}-\d{2}$').hasMatch(period)) {
    final parts = period.split('-');
    return 'Kỳ tháng ${parts[1]}/${parts[0]}';
  }
  return period.isEmpty ? '' : 'Kỳ $period';
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
