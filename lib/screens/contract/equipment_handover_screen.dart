import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/config/api_config.dart';
import 'package:hdbhms_mobile/models/contract/handover_item_model.dart';
import 'package:hdbhms_mobile/models/contract/handover_record_model.dart';
import 'package:hdbhms_mobile/services/contract/handover_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/widgets/image_zoom_viewer.dart';
import 'package:hdbhms_mobile/widgets/section_card.dart';

class EquipmentHandoverScreen extends StatefulWidget {
  const EquipmentHandoverScreen({
    super.key,
    required this.contractId,
    this.handoverService = const HandoverService(),
  });

  final int contractId;
  final HandoverService handoverService;

  @override
  State<EquipmentHandoverScreen> createState() =>
      _EquipmentHandoverScreenState();
}

class _EquipmentHandoverScreenState extends State<EquipmentHandoverScreen> {
  late Future<HandoverRecord> _handoverFuture;

  @override
  void initState() {
    super.initState();
    _handoverFuture = _load();
  }

  Future<HandoverRecord> _load() {
    return widget.handoverService.getHandoverItems(widget.contractId);
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
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.deepBlue,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Bàn giao thiết bị',
          style: AppColors.topBarTitleStyle,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: FutureBuilder<HandoverRecord>(
              future: _handoverFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _HandoverLoadingState();
                }

                if (snapshot.hasError) {
                  final error = snapshot.error;
                  if (error is HandoverNotFoundException) {
                    return _HandoverEmptyState(onRetry: _retry);
                  }
                  return _HandoverErrorState(
                    message: _messageForError(error),
                    onRetry: _retry,
                  );
                }

                final record = snapshot.data;
                if (record == null || record.items.isEmpty) {
                  return _HandoverEmptyState(onRetry: _retry);
                }

                return RefreshIndicator(
                  color: AppColors.deepBlue,
                  onRefresh: _refresh,
                  child: _HandoverContent(record: record),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HandoverContent extends StatelessWidget {
  const _HandoverContent({required this.record});

  final HandoverRecord record;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        if (record.isFromCache) ...[
          const _OfflineBanner(),
          const SizedBox(height: 12),
        ],
        for (var index = 0; index < record.items.length; index++) ...[
          _EquipmentCard(item: record.items[index]),
          if (index < record.items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({required this.item});

  final HandoverItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl(item);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.assetName.trim().isEmpty
                      ? 'Thiết bị'
                      : item.assetName.trim(),
                  style: const TextStyle(
                    color: AppColors.inputText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 20 / 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _ConditionBadge(status: item.conditionStatus),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: AppColors.bodyText,
              ),
              const SizedBox(width: 7),
              Text(
                'Số lượng: ${item.quantity}',
                style: const TextStyle(
                  color: AppColors.bodyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (item.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.note.trim(),
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 18 / 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (imageUrl.isEmpty)
            const _NoImagePlaceholder()
          else
            _EvidenceThumbnail(imageUrl: imageUrl, title: item.assetName),
        ],
      ),
    );
  }
}

class _EvidenceThumbnail extends StatelessWidget {
  const _EvidenceThumbnail({required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE7E9F0),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
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
    );
  }
}

class _ConditionBadge extends StatelessWidget {
  const _ConditionBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();
    final color = switch (normalized) {
      'GOOD' => const Color(0xFF0B7A3B),
      'ATTENTION' => const Color(0xFF9A6400),
      'BROKEN' => const Color(0xFFB00020),
      'MISSING' => const Color(0xFF5F6368),
      _ => AppColors.deepBlue,
    };
    final background = switch (normalized) {
      'GOOD' => const Color(0xFFE1F4E8),
      'ATTENTION' => const Color(0xFFFFF1CC),
      'BROKEN' => const Color(0xFFFFE1E1),
      'MISSING' => const Color(0xFFE8EAED),
      _ => const Color(0xFFE6E8FF),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _conditionLabel(normalized),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 14 / 11,
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1CC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0A100)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Color(0xFF9A6400), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dữ liệu offline',
              style: TextStyle(
                color: Color(0xFF7A4F00),
                fontSize: 13,
                fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.fromLTRB(14, 26, 14, 26),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E9F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined, color: AppColors.bodyText),
          SizedBox(height: 8),
          Text(
            'Chưa có ảnh',
            style: TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HandoverLoadingState extends StatelessWidget {
  const _HandoverLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: const [
        _LoadingCard(),
        SizedBox(height: 12),
        _LoadingCard(),
        SizedBox(height: 12),
        _LoadingCard(),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonLine(widthFactor: 0.7, height: 18),
          const SizedBox(height: 12),
          const _SkeletonLine(widthFactor: 0.45, height: 14),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
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
          borderRadius: BorderRadius.circular(6),
        ),
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
        child: CircularProgressIndicator(color: AppColors.deepBlue),
      ),
    );
  }
}

class _HandoverEmptyState extends StatelessWidget {
  const _HandoverEmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.inventory_2_outlined,
      title: 'Chưa có thông tin thiết bị bàn giao',
      buttonLabel: 'Thử lại',
      onRetry: onRetry,
    );
  }
}

class _HandoverErrorState extends StatelessWidget {
  const _HandoverErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      icon: Icons.error_outline_rounded,
      title: message,
      buttonLabel: 'Thử lại',
      onRetry: onRetry,
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.buttonLabel,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
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
          const SizedBox(height: 120),
          Icon(icon, color: AppColors.deepBlue, size: 46),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 20 / 15,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(buttonLabel),
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

String _imageUrl(HandoverItem item) {
  final fromResponse = item.evidenceFileUrl.trim();
  if (fromResponse.isNotEmpty) {
    return _resolveResourceUrl(fromResponse);
  }
  final fileId = item.evidenceFileId;
  if (fileId == null) {
    return '';
  }
  return '${ApiConfig.baseUrl}/files/download/$fileId';
}

String _resolveResourceUrl(String value) {
  final url = value.trim();
  if (url.isEmpty) {
    return '';
  }
  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasScheme) {
    return url;
  }

  final baseUri = Uri.parse(ApiConfig.baseUrl);
  final origin = '${baseUri.scheme}://${baseUri.authority}';
  if (url.startsWith('/api/')) {
    return '$origin$url';
  }
  if (url.startsWith('/')) {
    return '${ApiConfig.baseUrl}$url';
  }
  return '${ApiConfig.baseUrl}/$url';
}

String _conditionLabel(String status) {
  return switch (status) {
    'GOOD' => 'Tốt',
    'ATTENTION' => 'Cần lưu ý',
    'BROKEN' => 'Hỏng',
    'MISSING' => 'Thiếu',
    _ => status.isEmpty ? 'Chưa cập nhật' : status,
  };
}

String _messageForError(Object? error) {
  if (error is HandoverException) {
    return error.message;
  }
  return 'Không tải được dữ liệu bàn giao';
}
