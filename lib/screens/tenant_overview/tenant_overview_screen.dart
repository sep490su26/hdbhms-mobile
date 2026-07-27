import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/widgets/app_empty_state.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/screens/auth/login_page.dart';
import 'package:hdbhms_mobile/screens/home/home_screen.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/utils/display_formatters.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/widgets/app_skeleton.dart';
import 'package:hdbhms_mobile/widgets/app_brand_logo.dart';

class TenantOverviewScreen extends StatefulWidget {
  const TenantOverviewScreen({
    super.key,
    this.authService = const AuthService(),
    this.homeService = const HomeService(),
    this.leaseContractService = const LeaseContractService(),
    this.profileService = const TenantProfileService(),
    this.tenantInvoiceService = const TenantInvoiceService(),
  });

  final AuthService authService;
  final HomeService homeService;
  final LeaseContractService leaseContractService;
  final TenantProfileService profileService;
  final TenantInvoiceService tenantInvoiceService;

  @override
  State<TenantOverviewScreen> createState() => _TenantOverviewScreenState();
}

class _TenantOverviewScreenState extends State<TenantOverviewScreen> {
  final PageController _imageController = PageController();
  Timer? _imageTimer;
  HomeSummary? _summary;
  List<ActiveRoomItem> _rooms = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _imageIndex = 0;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadUserName();
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    try {
      final profile = await widget.profileService.getMyProfile();
      if (mounted && profile.person.fullName.trim().isNotEmpty) {
        setState(() => _userName = profile.person.fullName.trim());
      }
    } catch (_) {
      // Không hiển thị lỗi nếu không lấy được tên
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _imageIndex = 0;
    });

    try {
      final summary = await widget.homeService.fetchHomeSummary();
      var rooms = _roomsFromSummary(summary);

      try {
        final activeRooms = await widget.leaseContractService
            .fetchMyActiveRooms();
        if (activeRooms.isNotEmpty) {
          rooms = dedupeActiveRoomsByRoom(activeRooms);
        }
      } catch (_) {
        // The overview can still work with the rooms returned by /home.
      }

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _rooms = rooms;
        _isLoading = false;
      });
      _startImageTimer(_imageUrls(summary));
    } on HomeException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không tải được tổng quan nhà trọ';
        _isLoading = false;
      });
    }
  }

  List<ActiveRoomItem> _roomsFromSummary(HomeSummary summary) {
    final rooms = summary.rooms
        .map((room) {
          return ActiveRoomItem(
            contractId: summary.contract?.id ?? 0,
            contractCode: summary.contract?.contractCode ?? '',
            roomId: room.id ?? 0,
            roomCode: room.roomCode,
            roomName: room.name,
            roomStatus: room.currentStatus,
            propertyName: formatPropertyName(summary.tenant?.name ?? ''),
            contractStatus: summary.contract?.status ?? '',
            startDate: summary.contract?.startDate,
            endDate: summary.contract?.endDate,
          );
        })
        .toList(growable: false);

    final summaryRoom = summary.room;
    if (rooms.isNotEmpty || summaryRoom == null) {
      return dedupeActiveRoomsByRoom(rooms);
    }

    return dedupeActiveRoomsByRoom([
      ActiveRoomItem(
        contractId: summary.contract?.id ?? 0,
        contractCode: summary.contract?.contractCode ?? '',
        roomId: summaryRoom.id ?? 0,
        roomCode: summaryRoom.roomCode,
        roomName: summaryRoom.name,
        roomStatus: summaryRoom.currentStatus,
        propertyName: formatPropertyName(summary.tenant?.name ?? ''),
        contractStatus: summary.contract?.status ?? '',
        startDate: summary.contract?.startDate,
        endDate: summary.contract?.endDate,
      ),
    ]);
  }

  void _startImageTimer(List<String> images) {
    _imageTimer?.cancel();
    final pageCount = images.isEmpty ? 3 : images.length;
    if (pageCount <= 1) return;

    _imageTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_imageController.hasClients) return;
      final next = (_imageIndex + 1) % pageCount;
      _imageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<String> _imageUrls(HomeSummary summary) {
    return summary.tenant?.imageUrls
            .map(_resolveResourceUrl)
            .where((url) => url.isNotEmpty)
            .toList(growable: false) ??
        const [];
  }

  void _openRoom(ActiveRoomItem room) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          authService: widget.authService,
          homeService: widget.homeService,
          profileService: widget.profileService,
          leaseContractService: widget.leaseContractService,
          tenantInvoiceService: widget.tenantInvoiceService,
          initialRoom: room,
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TenantProfileScreen(
          authService: widget.authService,
          homeService: widget.homeService,
          profileService: widget.profileService,
          showBottomNavigation: false,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => LoginPage(
          authService: widget.authService,
          homeService: widget.homeService,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const _OverviewLoadingState();
    }

    if (_errorMessage != null) {
      return _OverviewErrorState(
        message: _errorMessage!,
        onRetry: _load,
        onLogout: _logout,
      );
    }

    final summary = _summary;
    if (summary == null) {
      return _OverviewErrorState(
        message: 'Không có dữ liệu tổng quan',
        onRetry: _load,
        onLogout: _logout,
      );
    }

    final tenant = summary.tenant;
    final tenantName = tenant?.name.trim().isNotEmpty == true
        ? formatPropertyName(tenant!.name.trim())
        : 'Nhà trọ của tôi';
    final phone = tenant?.propertyPhone.trim() ?? '';
    final address = tenant?.address.trim().isNotEmpty == true
        ? tenant!.address.trim()
        : 'Chưa cập nhật địa chỉ';
    final images = _imageUrls(summary);

    return RefreshIndicator(
      color: AppColors.deepBlue,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _OverviewHero(
            controller: _imageController,
            images: images,
            currentIndex: _imageIndex,
            tenantName: tenantName,
            phone: phone.isEmpty ? 'Chưa cập nhật số điện thoại' : phone,
            address: address,
            userName: _userName,
            onProfileTap: _openProfile,
            onPageChanged: (index) => setState(() => _imageIndex = index),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RoomSectionHeader(roomCount: _rooms.length),
                const SizedBox(height: 12),
                if (_rooms.isEmpty)
                  const _EmptyRoomsCard()
                else
                  ..._rooms.map(
                    (room) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RoomOverviewCard(
                        room: room,
                        onTap: () => _openRoom(room),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewHero extends StatelessWidget {
  const _OverviewHero({
    required this.controller,
    required this.images,
    required this.currentIndex,
    required this.tenantName,
    required this.phone,
    required this.address,
    required this.userName,
    required this.onProfileTap,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<String> images;
  final int currentIndex;
  final String tenantName;
  final String phone;
  final String address;
  final String userName;
  final VoidCallback onProfileTap;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final pageCount = images.isEmpty ? 3 : images.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = constraints.maxWidth < 380 ? 292.0 : 312.0;
        return SizedBox(
          height: heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: controller,
                itemCount: pageCount,
                onPageChanged: onPageChanged,
                itemBuilder: (context, index) {
                  if (images.isEmpty) {
                    return _FallbackPropertyImage(index: index);
                  }
                  return Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _FallbackPropertyImage(index: index),
                  );
                },
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66020B1A),
                      Color(0x22020B1A),
                      Color(0xEE071426),
                    ],
                    stops: [0, 0.42, 1],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: _HeroTopBar(
                  userName: userName,
                  onProfileTap: onProfileTap,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 38,
                child: _HeroPropertyInfo(
                  tenantName: tenantName,
                  phone: phone,
                  address: address,
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                child: _HeroImageIndicator(
                  pageCount: pageCount,
                  currentIndex: currentIndex,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroTopBar extends StatelessWidget {
  const _HeroTopBar({required this.userName, required this.onProfileTap});

  final String userName;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar icon nhỏ + tên người dùng (bấm → hồ sơ)
        Expanded(
          child: GestureDetector(
            onTap: onProfileTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    userName.isEmpty ? 'Hồ sơ của tôi' : userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 18 / 14,
                      shadows: const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Chuông thông báo bên phải
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationListScreen()),
          ),
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
          icon: const AppNotificationBell(color: Colors.white, size: 23),
          tooltip: 'Thông báo',
        ),
      ],
    );
  }
}

class _HeroPropertyInfo extends StatelessWidget {
  const _HeroPropertyInfo({
    required this.tenantName,
    required this.phone,
    required this.address,
  });

  final String tenantName;
  final String phone;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tenantName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 26 / 21,
          ),
        ),
        const SizedBox(height: 9),
        _HeroDetailLine(icon: Icons.call_outlined, text: phone),
        const SizedBox(height: 5),
        _HeroDetailLine(icon: Icons.location_on_outlined, text: address),
      ],
    );
  }
}

