// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/services/authenticated_client.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/utils/document_filename.dart';

Widget buildPlatformPdfViewer({
  required BuildContext context,
  required String pdfUrl,
  required String title,
  String? suggestedFilename,
}) {
  return WebPdfViewer(
    pdfUrl: pdfUrl,
    title: title,
    suggestedFilename: suggestedFilename,
  );
}

class WebPdfViewer extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final String? suggestedFilename;

  const WebPdfViewer({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.suggestedFilename,
  });

  @override
  State<WebPdfViewer> createState() => _WebPdfViewerState();
}

class _WebPdfViewerState extends State<WebPdfViewer> {
  late final String _viewType;
  late final html.IFrameElement _iframe;
  late Future<void> _loadFuture;
  String? _objectUrl;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-iframe-${DateTime.now().millisecondsSinceEpoch}';
    _iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );
    _loadFuture = _loadPdf();
  }

  Future<void> _loadPdf() async {
    final client = AuthenticatedClient();
    try {
      final response = await client
          .get(Uri.parse(widget.pdfUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('Không tải được tài liệu (${response.statusCode})');
      }

      final contentType = response.headers['content-type'] ?? 'application/pdf';
      final blob = html.Blob([response.bodyBytes], contentType);
      final objectUrl = html.Url.createObjectUrlFromBlob(blob);
      _revokeObjectUrl();
      _objectUrl = objectUrl;
      _iframe.src = objectUrl;
    } finally {
      client.close();
    }
  }

  void _retry() {
    setState(() {
      _iframe.src = 'about:blank';
      _loadFuture = _loadPdf();
    });
  }

  void _downloadFile() {
    final href = _objectUrl;
    if (href == null || _isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final anchor = html.AnchorElement(href: href)
        ..target = '_blank'
        ..download = sanitizeDownloadFilename(
          widget.suggestedFilename?.trim().isNotEmpty == true
              ? widget.suggestedFilename!
              : '${widget.title.replaceAll(' ', '_')}.pdf',
          'tai-lieu.pdf',
        );
      anchor.click();
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _revokeObjectUrl() {
    final objectUrl = _objectUrl;
    if (objectUrl != null) {
      html.Url.revokeObjectUrl(objectUrl);
      _objectUrl = null;
    }
  }

  @override
  void dispose() {
    _revokeObjectUrl();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.topBarIconColor,
        elevation: 0,
        title: Text(widget.title, style: AppColors.topBarTitleStyle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _objectUrl == null || _isDownloading
                  ? null
                  : _downloadFile,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              alignment: Alignment.center,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.topBarIconColor,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.file_download_outlined,
                      color: AppColors.topBarIconColor,
                      size: AppColors.topBarIconSize,
                    ),
              tooltip: 'Tải xuống',
            ),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.deepBlue),
                  SizedBox(height: 18),
                  Text(
                    'Đang tải tài liệu...',
                    style: TextStyle(
                      color: AppColors.bodyText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString().replaceAll('Exception: ', ''),
              onRetry: _retry,
            );
          }

          return HtmlElementView(viewType: _viewType);
        },
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
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.inputText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 20 / 15,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
