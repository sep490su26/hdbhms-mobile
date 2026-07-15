import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/services/authenticated_client.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

class AuthenticatedImage extends StatefulWidget {
  const AuthenticatedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorPlaceholder,
  });

  final String url;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorPlaceholder;

  @override
  State<AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<AuthenticatedImage> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = loadAuthenticatedImageBytes(widget.url);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytesFuture = loadAuthenticatedImageBytes(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholder ?? const _ImageLoading();
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          return widget.errorPlaceholder ?? const _ImageError();
        }
        return Image.memory(bytes, fit: widget.fit);
      },
    );
  }
}

class ImageZoomViewer extends StatefulWidget {
  const ImageZoomViewer({super.key, required this.imageUrl, this.title = ''});

  final String imageUrl;
  final String title;

  @override
  State<ImageZoomViewer> createState() => _ImageZoomViewerState();
}

class _ImageZoomViewerState extends State<ImageZoomViewer> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = loadAuthenticatedImageBytes(widget.imageUrl);
  }

  void _retry() {
    setState(() {
      _bytesFuture = loadAuthenticatedImageBytes(widget.imageUrl);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: FutureBuilder<Uint8List>(
                future: _bytesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator(color: Colors.white);
                  }
                  final bytes = snapshot.data;
                  if (snapshot.hasError || bytes == null || bytes.isEmpty) {
                    return _ZoomError(onRetry: _retry);
                  }
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Đóng',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Uint8List> loadAuthenticatedImageBytes(String url) async {
  final client = AuthenticatedClient();
  try {
    final response = await client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Image request failed: ${response.statusCode}');
  } finally {
    client.close();
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();

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

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE7E9F0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, color: AppColors.bodyText),
            SizedBox(height: 8),
            Text(
              'Chưa có ảnh',
              style: TextStyle(
                color: AppColors.bodyText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomError extends StatelessWidget {
  const _ZoomError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Không tải được ảnh',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
