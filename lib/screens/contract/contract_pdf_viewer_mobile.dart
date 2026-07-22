import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:hdbhms_mobile/services/authenticated_client.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/utils/document_filename.dart';

Widget buildPlatformPdfViewer({
  required BuildContext context,
  required String pdfUrl,
  required String title,
  String? suggestedFilename,
}) {
  return MobilePdfViewer(
    pdfUrl: pdfUrl,
    title: title,
    suggestedFilename: suggestedFilename,
  );
}

class MobilePdfViewer extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final String? suggestedFilename;

  const MobilePdfViewer({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.suggestedFilename,
  });

  @override
  State<MobilePdfViewer> createState() => _MobilePdfViewerState();
}

class _MobilePdfViewerState extends State<MobilePdfViewer> {
  late Future<String> _pdfPathFuture;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _pdfPathFuture = _downloadToTemp();
  }

  Future<String> _downloadToTemp() async {
    final response = await _fetchPdf();

    if (response.statusCode != 200) {
      throw Exception('Không tải được tài liệu (${response.statusCode})');
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/contract_preview_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  Future<http.Response> _fetchPdf() async {
    final client = AuthenticatedClient();
    try {
      return await client
          .get(Uri.parse(widget.pdfUrl))
          .timeout(const Duration(seconds: 20));
    } finally {
      client.close();
    }
  }

  void _retry() {
    setState(() {
      _pdfPathFuture = _downloadToTemp();
    });
  }

  Future<void> _downloadFile() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final response = await _fetchPdf();

      if (response.statusCode != 200) {
        throw Exception('Không tải được file');
      }

      final fileName = resolvePdfDownloadFilename(
        contentDisposition:
            response.headers['content-disposition'] ??
            response.headers['Content-Disposition'],
        suggestedFilename: widget.suggestedFilename,
      );

      // Ưu tiên lưu vào thư mục Downloads hệ thống (Android)
      // để người dùng có thể tìm thấy file qua trình quản lý file.
      // Nếu không khả dụng (iOS), fallback về thư mục documents của app.
      Directory saveDir;
      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          saveDir = downloadsDir;
        } else {
          saveDir = await getApplicationDocumentsDirectory();
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        final location = Platform.isAndroid ? 'Downloads' : 'tài liệu ứng dụng';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu vào $location: $fileName'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lỗi tải xuống: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: const Color(0xFFB00020),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
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
              onPressed: _isDownloading ? null : _downloadFile,
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
      body: FutureBuilder<String>(
        future: _pdfPathFuture,
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
            return _buildErrorState(
              snapshot.error.toString().replaceAll('Exception: ', ''),
            );
          }

          final path = snapshot.data;
          if (path == null || path.isEmpty) {
            return _buildErrorState('Không tải được tài liệu');
          }

          return Column(
            children: [
              Expanded(
                child: PDFView(
                  filePath: path,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  fitPolicy: FitPolicy.BOTH,
                  onRender: (pages) {
                    if (pages != null && mounted) {
                      setState(() => _totalPages = pages);
                    }
                  },
                  onPageChanged: (page, total) {
                    if (page != null && mounted) {
                      setState(() => _currentPage = page);
                    }
                  },
                  onError: (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lỗi hiển thị PDF: $error'),
                          backgroundColor: const Color(0xFFB00020),
                        ),
                      );
                    }
                  },
                ),
              ),
              if (_totalPages > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: AppColors.cardBorder.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: Text(
                    'Trang ${_currentPage + 1} / $_totalPages',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.bodyText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
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
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
