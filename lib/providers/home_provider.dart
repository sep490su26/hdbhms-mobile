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
      // Fallback to mock data for visualization if requested
      _summary = _mockSummary;
    } catch (e) {
      _errorMessage = 'Đã có lỗi xảy ra';
      _summary = _mockSummary;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static final _mockSummary = HomeSummary(
    user: const HomeUser(
      id: 1,
      fullName: 'Nguyễn Văn A',
      phone: '0912345678',
      email: 'a@example.com',
      role: 'RESIDENT',
      avatarUrl: '',
    ),
    tenant: const HomeTenant(id: 1, name: 'Chung cư Blue Sky'),
    room: const HomeRoom(
      id: 101,
      roomCode: 'P.101',
      name: 'Phòng 101 - Tầng 1',
      currentStatus: 'OCCUPIED',
    ),
    contract: HomeContract(
      id: 1,
      contractCode: 'HD-2024-001',
      status: 'ACTIVE',
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2025, 1, 1),
    ),
    invoiceSummary: const InvoiceSummary(
      unpaidCount: 2,
      totalUnpaidAmount: 3500000,
      nearestDueDate: null,
    ),
    notificationSummary: const NotificationSummary(unreadCount: 5),
    utilitySummary: const UtilitySummary(
      electricity: UtilityUsage(
        name: 'Điện tháng 4',
        value: 145.5,
        unit: 'kWh',
        status: 'Bình thường',
        percentChange: 5.2,
      ),
      water: UtilityUsage(
        name: 'Nước tháng 4',
        value: 12.0,
        unit: 'm³',
        status: 'Bình thường',
        percentChange: -2.1,
      ),
    ),
  );
}
