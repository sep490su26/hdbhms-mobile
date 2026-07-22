import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/profile_request/tenant_profile_model.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/app_action_tile.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/contract/lease_contract_list_screen.dart';
import 'package:hdbhms_mobile/screens/auth/change_password_page.dart';
import 'package:hdbhms_mobile/screens/auth/login_page.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/update_profile_screen.dart';

class TenantProfileScreen extends StatefulWidget {
  const TenantProfileScreen({
    super.key,
    this.profileService = const TenantProfileService(),
    this.authService = const AuthService(),
    this.homeService = const HomeService(),
    this.showBottomNavigation = true,
  });

  final TenantProfileService profileService;
  final AuthService authService;
  final HomeService homeService;
  final bool showBottomNavigation;

  @override
  State<TenantProfileScreen> createState() => _TenantProfileScreenState();
}

class _TenantProfileScreenState extends State<TenantProfileScreen> {
  late Future<TenantProfileResponse> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<TenantProfileResponse> _loadProfile() {
    return widget.profileService.getMyProfile();
  }

  Future<void> _refresh() async {
    final future = _loadProfile();
    setState(() {
      _profileFuture = future;
    });
    await future;
  }

  Future<void> _handleLogout() async {
    await widget.authService.logout();
    if (!mounted) {
      return;
    }
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

  Future<void> _openChangePassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ChangePasswordPage(
          authService: widget.authService,
          homeService: widget.homeService,
        ),
      ),
    );

    if (!mounted || changed != true) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _ProfileHeader(
              onBack: widget.showBottomNavigation
                  ? () =>
                        Navigator.of(context).popUntil((route) => route.isFirst)
                  : () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: Column(
                    children: [
                      Expanded(
                        child: FutureBuilder<TenantProfileResponse>(
                          future: _profileFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              final error = snapshot.error;
                              return _ProfileErrorState(
                                message: _messageForError(error),
                                onRetry: () {
                                  setState(() {
                                    _profileFuture = _loadProfile();
                                  });
                                },
                              );
                            }

                            final profile = snapshot.data;
                            if (profile == null) {
                              return _ProfileErrorState(
                                message: 'Chưa có hồ sơ cá nhân',
                                onRetry: () {
                                  setState(() {
                                    _profileFuture = _loadProfile();
                                  });
                                },
                              );
                            }

                            return RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: _refresh,
                              child: _ProfileContent(
                                profile: profile,
                                onProfileUpdated: _refresh,
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                        child: Column(
                          children: [
                            _ChangePasswordButton(
                              onChangePassword: _openChangePassword,
                            ),
                            const SizedBox(height: 10),
                            _LogoutButton(onLogout: _handleLogout),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? Builder(
              builder: (ctx) => TenantBottomNavigation(
                activeTab: TenantBottomNavTab.profile,
                onHomeTap: () =>
                    Navigator.of(ctx).popUntil((route) => route.isFirst),
                onBillsTap: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (context) => const BillSelectionPage(),
                    ),
                  );
                },
                onSupportTap: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (context) => const MaintenanceTicketListScreen(),
                    ),
                  );
                },
                onProfileTap: () {},
                onRequestsTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TenantRequestScreen(),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.onBack});

  final VoidCallback onBack;

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
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text('Hồ sơ cá nhân', style: AppColors.topBarTitleStyle),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: const AppNotificationBell(
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

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.onProfileUpdated,
  });

  final TenantProfileResponse profile;
  final Future<void> Function() onProfileUpdated;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileSummaryCard(profile: profile),
          const SizedBox(height: 16),
          const _ContractEntrySection(),
          const SizedBox(height: 16),
          _InfoSectionCard(
            icon: Icons.badge_outlined,
            title: 'Thông tin cá nhân',
            children: [
              _ReadOnlyField(
                label: 'Họ và tên',
                value: profile.person.fullName,
              ),
              _ReadOnlyField(label: 'SĐT', value: profile.person.phone),
              _ReadOnlyField(label: 'Email', value: profile.person.email),
              _ReadOnlyField(
                label: 'Địa chỉ thường trú',
                value: profile.person.permanentAddress,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _IdentitySection(document: profile.identityDocument),
          const SizedBox(height: 16),
          _EmergencyContactsSection(contacts: profile.emergencyContacts),
          const SizedBox(height: 16),
          _VehiclesSection(vehicles: profile.vehicles),
          const SizedBox(height: 16),
          _UpdateProfileButton(
            profile: profile,
            onProfileUpdated: onProfileUpdated,
          ),
          // const SizedBox(height: 16),
          // _LogoutButton(onLogout: onLogout),
        ],
      ),
    );
  }
}

