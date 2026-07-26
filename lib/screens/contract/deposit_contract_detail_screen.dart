import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_request_screen.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/contract/contract_list_item_model.dart';
import 'package:hdbhms_mobile/services/contract/deposit_contract_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/utils/currency_formatter.dart';
import 'package:hdbhms_mobile/utils/document_filename.dart';
import 'package:hdbhms_mobile/widgets/tenant_bottom_navigation.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';
import 'package:hdbhms_mobile/screens/payment/bill_selection_page.dart';
import 'package:hdbhms_mobile/screens/contract/contract_pdf_viewer_screen.dart';
import 'package:hdbhms_mobile/screens/maintenance/maintenance_ticket_list_screen.dart';
import 'package:hdbhms_mobile/screens/profile_request/tenant_profile_screen.dart';

class DepositContractDetailScreen extends StatefulWidget {
  const DepositContractDetailScreen({
    super.key,
    required this.depositId,
    this.depositService = const DepositContractService(),
  });

  final int depositId;
  final DepositContractService depositService;

  @override
  State<DepositContractDetailScreen> createState() =>
      _DepositContractDetailScreenState();
}

class _DepositContractDetailScreenState
    extends State<DepositContractDetailScreen> {
  late Future<DepositContract> _depositFuture;

  @override
  void initState() {
    super.initState();
    _depositFuture = _load();
  }

  Future<DepositContract> _load() {
    return widget.depositService.getDepositById(widget.depositId);
  }

  void _retry() {
    setState(() {
      _depositFuture = _load();
    });
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _depositFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(
          header: const _DetailHeader(),
          child: FutureBuilder<DepositContract>(
            future: _depositFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.deepBlue),
                );
              }

              if (snapshot.hasError) {
                return _ErrorState(
                  message: _errorMessage(snapshot.error),
                  onRetry: _retry,
                );
              }

              final deposit = snapshot.data;
              if (deposit == null) {
                return _ErrorState(
                  message: 'Không tìm thấy HĐ cọc',
                  onRetry: _retry,
                );
              }

              return RefreshIndicator(
                color: AppColors.deepBlue,
                onRefresh: _refresh,
                child: _DepositContent(deposit: deposit),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const _DepositBottomNavigation(),
    );
  }

  String _errorMessage(Object? error) {
    if (error is DepositContractException) return error.message;
    return 'Không tải được dữ liệu HĐ cọc';
  }
}

// ── Header ──

class _DetailHeader extends StatelessWidget {
  const _DetailHeader();

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
            child: Text('Thông tin HĐ cọc', style: AppColors.topBarTitleStyle),
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

// ── Content ──

class _DepositContent extends StatelessWidget {
  const _DepositContent({required this.deposit});

  final DepositContract deposit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoomHeroCard(deposit: deposit),
          const SizedBox(height: 12),
          _DepositInfoGrid(deposit: deposit),
          const SizedBox(height: 12),
          _DocumentSection(
            contractFileUrl: deposit.contractFileUrl,
            suggestedFilename: buildDocumentFilename(
              documentType: 'HDC',
              roomCode: deposit.room.roomCode,
              date: deposit.expectedMoveInDate,
            ),
          ),
          if (deposit.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NoteSection(note: deposit.note),
          ],
        ],
      ),
    );
  }
}

// ── Room Hero Card ──

class _RoomHeroCard extends StatelessWidget {
  const _RoomHeroCard({required this.deposit});

  final DepositContract deposit;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveResourceUrl(deposit.room.imageUrl);
    final roomName = _roomTitle(deposit.room);
    final hasImage = imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: real photo or abstract gradient banner
            if (hasImage)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _ModernRoomBannerBg(),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const _ModernRoomBannerBg(),
              )
            else
              const _ModernRoomBannerBg(),
            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: hasImage ? 0.08 : 0.3),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
            // Content
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusBadge(status: deposit.status),
                        const SizedBox(height: 8),
                        Text(
                          roomName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppColors.radiusPill),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      _formatMoney(deposit.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Top-right: room code chip
            if (deposit.room.roomCode.trim().isNotEmpty)
              Positioned(
                top: 14,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    '#${deposit.room.roomCode.trim()}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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

/// Abstract gradient background – Gen-Z / Airbnb inspired.
class _ModernRoomBannerBg extends StatelessWidget {
  const _ModernRoomBannerBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.deepBlue,
            AppColors.darkBlue,
            Color(0xFF1A4A8A),
            AppColors.primary,
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0891B2).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 100,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.apartment_rounded,
              color: Colors.white24,
              size: 72,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFA7B4FF),
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        _statusLabel(status),
        style: const TextStyle(
          color: AppColors.deepBlue,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 13 / 10,
        ),
      ),
    );
  }
}

// ── Info Grid ──

