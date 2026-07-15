import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  static const _apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');
  static const _frontendBaseUrlDefine = String.fromEnvironment(
    'FRONTEND_BASE_URL',
  );

  static const webBaseUrl = 'http://localhost:8080/api/v1';
  static const androidEmulatorBaseUrl = 'http://10.0.2.2:8080/api/v1';

  // Frontend web app URLs (Next.js, port 3000)
  static const webFrontendUrl = 'http://localhost:3000';
  static const androidEmulatorFrontendUrl = 'http://10.0.2.2:3000';

  static String get baseUrl {
    final configuredBaseUrl = _normalizeBaseUrl(_apiBaseUrlDefine);
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    if (kIsWeb) {
      return webBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorBaseUrl;
    }

    return webBaseUrl;
  }

  static String get frontendUrl {
    final configuredFrontendUrl = _normalizeBaseUrl(_frontendBaseUrlDefine);
    if (configuredFrontendUrl.isNotEmpty) {
      return configuredFrontendUrl;
    }

    if (kIsWeb) {
      return webFrontendUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorFrontendUrl;
    }

    return webFrontendUrl;
  }

  static void logResolvedConfig() {
    if (!kDebugMode) return;
    debugPrint(
      '[API CONFIG] baseUrl=$baseUrl frontendUrl=$frontendUrl platform=${kIsWeb ? 'web' : defaultTargetPlatform.name}',
    );
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        _apiBaseUrlDefine.isEmpty) {
      debugPrint(
        '[API CONFIG] Android fallback is emulator-only. For a real Android device, run with '
        '--dart-define=API_BASE_URL=http://<LAN_IP>:8080/api/v1',
      );
    }
  }

  static String _normalizeBaseUrl(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }
}
