import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  // A stream that emits the token detected from the deep link
  final _tokenController = StreamController<String>.broadcast();
  Stream<String> get onResetPasswordToken => _tokenController.stream;

  void initialize() {
    // Check for initial link when app starts from a closed state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });

    // Listen for incoming links while app is running
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) {
    // Example: hdbhms://reset-password?token=ABCDEF
    // Or: https://yourdomain.com/reset-password?code=ABCDEF
    if (uri.path.contains('reset-password')) {
      final token = uri.queryParameters['token'] ?? uri.queryParameters['code'];
      if (token != null && token.isNotEmpty) {
        _tokenController.add(token);
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _tokenController.close();
  }
}
