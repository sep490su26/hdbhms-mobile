
import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  static const webBaseUrl = 'http://localhost:8080/api/v1';
  static const androidEmulatorBaseUrl = 'http://10.0.2.2:8080/api/v1';

  // Frontend web app URLs (Next.js, port 3000)
  static const webFrontendUrl = 'http://localhost:3000';
  static const androidEmulatorFrontendUrl = 'http://10.0.2.2:3000';

  static String get baseUrl {
    if (kIsWeb) {
      return webBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorBaseUrl;
    }

    return webBaseUrl;
  }

  static String get frontendUrl {
    if (kIsWeb) {
      return webFrontendUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorFrontendUrl;
    }

    return webFrontendUrl;
  }
}
