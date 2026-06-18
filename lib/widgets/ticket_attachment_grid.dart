import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/maintenance/maintenance_ticket_model.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

class TicketAttachmentGrid extends StatelessWidget {
  const TicketAttachmentGrid({
    super.key,
    required this.attachments,
    required this.emptyText,
    this.onAttachmentError,
  });

  final List<TicketAttachment> attachments;
  final String emptyText;
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
    required this.onAttachmentError,
  });

  final TicketAttachment attachment;
  final VoidCallback? onAttachmentError;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPreview(context),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (attachment.isImage)
                Image.network(
                  attachment.url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      onAttachmentError?.call();
                    });
                    return const _AttachmentPlaceholder();
                  },
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
          onAttachmentError: onAttachmentError,
        ),
      ),
    );
  }
}

class _AttachmentPreviewScreen extends StatelessWidget {
  const _AttachmentPreviewScreen({
    required this.attachment,
    required this.onAttachmentError,
  });

  final TicketAttachment attachment;
  final VoidCallback? onAttachmentError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          attachment.name.isEmpty ? 'File đính kèm' : attachment.name,
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
                  child: Image.network(
                    attachment.url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        onAttachmentError?.call();
                      });
                      return const _PreviewPlaceholder();
                    },
                  ),
                )
              : const _PreviewVideoPlaceholder(),
        ),
      ),
    );
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
        borderRadius: BorderRadius.circular(8),
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
              'Không tải được file đính kèm',
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
          colors: [Color(0xFF111827), Color(0xFF374151)],
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
        'Không tải được file đính kèm',
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
            'Video đính kèm',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