class _UpdateProfileButton extends StatelessWidget {
  const _UpdateProfileButton({
    required this.profile,
    required this.onProfileUpdated,
  });

  final TenantProfileResponse profile;
  final Future<void> Function() onProfileUpdated;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () async {
          final updated = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => UpdateProfileScreen(profile: profile),
            ),
          );
          if (updated == true) {
            await onProfileUpdated();
          }
        },
        icon: const Icon(Icons.edit_note_rounded, size: 20),
        label: const Text('Cập nhật hồ sơ'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.72),
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 18 / 14,
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onLogout,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Đăng xuất'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          backgroundColor: const Color(0xFFFFF1F2),
          side: const BorderSide(color: Color(0xFFFCA5A5)),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 18 / 14,
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordButton extends StatelessWidget {
  const _ChangePasswordButton({required this.onChangePassword});

  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onChangePassword,
        icon: const Icon(Icons.lock_reset_rounded, size: 20),
        label: const Text('Đổi mật khẩu'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.72),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.24)),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 18 / 14,
          ),
        ),
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.profile});

  final TenantProfileResponse profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: _cardDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF061827), AppColors.deepBlue, AppColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _display(profile.person.fullName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 22 / 17,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.apartment_outlined,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                profile.status.isEmpty ? 'Chưa cập nhật' : profile.status,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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

class _ContractEntrySection extends StatelessWidget {
  const _ContractEntrySection();

  @override
  Widget build(BuildContext context) {
    return _InfoSectionCard(
      icon: Icons.description_outlined,
      title: 'Hợp đồng thuê phòng',
      children: [
        AppActionRowButton(
          icon: Icons.description_rounded,
          title: 'Xem danh sách hợp đồng',
          subtitle: 'Hợp đồng thuê, cọc và tài liệu liên quan',
          accentColor: AppColors.accent,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const LeaseContractListScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.document});

  final IdentityDocumentDto? document;

  @override
  Widget build(BuildContext context) {
    return _InfoSectionCard(
      icon: Icons.credit_card_rounded,
      title: 'Giấy tờ tùy thân',
      children: [
        _ReadOnlyField(label: 'Loại giấy tờ', value: document?.docType ?? ''),
        _ReadOnlyField(label: 'Số giấy tờ', value: document?.docNumber ?? ''),
        _ReadOnlyField(
          label: 'Ngày cấp',
          value: document?.issuedDate == null
              ? ''
              : _formatDate(document!.issuedDate!),
        ),
        _ReadOnlyField(label: 'Nơi cấp', value: document?.issuedPlace ?? ''),
        const SizedBox(height: 8),
        _IdentityDocumentImages(document: document),
      ],
    );
  }
}

class _IdentityDocumentImages extends StatelessWidget {
  const _IdentityDocumentImages({required this.document});

  final IdentityDocumentDto? document;

  @override
  Widget build(BuildContext context) {
    final frontUrl = document?.frontFileUrl ?? '';
    final backUrl = document?.backFileUrl ?? '';

    if (frontUrl.isEmpty && backUrl.isEmpty) {
      return const _EmptyText('Chưa có ảnh CCCD');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (frontUrl.isNotEmpty) ...[
          const _ImageLabel('Ảnh CCCD mặt trước'),
          const SizedBox(height: 12),
          _TenantProfileImage(
            imageUrl: frontUrl,
            title: 'CCCD mặt trước',
            fallbackText: 'Không tải được ảnh CCCD',
          ),
        ],
        if (backUrl.isNotEmpty) ...[
          if (frontUrl.isNotEmpty) const SizedBox(height: 22),
          const _ImageLabel('Ảnh CCCD mặt sau'),
          const SizedBox(height: 12),
          _TenantProfileImage(
            imageUrl: backUrl,
            title: 'CCCD mặt sau',
            fallbackText: 'Không tải được ảnh CCCD',
          ),
        ],
      ],
    );
  }
}

class _ImageLabel extends StatelessWidget {
  const _ImageLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.bodyText,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 14 / 10,
        ),
      ),
    );
  }
}

