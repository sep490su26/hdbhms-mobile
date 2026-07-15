import 'package:hdbhms_mobile/config/app_config.dart';

class ApiService {
  const ApiService();

  String get baseUrl => AppConfig.apiBaseUrl;

  Future<Map<String, dynamic>> getDemoHealth() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const {'status': 'ok'};
  }
}
