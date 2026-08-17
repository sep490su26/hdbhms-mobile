import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/widgets/app_empty_state.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/contract/handover_item_model.dart';
import 'package:hdbhms_mobile/models/contract/handover_record_model.dart';
import 'package:hdbhms_mobile/screens/notification/notification_list_screen.dart';
import 'package:hdbhms_mobile/services/contract/handover_service.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/image_zoom_viewer.dart';
import 'package:hdbhms_mobile/widgets/app_notification_bell.dart';

/// Màn hình liệt kê tiện ích / đồ dùng có sẵn trong phòng
class RoomAmenitiesScreen extends StatefulWidget {
  const RoomAmenitiesScreen({
    super.key,
    this.contractId,
    this.handoverService = const HandoverService(),
    this.leaseContractService = const LeaseContractService(),
  });

  /// Nếu null, sẽ tự fetch active contract để lấy contractId
  final int? contractId;
  final HandoverService handoverService;
  final LeaseContractService leaseContractService;

  @override
  State<RoomAmenitiesScreen> createState() => _RoomAmenitiesScreenState();
}

class _RoomAmenitiesScreenState extends State<RoomAmenitiesScreen> {
  late Future<HandoverRecord> _handoverFuture;

  @override
  void initState() {
    super.initState();
    _handoverFuture = _load();
  }

  Future<HandoverRecord> _load() async {
    var contractId = widget.contractId;
    if (contractId == null || contractId <= 0) {
      // Fetch active contract to get contractId
      final contract = await widget.leaseContractService.getMyActiveContract();
      contractId = contract.id;
    }
    if (contractId == null) {
      throw const HandoverNotFoundException();
    }
    return widget.handoverService.getHandoverItems(contractId);
  }

  void _retry() {
    setState(() {
      _handoverFuture = _load();
    });
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _handoverFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _AmenitiesHeader(),
          Expanded(
            child: FutureBuilder<HandoverRecord>(
              future: _handoverFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _AmenitiesLoadingState();
                }

                if (snapshot.hasError) {
                  final error = snapshot.error;
                  if (error is HandoverNotFoundException) {
                    return _AmenitiesEmptyState(onRetry: _retry);
                  }
                  return _AmenitiesErrorState(
                    message: _messageForError(error),
                    onRetry: _retry,
                  );
                }

                final record = snapshot.data;
                if (record == null || record.items.isEmpty) {
                  return _AmenitiesEmptyState(onRetry: _retry);
                }

                return RefreshIndicator(
                  color: AppColors.deepBlue,
                  onRefresh: _refresh,
                  child: _AmenitiesContent(record: record),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _AmenitiesHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: AppColors.topBarHeight,
        padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
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
              child: Text('Tiện ích phòng', style: AppColors.topBarTitleStyle),
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
      ),
    );
  }
}

// ── Content ───────────────────────────────────────────────────────────────────

class _AmenitiesContent extends StatelessWidget {
  const _AmenitiesContent({required this.record});

  final HandoverRecord record;

  @override
  Widget build(BuildContext context) {
    final items = record.items;
    final goodCount = items
        .where((i) => i.conditionStatus.toUpperCase() == 'GOOD')
        .length;
    final totalCount = items.length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        if (record.isFromCache) ...[
          _OfflineBanner(),
          const SizedBox(height: 14),
        ],
        // Summary card
        _SummaryCard(goodCount: goodCount, totalCount: totalCount),
        const SizedBox(height: 20),
        // Section heading
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Text(
                'Danh sách đồ dùng & tiện ích',
                style: TextStyle(
                  color: AppColors.inputText,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 20 / 15,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.deepBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
                ),
                child: Text(
                  '$totalCount mục',
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Item list
        for (var i = 0; i < items.length; i++) ...[
          _AmenityCard(item: items[i], index: i),
          if (i < items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.goodCount, required this.totalCount});

  final int goodCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final ratio = totalCount == 0 ? 0.0 : goodCount / totalCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.heroGradientStart,
            AppColors.deepBlue,
            Color(0xFF1A4A8A),
          ],
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(
              Icons.meeting_room_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TỔNG QUAN TIỆN ÍCH',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$goodCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: '/$totalCount mục tốt',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.success,
                    ),
                    minHeight: 5,
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

// ── Amenity Card ──────────────────────────────────────────────────────────────

class _AmenityCard extends StatelessWidget {
  const _AmenityCard({required this.item, required this.index});

  final HandoverItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl(item);
    final conditionNorm = item.conditionStatus.trim().toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Index badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.deepBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.assetName.trim().isEmpty
                            ? 'Thiết bị'
                            : item.assetName.trim(),
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 20 / 15,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (item.assetCategory.trim().isNotEmpty)
                            _AssetMetaChip(
                              icon: Icons.category_outlined,
                              label: _assetCategoryLabel(item.assetCategory),
                            ),
                          _AssetMetaChip(
                            icon: Icons.inventory_2_outlined,
                            label: 'Số lượng: ${item.quantity}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ConditionChip(status: conditionNorm),
              ],
            ),
          ),
          // Note
          if (item.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notes_rounded,
                      size: 14,
                      color: AppColors.bodyText,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        item.note.trim(),
                        style: const TextStyle(
                          color: AppColors.bodyText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 17 / 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Image
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: imageUrl.isEmpty
                ? const _NoImagePlaceholder()
                : _EvidenceThumbnail(imageUrl: imageUrl, title: item.assetName),
          ),
        ],
      ),
    );
  }
}

