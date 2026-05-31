import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  static const webBaseUrl = 'https://unaudited-hazy-unnerve.ngrok-free.dev/api/v1';
  static const androidEmulatorBaseUrl = 'https://unaudited-hazy-unnerve.ngrok-free.dev/api/v1';

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