class _DepositInfoGrid extends StatelessWidget {
  const _DepositInfoGrid({required this.deposit});

  final DepositContract deposit;

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoGridItem(label: 'Mã HĐ cọc', value: deposit.depositCode),
      _InfoGridItem(label: 'Mã phòng', value: deposit.room.roomCode),
      _InfoGridItem(label: 'Số tiền cọc', value: _formatMoney(deposit.amount)),
      _InfoGridItem(label: 'Trạng thái', value: _statusLabel(deposit.status)),
      _InfoGridItem(
        label: 'Ngày dọn vào (DK)',
        value: _formatDate(deposit.expectedMoveInDate),
      ),
      _InfoGridItem(
        label: 'Ngày ký HĐ (DK)',
        value: _formatDate(deposit.expectedLeaseSignDate),
      ),
      _InfoGridItem(
        label: 'HĐ cọc hết hạn',
        value: _formatDate(deposit.depositExpiresAt),
      ),
      _InfoGridItem(label: 'Ngày tạo', value: _formatDate(deposit.createdAt)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.9,
          crossAxisSpacing: 14,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

class _InfoGridItem extends StatelessWidget {
  const _InfoGridItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.bodyText,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 13 / 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _display(value),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 17 / 13,
          ),
        ),
      ],
    );
  }
}

// ── Document Section ──

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.contractFileUrl,
    required this.suggestedFilename,
  });

  final String contractFileUrl;
  final String suggestedFilename;

  @override
  Widget build(BuildContext context) {
    final url = _resolveResourceUrl(contractFileUrl);

    return _SectionCard(
      title: 'Quản lý tài liệu',
      child: url.isEmpty
          ? const _MutedText('Chưa có tài liệu hợp đồng cọc')
          : SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showFile(context, url, suggestedFilename),
                icon: const Icon(Icons.description_outlined, size: 20),
                label: const Text('Xem HĐ cọc'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Note Section ──

class _NoteSection extends StatelessWidget {
  const _NoteSection({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Ghi chú',
      icon: Icons.notes_rounded,
      child: Text(
        note,
        style: const TextStyle(
          color: AppColors.bodyText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 18 / 13,
        ),
      ),
    );
  }
}

// ── Shared widgets ──

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.icon});

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.deepBlue, size: 19),
                const SizedBox(width: 7),
              ],
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
              Icons.error_outline_rounded,
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

// ── Helpers ──

void _showFile(BuildContext context, String url, String suggestedFilename) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ContractPdfViewerScreen(
        pdfUrl: url,
        title: 'Hợp đồng cọc',
        suggestedFilename: suggestedFilename,
      ),
    ),
  );
}

String _display(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? 'Chưa cập nhật' : trimmed;
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Chưa cập nhật';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatMoney(num? amount) {
  if (amount == null) return 'Chưa cập nhật';
  return CurrencyFormatter.vnd(amount).replaceAll(' đ', 'đ');
}

String _roomTitle(DepositRoom room) {
  if (room.roomName.trim().isNotEmpty) return room.roomName.trim();
  if (room.roomCode.trim().isNotEmpty) return 'Phòng ${room.roomCode.trim()}';
  return 'Phòng cọc';
}

String _statusLabel(String status) {
  return switch (status.trim().toUpperCase()) {
    'CONFIRMED' => 'Đã xác nhận',
    'PAID' => 'Đã thanh toán',
    'PENDING_PAYMENT' => 'Chờ thanh toán',
    'DRAFT' => 'Bản nháp',
    'CONVERTED_TO_LEASE' => 'Đã chuyển HĐ thuê',
    'EXTENDED' => 'Đã gia hạn',
    'REFUNDED' => 'Đã hoàn tiền',
    'FORFEITED' => 'Đã mất cọc',
    'CANCELLED' => 'Đã hủy',
    _ => 'Chưa cập nhật',
  };
}

String _resolveResourceUrl(String value) {
  final url = value.trim();
  if (url.isEmpty) return '';
  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasScheme) return url;

  final baseUri = Uri.parse(ApiConfig.baseUrl);
  if (url.startsWith('/')) return baseUri.replace(path: url).toString();
  final base = ApiConfig.baseUrl.endsWith('/')
      ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
      : ApiConfig.baseUrl;
  return '$base/$url';
}

// ── Bottom Navigation ──

class _DepositBottomNavigation extends StatelessWidget {
  const _DepositBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return TenantBottomNavigation(
      activeTab: TenantBottomNavTab.home,
      onHomeTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      onSupportTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const MaintenanceTicketListScreen(),
          ),
        );
      },
      onBillsTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const BillSelectionPage()),
        );
      },
      onProfileTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const TenantProfileScreen()),
        );
      },
      onRequestsTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const TenantRequestScreen()),
      ),
    );
  }
}
