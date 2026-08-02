import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/services/file_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

class TicketAttachmentGrid extends StatelessWidget {
  const TicketAttachmentGrid({
    super.key,
    required this.attachments,
    required this.emptyText,
    this.fileService = const FileService(),
    this.onAttachmentError,
  });

  final List<TicketAttachment> attachments;
  final String emptyText;
  final FileService fileService;
  final VoidCallback? onAttachmentError;

  @override
  Widget build(BuildContext context) {
    final sorted = [...attachments]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (sorted.isEmpty) {
      return _EmptyAttachments(text: emptyText);
    }

    return Column(
      children: [
        for (var index = 0; index < sorted.length; index++) ...[
          _AttachmentTile(
            attachment: sorted[index],
            fileService: fileService,
            onAttachmentError: onAttachmentError,
          ),
          if (index < sorted.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.fileService,
    required this.onAttachmentError,
  });

  final TicketAttachment attachment;
  final FileService fileService;
  final VoidCallback? onAttachmentError;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPreview(context),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (attachment.isImage)
                _AttachmentImage(
                  attachment: attachment,
                  fileService: fileService,
                  fit: BoxFit.cover,
                  loading: const _AttachmentLoading(),
                  placeholder: const _AttachmentPlaceholder(),
                  onAttachmentError: onAttachmentError,
                )
              else
                const _VideoPlaceholder(),
              if (attachment.isVideo)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 58,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AttachmentPreviewScreen(
          attachment: attachment,
          fileService: fileService,
          onAttachmentError: onAttachmentError,
        ),
      ),
    );
  }
}

class _AttachmentPreviewScreen extends StatelessWidget {
  const _AttachmentPreviewScreen({
    required this.attachment,
    required this.fileService,
    required this.onAttachmentError,
  });

  final TicketAttachment attachment;
  final FileService fileService;
  final VoidCallback? onAttachmentError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          attachment.name.isEmpty ? 'Tệp đính kèm' : attachment.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: attachment.isImage
              ? InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: _AttachmentImage(
                    attachment: attachment,
                    fileService: fileService,
                    fit: BoxFit.contain,
                    loading: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    placeholder: const _PreviewPlaceholder(),
                    onAttachmentError: onAttachmentError,
                  ),
                )
              : const _PreviewVideoPlaceholder(),
        ),
      ),
    );
  }
}

class _AttachmentImage extends StatelessWidget {
  const _AttachmentImage({
    required this.attachment,
    required this.fileService,
    required this.fit,
    required this.loading,
    required this.placeholder,
    required this.onAttachmentError,
  });

  final TicketAttachment attachment;
  final FileService fileService;
  final BoxFit fit;
  final Widget loading;
  final Widget placeholder;
  final VoidCallback? onAttachmentError;

  @override
  Widget build(BuildContext context) {
    if (attachment.fileId > 0) {
      return FutureBuilder<Uint8List>(
        future: fileService.download(attachment.fileId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return loading;
          }
          final bytes = snapshot.data;
          if (snapshot.hasError || bytes == null || bytes.isEmpty) {
            return _errorPlaceholder();
          }
          return Image.memory(
            bytes,
            width: double.infinity,
            height: double.infinity,
            fit: fit,
          );
        },
      );
    }

    final url = attachment.url.trim();
    if (url.isEmpty) {
      return _errorPlaceholder();
    }

    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
    );
  }

  Widget _errorPlaceholder() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onAttachmentError?.call();
    });
    return placeholder;
  }
}

class _EmptyAttachments extends StatelessWidget {
  const _EmptyAttachments({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.bodyText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AttachmentLoading extends StatelessWidget {
  const _AttachmentLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE7E9F0),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.deepBlue,
          ),
        ),
      ),
    );
  }
}

class _AttachmentPlaceholder extends StatelessWidget {
  const _AttachmentPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE7E9F0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: AppColors.bodyText),
            SizedBox(height: 8),
            Text(
              'Không tải được tệp đính kèm',
              style: TextStyle(
                color: AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.neutralStrong, Color(0xFF374151)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Không tải được tệp đính kèm',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PreviewVideoPlaceholder extends StatelessWidget {
  const _PreviewVideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            color: Colors.white,
            size: 72,
          ),
          SizedBox(height: 12),
          Text(
            'Tệp video đính kèm',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