class _HeroDetailLine extends StatelessWidget {
  const _HeroDetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 14 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _OverviewLogoMark extends StatelessWidget {
  const _OverviewLogoMark();

  @override
  Widget build(BuildContext context) =>
      const AppBrandLogo(variant: AppBrandLogoVariant.overview);
}

// ignore: unused_element
class _RentalPortfolioCard extends StatelessWidget {
  const _RentalPortfolioCard({required this.rooms});

  final List<ActiveRoomItem> rooms;

  @override
  Widget build(BuildContext context) {
    final propertyCount = rooms
        .map((room) => formatPropertyName(room.propertyName).trim())
        .where((property) => property.isNotEmpty)
        .toSet()
        .length;
    final primaryCount = rooms
        .where((room) => room.roleInContract.trim().toUpperCase() == 'PRIMARY')
        .length;
    final soonExpiringCount = rooms.where(_isExpiringSoon).length;
    final nearestEndDate = _nearestEndDate(rooms);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              color: AppColors.deepBlue,
              size: 19,
            ),
            SizedBox(width: 8),
            Text(
              'Tổng quan lưu trú',
              style: TextStyle(
                color: AppColors.inputText,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 20 / 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PortfolioMetric(
                icon: Icons.meeting_room_outlined,
                label: 'Phòng',
                value: rooms.length.toString(),
                color: AppColors.actionBlue,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _PortfolioMetric(
                icon: Icons.apartment_rounded,
                label: 'Cơ sở',
                value: propertyCount == 0 ? '1' : propertyCount.toString(),
                color: AppColors.actionEmerald,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _PortfolioMetric(
                icon: Icons.event_available_outlined,
                label: 'HĐ sắp hết hạn',
                value: soonExpiringCount.toString(),
                color: soonExpiringCount > 0
                    ? AppColors.actionOrange
                    : AppColors.actionCyan,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _PortfolioMetric(
                icon: Icons.verified_user_outlined,
                label: 'Đứng tên',
                value: primaryCount.toString(),
                color: AppColors.actionViolet,
              ),
            ),
          ],
        ),
        if (nearestEndDate != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.deepBlue,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hợp đồng gần nhất hết hạn ${_formatShortDate(nearestEndDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.inputText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 16 / 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ignore: unused_element
class _PortfolioMetric extends StatelessWidget {
  const _PortfolioMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Color.alphaBlend(
      color.withValues(alpha: 0.16),
      AppColors.surface,
    );
    final accentColor = color.withValues(alpha: 0.28);
    final iconBackgroundColor = color.withValues(alpha: 0.14);

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: accentColor),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: Icon(icon, color: color, size: 13),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 17 / 14,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 11 / 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _OverviewGuideCard extends StatelessWidget {
  const _OverviewGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.inputText.withValues(alpha: 0.055),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Row(
        children: [
          _GuideIcon(),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quản lý theo từng phòng',
                  style: TextStyle(
                    color: AppColors.inputText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 18 / 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Chọn một phòng bên dưới để xem hóa đơn, hợp đồng và tiện ích riêng.',
                  style: TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 17 / 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideIcon extends StatelessWidget {
  const _GuideIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: const Icon(
        Icons.tips_and_updates_outlined,
        color: AppColors.primary,
        size: 21,
      ),
    );
  }
}

class _HeroImageIndicator extends StatelessWidget {
  const _HeroImageIndicator({
    required this.pageCount,
    required this.currentIndex,
  });

  final int pageCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(pageCount, (index) {
        final selected = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 24 : 7,
          height: 7,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(AppColors.radiusPill),
          ),
        );
      }),
    );
  }
}

class _FallbackPropertyImage extends StatelessWidget {
  const _FallbackPropertyImage({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.apartment_rounded,
      Icons.bedroom_parent_outlined,
      Icons.home_work_outlined,
    ];
    final colors = [
      const Color(0xFF071426),
      AppColors.darkBlue,
      const Color(0xFF1D4ED8),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[index % colors.length],
            AppColors.deepBlue,
            AppColors.primary,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icons[index % icons.length],
          color: Colors.white.withValues(alpha: 0.84),
          size: 88,
        ),
      ),
    );
  }
}

class _RoomSectionHeader extends StatelessWidget {
  const _RoomSectionHeader({required this.roomCount});

  final int roomCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Phòng đang thuê',
          style: TextStyle(
            color: AppColors.inputText,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            height: 24 / 19,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 11, 7),
          decoration: BoxDecoration(
            color: AppColors.deepBlue,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlue.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.meeting_room_outlined,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '$roomCount phòng',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 16 / 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoomOverviewCard extends StatelessWidget {
  const _RoomOverviewCard({required this.room, required this.onTap});

  final ActiveRoomItem room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(
      room.contractStatus.isNotEmpty ? room.contractStatus : room.roomStatus,
    );

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.inputText.withValues(alpha: 0.045),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.deepBlue,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  _roomShortCode(room),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inputText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 20 / 15,
                      ),
                    ),
                    if (room.propertyName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        formatPropertyName(room.propertyName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.bodyText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 16 / 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (room.endDate != null)
                          _RoomMeta(
                            icon: Icons.event_outlined,
                            text: 'Hết hạn: ${_formatShortDate(room.endDate!)}',
                          ),
                        if (room.occupantCount > 0)
                          _RoomMeta(
                            icon: Icons.people_outline_rounded,
                            text: '${room.occupantCount} người đang ở',
                          ),
                        if (room.roleInContract.isNotEmpty)
                          _RoomMeta(
                            icon: Icons.person_outline_rounded,
                            text: _roleLabel(room.roleInContract),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _RoomStatusPill(label: status),
                  const SizedBox(height: 10),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.deepBlue,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomMeta extends StatelessWidget {
  const _RoomMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.bodyText, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 14 / 11,
          ),
        ),
      ],
    );
  }
}

class _RoomStatusPill extends StatelessWidget {
  const _RoomStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Sắp hết hạn' => AppColors.warning,
      'Hết hạn' => AppColors.danger,
      'Đang thuê' => AppColors.success,
      _ => AppColors.bodyText,
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 14 / 11,
          ),
        ),
      ),
    );
  }
}

