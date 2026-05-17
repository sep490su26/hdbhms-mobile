import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  static const webBaseUrl = 'http://localhost:8080/api/v1';
  static const androidEmulatorBaseUrl = 'http://10.0.2.2:8080/api/v1';

  static String get baseUrl {
    if (kIsWeb) {
      return webBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorBaseUrl;
    }

    return webBaseUrl;
  }
}