class _TenantProfileImage extends StatefulWidget {
  const _TenantProfileImage({
    required this.imageUrl,
    required this.title,
    this.fallbackText = 'Không tải được ảnh',
  });

  final String imageUrl;
  final String title;
  final String fallbackText;

  @override
  State<_TenantProfileImage> createState() => _TenantProfileImageState();
}

class _TenantProfileImageState extends State<_TenantProfileImage> {
  late Future<Uint8List> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImage();
  }

  Future<Uint8List> _loadImage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AuthService.accessTokenKey);
    final response = await http.get(
      Uri.parse(widget.imageUrl),
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw const FormatException('Cannot load image');
    }
    return response.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _EmptyImage(text: widget.fallbackText);
        }

        if (!snapshot.hasData) {
          return const _LoadingImage();
        }

        return GestureDetector(
          onTap: () {
            showDialog<void>(
              context: context,
              barrierColor: Colors.transparent,
              builder: (dialogContext) => _ImageOverlayDialog(
                imageBytes: snapshot.data!,
                title: widget.title,
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.memory(snapshot.data!, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}

// ── Image Overlay Dialog (backdrop blur) ──────────────────────────────────────

class _ImageOverlayDialog extends StatefulWidget {
  const _ImageOverlayDialog({required this.imageBytes, required this.title});

  final Uint8List imageBytes;
  final String title;

  @override
  State<_ImageOverlayDialog> createState() => _ImageOverlayDialogState();
}

class _ImageOverlayDialogState extends State<_ImageOverlayDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _close() {
    _animCtrl.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Backdrop blur + dim ──────────────────────────────────────
            GestureDetector(
              onTap: _close,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: Colors.black.withValues(alpha: 0.72)),
              ),
            ),

            // ── Image viewer ──────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _close,
                          icon: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          tooltip: 'Đóng',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Zoomable image
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Hint
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Chụm để phóng to · Chạm ngoài để đóng',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

class _LoadingImage extends StatelessWidget {
  const _LoadingImage();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEDECF1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFDAD8E0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.deepBlue,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

class _EmergencyContactsSection extends StatelessWidget {
  const _EmergencyContactsSection({required this.contacts});

  final List<EmergencyContactDto> contacts;

  @override
  Widget build(BuildContext context) {
    return _InfoSectionCard(
      icon: Icons.contact_emergency_outlined,
      title: 'Thông tin người thân',
      children: contacts.isEmpty
          ? const [_EmptyText('Chưa có liên hệ khẩn cấp')]
          : [
              for (var i = 0; i < contacts.length; i++) ...[
                if (i > 0) const _InlineDivider(),
                _ReadOnlyField(label: 'Họ tên', value: contacts[i].fullName),
                _ReadOnlyField(
                  label: 'Số điện thoại',
                  value: contacts[i].phone,
                ),
              ],
            ],
    );
  }
}

class _VehiclesSection extends StatelessWidget {
  const _VehiclesSection({required this.vehicles});

  final List<VehicleDto> vehicles;

  @override
  Widget build(BuildContext context) {
    return _InfoSectionCard(
      icon: Icons.two_wheeler_rounded,
      title: 'Thông tin xe',
      children: vehicles.isEmpty
          ? const [_EmptyText('Chưa có phương tiện')]
          : [
              for (var i = 0; i < vehicles.length; i++) ...[
                if (i > 0) const _InlineDivider(),
                _ReadOnlyField(
                  label: 'Loại xe',
                  value: _vehicleTypeLabel(vehicles[i].vehicleType),
                ),
                _ReadOnlyField(
                  label: 'Biển số xe',
                  value: vehicles[i].licensePlate,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ảnh xe thực tế',
                  style: TextStyle(
                    color: AppColors.bodyText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 15 / 11,
                  ),
                ),
                const SizedBox(height: 8),
                _VehicleImage(
                  key: ValueKey('vehicle-image-${vehicles[i].id ?? i}'),
                  vehicle: vehicles[i],
                ),
              ],
            ],
    );
  }
}

class _InfoSectionCard extends StatelessWidget {
  const _InfoSectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 18, 17, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.deepBlue, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 20 / 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 14 / 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _display(value),
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 17 / 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleImage extends StatelessWidget {
  const _VehicleImage({super.key, required this.vehicle});

  final VehicleDto vehicle;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl(vehicle.imageUrl);
    if (imageUrl.isEmpty) {
      return const _EmptyImage(text: 'Chưa có ảnh phương tiện');
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VehicleImagePreviewPage(
                imageUrl: imageUrl,
                title: _display(vehicle.licensePlate),
              ),
            ),
          );
        },
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _EmptyImage(text: 'Không tải được ảnh phương tiện'),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyImage extends StatelessWidget {
  const _EmptyImage({this.text = 'Chưa có ảnh phương tiện'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEDECF1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFDAD8E0)),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class VehicleImagePreviewPage extends StatelessWidget {
  const VehicleImagePreviewPage({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Text(
              'Không tải được ảnh',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineDivider extends StatelessWidget {
  const _InlineDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Divider(color: Color(0xFFE5E5E5), height: 1),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.deepBlue,
      onRefresh: () async => onRetry(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          const Icon(
            Icons.person_search_rounded,
            color: AppColors.deepBlue,
            size: 44,
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
          Center(
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tải lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.bodyText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 18 / 13,
      ),
    );
  }
}

BoxDecoration _cardDecoration({Gradient? gradient}) {
  return BoxDecoration(
    color: gradient == null ? AppColors.surface : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: gradient == null
          ? AppColors.cardBorder
          : Colors.white.withValues(alpha: 0.18),
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.deepBlue.withValues(alpha: 0.06),
        blurRadius: 22,
        offset: const Offset(0, 11),
      ),
    ],
  );
}

String _display(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? 'Chưa cập nhật' : trimmed;
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _vehicleTypeLabel(String value) {
  return switch (value.trim().toUpperCase()) {
    'MOTORBIKE' => 'Xe máy',
    'CAR' => 'Ô tô',
    'BICYCLE' => 'Xe đạp',
    _ => _display(value),
  };
}

String _resolveImageUrl(String value) {
  final url = value.trim();
  if (url.isEmpty) {
    return '';
  }
  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasScheme) {
    return url;
  }

  final baseUri = Uri.parse(ApiConfig.baseUrl);
  if (url.startsWith('/')) {
    return baseUri.replace(path: url).toString();
  }
  final base = ApiConfig.baseUrl.endsWith('/')
      ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
      : ApiConfig.baseUrl;
  return '$base/$url';
}

String _messageForError(Object? error) {
  if (error is TenantProfileException) {
    return error.message;
  }
  return 'Không tải được hồ sơ, vui lòng thử lại';
}
