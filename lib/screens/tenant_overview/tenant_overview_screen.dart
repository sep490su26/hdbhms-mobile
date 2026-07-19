import 'dart:async';

import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    _imageController.dispose();
    super.dispose();
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
            roomCount: _rooms.length,
            onProfileTap: _openProfile,
            onPageChanged: (index) => setState(() => _imageIndex = index),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PropertySummaryCard(
                  phone: phone.isEmpty
                      ? 'Chưa cập nhật SĐT nhà trọ'
                      : 'SĐT nhà trọ: $phone',
                  address: address,
                ),
                const SizedBox(height: 20),
                _RoomSectionHeader(count: _rooms.length),
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
    required this.roomCount,
    required this.onProfileTap,
    required this.onPageChanged,
  });

  final PageController controller;
  final List<String> images;
  final int currentIndex;
  final String tenantName;
  final int roomCount;
  final VoidCallback onProfileTap;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final pageCount = images.isEmpty ? 3 : images.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = constraints.maxWidth < 380 ? 276.0 : 296.0;
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
                child: _HeroTopBar(onProfileTap: onProfileTap),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 38,
                child: _HeroPropertyInfo(
                  tenantName: tenantName,
                  roomCount: roomCount,
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
  const _HeroTopBar({required this.onProfileTap});

  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _OverviewLogoMark(),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationListScreen()),
          ),
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
          icon: const AppNotificationBell(color: Colors.white, size: 23),
          tooltip: 'Thông báo',
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: onProfileTap,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          tooltip: 'Hồ sơ',
        ),
      ],
    );
  }
}

class _HeroPropertyInfo extends StatelessWidget {
  const _HeroPropertyInfo({required this.tenantName, required this.roomCount});

  final String tenantName;
  final int roomCount;

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
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 27 / 22,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _HeroInfoPill(
              icon: Icons.meeting_room_outlined,
              label: '$roomCount phòng đang thuê',
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroInfoPill extends StatelessWidget {
  const _HeroInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 14 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewLogoMark extends StatelessWidget {
  const _OverviewLogoMark();

  @override
  Widget build(BuildContext context) =>
      const AppBrandLogo(variant: AppBrandLogoVariant.overview);
}

class _PropertySummaryCard extends StatelessWidget {
  const _PropertySummaryCard({required this.phone, required this.address});

  final String phone;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.inputText.withValues(alpha: 0.055),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin nhà trọ',
            style: TextStyle(
              color: AppColors.inputText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 24 / 18,
            ),
          ),
          const SizedBox(height: 14),
          _PropertyInfoLine(icon: Icons.call_outlined, text: phone),
          const SizedBox(height: 10),
          _PropertyInfoLine(icon: Icons.location_on_outlined, text: address),
        ],
      ),
    );
  }
}

class _PropertyInfoLine extends StatelessWidget {
  const _PropertyInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.inputText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 18 / 13,
              ),
            ),
          ),
        ),
      ],
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
            borderRadius: BorderRadius.circular(99),
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
      const Color(0xFF12345C),
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
  const _RoomSectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Phòng đang thuê',
            style: TextStyle(
              color: AppColors.inputText,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 24 / 19,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$count phòng',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 15 / 12,
            ),
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(height: 9),
                    _RoomStatusPill(label: status),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
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
          borderRadius: BorderRadius.circular(99),
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.meeting_room_outlined,
            color: AppColors.deepBlue,
            size: 32,
          ),
          SizedBox(height: 10),
          Text(
            'Chưa có phòng đang thuê',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inputText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
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
    _ => rawStatus.trim().isEmpty ? 'Đang thuê' : rawStatus.trim(),
  };
}

String _roleLabel(String rawRole) {
  return switch (rawRole.trim().toUpperCase()) {
    'PRIMARY' => 'Người thuê chính',
    'CO_OCCUPANT' => 'Người ở cùng',
    _ => rawRole.trim(),
  };
}

String _formatShortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
