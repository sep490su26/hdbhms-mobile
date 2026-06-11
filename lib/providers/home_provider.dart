import 'package:flutter/foundation.dart';

import '../models/home_summary_model.dart';
import '../services/auth_service.dart';
import '../services/home_service.dart';
import '../services/lease_contract_service.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider({
    HomeService homeService = const HomeService(),
    LeaseContractService leaseContractService = const LeaseContractService(),
  })  : _homeService = homeService,
        _leaseContractService = leaseContractService;

  final HomeService _homeService;
  final LeaseContractService _leaseContractService;

  HomeSummary? _summary;
  String? _errorMessage;
  bool _isLoading = false;
  bool _sessionExpired = false;

  // Active rooms for the room switcher
  List<ActiveRoomItem> _activeRooms = const [];
  ActiveRoomItem? _selectedRoom;

  HomeSummary? get summary => _summary;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get sessionExpired => _sessionExpired;
  List<ActiveRoomItem> get activeRooms => _activeRooms;
  ActiveRoomItem? get selectedRoom => _selectedRoom;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _sessionExpired = false;
    _summary = null;
    _activeRooms = const [];
    _selectedRoom = null;
    notifyListeners();

    try {
      _summary = await _homeService.fetchHomeSummary();
    } on SessionExpiredException catch (error) {
      _sessionExpired = true;
      _errorMessage = error.message;
    } on HomeException catch (error) {
      _errorMessage = error.message;
    } catch (e) {
      _errorMessage = 'Đã có lỗi xảy ra';
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Fetch active rooms independently so a failure doesn't block the home screen
    if (!_sessionExpired) {
      _loadActiveRooms();
    }
  }

  Future<void> _loadActiveRooms() async {
    // First, seed from the home summary's rooms list (instant, no extra call)
    final summaryRooms = _summary?.rooms ?? [];
    if (summaryRooms.isNotEmpty && _activeRooms.isEmpty) {
      _activeRooms = summaryRooms.map((r) => ActiveRoomItem(
        contractId: 0,
        contractCode: '',
        roomId: r.id ?? 0,
        roomCode: r.roomCode,
        roomName: r.name,
        propertyName: _summary?.tenant?.name ?? '',
      )).toList();
      if (_selectedRoom == null && _activeRooms.isNotEmpty) {
        _selectedRoom = _activeRooms.first;
      }
      notifyListeners();
    }

    // Then fetch the richer list from the dedicated endpoint
    try {
      final rooms = await _leaseContractService.fetchMyActiveRooms();
      if (rooms.isNotEmpty) {
        _activeRooms = rooms;
        // Preserve selection or pick by matching room id
        final summaryRoomId = _summary?.room?.id;
        if (_selectedRoom == null || !rooms.any((r) => r.contractId == _selectedRoom!.contractId)) {
          _selectedRoom = summaryRoomId != null
              ? rooms.firstWhere(
                  (r) => r.roomId == summaryRoomId,
                  orElse: () => rooms.first,
                )
              : rooms.first;
        }
        notifyListeners();
      }
    } catch (_) {
      // Non-fatal: fall back to what we already seeded from summary.rooms
    }
  }

  void selectRoom(ActiveRoomItem room) {
    if (_selectedRoom?.contractId == room.contractId) return;
    _selectedRoom = room;
    notifyListeners();
  }
}