// ── Condition Chip ────────────────────────────────────────────────────────────

class _AssetMetaChip extends StatelessWidget {
  const _AssetMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.bodyText),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 15 / 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'GOOD' => ('Tốt', const Color(0xFF0B7A3B), const Color(0xFFE1F4E8)),
      'ATTENTION' => (
        'Lưu ý',
        const Color(0xFF9A6400),
        const Color(0xFFFFF1CC),
      ),
      'BROKEN' => ('Hỏng', const Color(0xFFB00020), const Color(0xFFFFE1E1)),
      'MISSING' => ('Thiếu', const Color(0xFF5F6368), const Color(0xFFE8EAED)),
      _ => ('N/A', AppColors.deepBlue, const Color(0xFFE6E8FF)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 14 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Evidence Thumbnail ────────────────────────────────────────────────────────

class _EvidenceThumbnail extends StatelessWidget {
  const _EvidenceThumbnail({required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Material(
        color: const Color(0xFFE7E9F0),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ImageZoomViewer(imageUrl: imageUrl, title: title),
            ),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: AuthenticatedImage(
              url: imageUrl,
              fit: BoxFit.cover,
              placeholder: const _ImageSkeleton(),
              errorPlaceholder: const _NoImagePlaceholder(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty / Error / Loading ───────────────────────────────────────────────────

class _AmenitiesLoadingState extends StatelessWidget {
  const _AmenitiesLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Skeleton summary card
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFFE3E8EF),
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
          ),
        ),
        const SizedBox(height: 20),
        for (int i = 0; i < 3; i++) ...[
          _LoadingCard(),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7E9F0),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonLine(widthFactor: 0.6, height: 15),
                    const SizedBox(height: 6),
                    _SkeletonLine(widthFactor: 0.3, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            child: const AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(color: Color(0xFFE7E9F0)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenitiesEmptyState extends StatelessWidget {
  const _AmenitiesEmptyState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.weekend_outlined,
    title: 'Ph\u00F2ng ch\u01B0a c\u00F3 th\u00F4ng tin ti\u1EC7n \u00EDch',
    description:
        'Danh s\u00E1ch \u0111\u1ED3 d\u00F9ng b\u00E0n giao s\u1EBD hi\u1EC3n th\u1ECB t\u1EA1i \u0111\u00E2y',
    actionLabel: 'Th\u1EED l\u1EA1i',
    actionIcon: Icons.refresh_rounded,
    onAction: onRetry,
    scrollable: true,
    onRefresh: () async => onRetry(),
  );
}

class _AmenitiesErrorState extends StatelessWidget {
  const _AmenitiesErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.cloud_off_rounded,
      iconColor: AppColors.bodyText,
      title: message,
      subtitle: 'Kéo xuống hoặc nhấn thử lại để tải dữ liệu',
      buttonLabel: 'Thử lại',
      onRetry: onRetry,
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onRetry,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
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
          const SizedBox(height: 80),
          Container(
            width: 72,
            height: 72,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 36),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 22 / 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 18 / 13,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Misc Widgets ──────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1CC),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: const Color(0xFFE0A100)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Color(0xFF9A6400), size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đang hiển thị dữ liệu offline',
              style: TextStyle(
                color: Color(0xFF7A4F00),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoImagePlaceholder extends StatelessWidget {
  const _NoImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F9),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.bodyText,
            size: 26,
          ),
          SizedBox(height: 6),
          Text(
            'Chưa có hình ảnh',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSkeleton extends StatelessWidget {
  const _ImageSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE7E9F0),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.deepBlue,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor, required this.height});
  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE7E9F0),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _resolveImageUrl(HandoverItem item) {
  final fromResponse = item.evidenceFileUrl.trim();
  if (fromResponse.isNotEmpty) {
    return _resolveUrl(fromResponse);
  }
  final fileId = item.evidenceFileId;
  if (fileId == null) return '';
  return '${ApiConfig.baseUrl}/files/download/$fileId';
}

String _resolveUrl(String value) {
  final url = value.trim();
  if (url.isEmpty) return '';
  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasScheme) return url;

  final baseUri = Uri.parse(ApiConfig.baseUrl);
  final origin = '${baseUri.scheme}://${baseUri.authority}';
  if (url.startsWith('/api/')) return '$origin$url';
  if (url.startsWith('/')) return '${ApiConfig.baseUrl}$url';
  return '${ApiConfig.baseUrl}/$url';
}

String _assetCategoryLabel(String value) {
  final normalized = value.trim().toUpperCase();
  return switch (normalized) {
    'APPLIANCE' => 'Thiết bị điện',
    'ELECTRIC' || 'ELECTRICAL' || 'ELECTRICITY' => 'Đồ điện',
    'FURNITURE' => 'Nội thất',
    'SANITARY' || 'BATHROOM' || 'TOILET' => 'Vệ sinh',
    'OTHER' => 'Khác',
    _ => 'Khác',
  };
}

String _messageForError(Object? error) {
  if (error is HandoverException) return error.message;
  return 'Không tải được danh sách tiện ích phòng';
}