class _EmptyRoomsCard extends StatelessWidget {
  const _EmptyRoomsCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: const AppEmptyState(
      icon: Icons.meeting_room_outlined,
      title: 'Ch\u01B0a c\u00F3 ph\u00F2ng \u0111ang thu\u00EA',
      compact: true,
    ),
  );
}

class _OverviewLoadingState extends StatelessWidget {
  const _OverviewLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: const [
        AppSkeleton(width: double.infinity, height: 296, borderRadius: 0),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 172, height: 22),
              SizedBox(height: 12),
              AppSkeleton(width: double.infinity, height: 88, borderRadius: 12),
              SizedBox(height: 26),
              AppSkeleton(width: 142, height: 20),
              SizedBox(height: 12),
              AppSkeleton(
                width: double.infinity,
                height: 130,
                borderRadius: 12,
              ),
              SizedBox(height: 10),
              AppSkeleton(
                width: double.infinity,
                height: 130,
                borderRadius: 12,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewErrorState extends StatelessWidget {
  const _OverviewErrorState({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

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
                fontWeight: FontWeight.w800,
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
            TextButton(onPressed: onLogout, child: const Text('Đăng xuất')),
          ],
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
  if (value.startsWith('/')) {
    return Uri.parse(ApiConfig.baseUrl).origin + value;
  }
  return '${ApiConfig.baseUrl}/$value';
}

String _roomShortCode(ActiveRoomItem room) {
  final code = room.roomCode.trim();
  if (code.isNotEmpty) return code;
  final name = room.roomName.trim();
  if (name.isEmpty) return 'P';
  return name.length <= 3 ? name : name.substring(name.length - 3);
}

String _statusLabel(String rawStatus) {
  final value = rawStatus.trim().toUpperCase();
  return switch (value) {
    'ACTIVE' || 'OCCUPIED' || 'RENTED' => 'Đang thuê',
    'EXPIRING_SOON' => 'Sắp hết hạn',
    'EXPIRED' => 'Hết hạn',
    'DEPOSITED' || 'HELD' => 'Đã cọc',
    'MAINTENANCE' => 'Bảo trì',
    'VACANT' => 'Còn trống',
    _ => 'Chưa cập nhật',
  };
}

String _roleLabel(String rawRole) {
  return switch (rawRole.trim().toUpperCase()) {
    'PRIMARY' => 'Người thuê chính',
    'CO_OCCUPANT' => 'Người ở cùng',
    _ => 'Chưa xác định',
  };
}

bool _isExpiringSoon(ActiveRoomItem room) {
  final endDate = room.endDate;
  if (endDate == null) return false;
  final today = DateTime.now();
  final dateOnlyToday = DateTime(today.year, today.month, today.day);
  final dateOnlyEnd = DateTime(endDate.year, endDate.month, endDate.day);
  final daysLeft = dateOnlyEnd.difference(dateOnlyToday).inDays;
  return daysLeft >= 0 && daysLeft <= 45;
}

DateTime? _nearestEndDate(List<ActiveRoomItem> rooms) {
  DateTime? nearest;
  for (final room in rooms) {
    final endDate = room.endDate;
    if (endDate == null) continue;
    if (nearest == null || endDate.isBefore(nearest)) {
      nearest = endDate;
    }
  }
  return nearest;
}

String _formatShortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
