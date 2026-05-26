// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

Widget buildPlatformPdfViewer({
  required BuildContext context,
  required String pdfUrl,
  required String title,
}) {
  return WebPdfViewer(pdfUrl: pdfUrl, title: title);
}

class WebPdfViewer extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const WebPdfViewer({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<WebPdfViewer> createState() => _WebPdfViewerState();
}

class _WebPdfViewerState extends State<WebPdfViewer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-iframe-${DateTime.now().millisecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => html.IFrameElement()
        ..src = widget.pdfUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%',
    );
  }

  void _downloadFile() {
    final anchor = html.AnchorElement(href: widget.pdfUrl)
      ..target = '_blank'
      ..download = '${widget.title.replaceAll(' ', '_')}.pdf';
    anchor.click();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.deepBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 20 / 15,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _downloadFile,
            icon: const Icon(Icons.download_rounded, size: 24),
            tooltip: 'Tải xuống',
          ),
        ],
      ),
      body: HtmlElementView(
        viewType: _viewType,
      ),
    );
  }
}
