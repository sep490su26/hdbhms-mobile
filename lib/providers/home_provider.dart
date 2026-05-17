import 'package:flutter/foundation.dart';

import '../models/home_summary_model.dart';
import '../services/home_service.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider({HomeService homeService = const HomeService()})
    : _homeService = homeService;

  final HomeService _homeService;

  HomeSummary? _summary;
  String? _errorMessage;
  bool _isLoading = false;
  bool _sessionExpired = false;

  HomeSummary? get summary => _summary;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get sessionExpired => _sessionExpired;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _sessionExpired = false;
    notifyListeners();

    try {
      _summary = await _homeService.fetchHomeSummary();
    } on SessionExpiredException catch (error) {
      _sessionExpired = true;
      _errorMessage = error.message;
    } on HomeException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
