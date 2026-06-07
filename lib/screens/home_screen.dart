import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/config/app_config.dart';

import '../models/home_summary_model.dart';
import '../providers/home_provider.dart';
import '../services/auth_service.dart';
import '../services/home_service.dart';
import '../services/tenant_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/tenant_bottom_navigation.dart';
import 'bill_selection_page.dart';
import 'contract_hub_screen.dart';
import 'create_maintenance_ticket_screen.dart';
import 'login_page.dart';
import 'maintenance_ticket_list_screen.dart';
import 'property_rules_screen.dart';
import 'tenant_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.homeService = const HomeService(),
    this.authService = const AuthService(),
    this.profileService = const TenantProfileService(),
  });

  final HomeService homeService;
  final AuthService authService;
  final TenantProfileService profileService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = HomeProvider(homeService: widget.homeService)
      ..addListener(_handleProviderChanged);
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
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: _buildBody(),
              ),
            ),
          ),
          bottomNavigationBar: _HomeBottomNavigation(
            authService: widget.authService,
            homeService: widget.homeService,
            profileService: widget.profileService,
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_provider.isLoading && _provider.summary == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.deepBlue),
      );
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

    return Column(
      children: [
        _HomeHeader(summary: summary),
        Expanded(
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
                  _PaymentStatusCard(summary: summary),
                  const SizedBox(height: 18),
                  const _SectionHeading('Điện & Nước'),
                  const SizedBox(height: 17),
                  _UtilitiesSection(summary: summary),
                  const SizedBox(height: 17),
                  const _SectionHeading('Thao tác nhanh'),
                  const SizedBox(height: 17),
                  const _QuickActions(),
                ],
              ),
            ),
          ),
        ),
      ],
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
  const _HomeHeader({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
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
          _RoomSelector(room: summary.room),
          const Spacer(),
          IconButton(
            onPressed: () => _showTodo(context, 'Màn thông báo chưa có'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.inputText,
              size: 24,
            ),
            tooltip: 'Thông báo',
          ),
          const SizedBox(width: 8),
          _UserAvatar(user: summary.user),
        ],
      ),
    );
  }
}

/// Widget hiển thị tên phòng/số phòng, khi bấm mở dropdown các phòng đã thuê.
class _RoomSelector extends StatelessWidget {
  const _RoomSelector({required this.room});

  final HomeRoom? room;

  String get _roomLabel {
    if (room == null) return 'Chưa có phòng';
    final name = room!.name.trim();
    final code = room!.roomCode.trim();
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return 'Phòng $code';
    return 'Chưa có phòng';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showRoomDropdown(context),
      behavior: HitTestBehavior.opaque,
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
                _roomLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 18 / 14,
                ),
              ),
              if (room?.roomCode.isNotEmpty == true &&
                  room!.name.trim().isNotEmpty)
                Text(
                  'Phòng ${room!.roomCode}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 15 / 11,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.deepBlue,
            size: 18,
          ),
        ],
      ),
    );
  }

  void _showRoomDropdown(BuildContext context) {
    // Hiện popup dropdown danh sách phòng tài khoản đã thuê.
    // TODO: lấy danh sách phòng từ API. Hiện tại dùng phòng hiện tại làm placeholder.
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

    final items = room == null
        ? <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              enabled: false,
              child: Text(
                'Chưa có phòng nào',
                style: TextStyle(color: AppColors.bodyText, fontSize: 13),
              ),
            ),
          ]
        : <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: room!.id?.toString() ?? '',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room!.name.isNotEmpty
                              ? room!.name
                              : 'Phòng ${room!.roomCode}',
                          style: const TextStyle(
                            color: AppColors.inputText,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (room!.roomCode.isNotEmpty)
                          Text(
                            'Mã: ${room!.roomCode}',
                            style: const TextStyle(
                              color: AppColors.bodyText,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
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
          ];

    showMenu<String>(
      context: context,
      position: position,
      items: items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 8,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final HomeUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 39,
      height: 39,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.deepBlue,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: user.avatarUrl.isEmpty
          ? const Icon(Icons.person, color: Colors.white, size: 22)
          : Image.network(
              AppConfig.apiBaseUrl + user.avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.person, color: Colors.white, size: 22),
            ),
    );
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
  const _PaymentStatusCard({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final invoice = summary.invoiceSummary;
    final hasUnpaid = invoice.unpaidCount > 0 || invoice.totalUnpaidAmount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 23, 24, 23),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAE8EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Trạng thái thanh toán',
                  style: TextStyle(
                    color: AppColors.inputText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 20 / 15,
                  ),
                ),
              ),
              _PaymentBadge(isUnpaid: hasUnpaid),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            invoice.nearestDueDate == null
                ? 'Chưa có hạn thanh toán'
                : 'Hạn: ${_formatDate(invoice.nearestDueDate!)}',
            style: const TextStyle(
              color: AppColors.bodyText,
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
                  _formatAmount(invoice.totalUnpaidAmount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 36 / 30,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text(
                  '/ tháng',
                  style: TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 20 / 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: hasUnpaid
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const BillSelectionPage(),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                disabledBackgroundColor: AppColors.deepBlue.withValues(
                  alpha: 0.42,
                ),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Text(
                'Thanh toán ngay',
                style: TextStyle(
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
  const _PaymentBadge({required this.isUnpaid});

  final bool isUnpaid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      decoration: BoxDecoration(
        color: isUnpaid ? const Color(0xFFD4F8DE) : const Color(0xFFE7E9F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isUnpaid ? 'Chưa thanh toán' : 'Đã thanh toán',
        style: TextStyle(
          color: isUnpaid ? const Color(0xFF159447) : AppColors.bodyText,
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
          iconColor: const Color(0xFFE8A100),
          iconBackground: const Color(0xFFFCF8E9),
        ),
        const SizedBox(height: 16),
        _UtilityCard(
          usage: utilities.water,
          title: 'Nước',
          unit: 'm³',
          icon: Icons.water_drop_outlined,
          iconColor: const Color(0xFF1F78FF),
          iconBackground: const Color(0xFFEFF6FF),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9E7EA)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(8),
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
                        text:
                            ' ${usage?.unit.isNotEmpty == true ? usage!.unit : unit}',
                        style: const TextStyle(
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
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.inputText,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        height: 24 / 20,
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.42,
      children: [
        _QuickActionButton(
          icon: Icons.rule_folder_outlined,
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
          icon: Icons.article_outlined,
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
          icon: Icons.warning_amber_rounded,
          label: 'Báo cáo sự cố',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CreateMaintenanceTicketScreen(),
              ),
            );
          },
        ),
        _QuickActionButton(
          icon: Icons.assignment_late_outlined,
          label: 'Danh sách sự cố',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MaintenanceTicketListScreen(),
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 98,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.deepBlue, size: 30),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 16 / 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBottomNavigation extends StatelessWidget {
  const _HomeBottomNavigation({
    required this.authService,
    required this.homeService,
    required this.profileService,
  });

  final AuthService authService;
  final HomeService homeService;
  final TenantProfileService profileService;

  Future<void> _handleLogout(BuildContext context) async {
    await authService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => LoginPage(
          authService: authService,
          homeService: homeService,
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
            builder: (context) => TenantProfileScreen(
              authService: authService,
              homeService: homeService,
              profileService: profileService,
            ),
          ),
        );
      },
      onLogoutTap: () => _handleLogout(context),
    );
  }
}

void _showTodo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
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
