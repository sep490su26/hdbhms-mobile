import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

/// Màn WebView dùng chung – nhận [url] và [title] từ ngoài truyền vào.
///
/// Chỉ hoạt động trên Android/iOS. Trên Flutter Web sẽ hiện thông báo.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.postData,
  });

  final String url;
  final String title;
  final Map<String, String>? postData;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // webview_flutter không hỗ trợ Flutter Web → bỏ qua init trên web
    if (kIsWeb) return;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress);
            }
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _hasError = false;
                _loadingProgress = 0;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loadingProgress = 100);
            }
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => _hasError = true);
            }
          },
        ),
      );

    if (widget.postData != null && widget.postData!.isNotEmpty) {
      final String bodyString = widget.postData!.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');

      _controller.loadRequest(
        Uri.parse(widget.url),
        method: LoadRequestMethod.post,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: Uint8List.fromList(utf8.encode(bodyString)),
      );
    } else {
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // Trên Flutter Web, webview_flutter không được hỗ trợ
            if (kIsWeb)
              Expanded(child: _buildWebNotSupported())
            else ...[
              // Loading progress bar
              if (_loadingProgress < 100)
                LinearProgressIndicator(
                  value: _loadingProgress / 100,
                  backgroundColor: AppColors.cardBorder.withValues(alpha: 0.3),
                  color: AppColors.deepBlue,
                  minHeight: 2,
                ),
              Expanded(
                child: _hasError
                    ? _buildErrorState()
                    : WebViewWidget(controller: _controller),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppColors.topBarTitleStyle,
            ),
          ),
          if (!kIsWeb)
            IconButton(
              onPressed: () => _controller.reload(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.topBarIconColor,
                size: AppColors.topBarIconSize,
              ),
              tooltip: 'Tải lại',
            ),
        ],
      ),
    );
  }

  /// Hiện khi chạy trên Flutter Web – webview_flutter chỉ hỗ trợ Android/iOS.
  Widget _buildWebNotSupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
              ),
              child: const Icon(
                Icons.smartphone_rounded,
                color: AppColors.deepBlue,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chỉ khả dụng trên ứng dụng mobile',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inputText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 22 / 17,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tính năng này yêu cầu chạy trên thiết bị Android hoặc iOS.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.bodyText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 18 / 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Quay lại'),
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.deepBlue,
              size: 52,
            ),
            const SizedBox(height: 16),
            const Text(
              'Không thể tải trang',
              style: TextStyle(
                color: AppColors.inputText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 22 / 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.url,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 17 / 12,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _hasError = false);
                _controller.reload();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
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
