import 'package:flutter/foundation.dart';

import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider({
    HomeService homeService = const HomeService(),
    LeaseContractService leaseContractService = const LeaseContractService(),
    TenantInvoiceService tenantInvoiceService = const TenantInvoiceService(),
  }) : _homeService = homeService,
       _leaseContractService = leaseContractService,
       _tenantInvoiceService = tenantInvoiceService;

  final HomeService _homeService;
  final LeaseContractService _leaseContractService;
  final TenantInvoiceService _tenantInvoiceService;

  HomeSummary? _summary;
  String? _errorMessage;
  bool _isLoading = false;
  bool _sessionExpired = false;
  bool _invoicesLoaded = false;
  List<TenantInvoice> _invoices = const [];

  // Active rooms for the room switcher
  List<ActiveRoomItem> _activeRooms = const [];
  ActiveRoomItem? _selectedRoom;

  HomeSummary? get summary => _summary;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get sessionExpired => _sessionExpired;
  List<ActiveRoomItem> get activeRooms => _activeRooms;
  ActiveRoomItem? get selectedRoom => _selectedRoom;
  List<TenantInvoice> get invoices => List.unmodifiable(_invoices);

  List<TenantInvoice> get selectedRoomInvoices {
    final room = _selectedRoom;
    if (room == null) {
      return _invoices;
    }

    return _invoices
        .where((invoice) {
          if (invoice.contractId != null && room.contractId > 0) {
            return invoice.contractId == room.contractId;
          }
          if (invoice.roomId != null && room.roomId > 0) {
            return invoice.roomId == room.roomId;
          }
          if (invoice.contractCode.isNotEmpty && room.contractCode.isNotEmpty) {
            return invoice.contractCode == room.contractCode;
          }
          return invoice.roomCode == room.roomCode;
        })
        .toList(growable: false);
  }

  List<TenantInvoice> get payableInvoices => selectedRoomInvoices
      .where((invoice) => invoice.canPay && invoice.remainingAmount > 0)
      .toList(growable: false);

  InvoiceSummary get invoiceSummary {
    if (!_invoicesLoaded) {
      return _summary?.invoiceSummary ??
          const InvoiceSummary(
            unpaidCount: 0,
            totalUnpaidAmount: 0,
            nearestDueDate: null,
          );
    }

    final unpaid = payableInvoices;
    DateTime? nearestDueDate;
    for (final invoice in unpaid) {
      final dueDate = invoice.dueDate;
      if (dueDate != null &&
          (nearestDueDate == null || dueDate.isBefore(nearestDueDate))) {
        nearestDueDate = dueDate;
      }
    }

    return InvoiceSummary(
      unpaidCount: unpaid.length,
      totalUnpaidAmount: unpaid.fold<double>(
        0,
        (total, invoice) => total + invoice.remainingAmount,
      ),
      nearestDueDate: nearestDueDate,
    );
  }

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
      _summary = _mockSummary;
    } catch (e) {
      _errorMessage = 'Đã có lỗi xảy ra';
      _summary = _mockSummary;
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Fetch active rooms independently so a failure doesn't block the home screen
    if (!_sessionExpired) {
      _loadActiveRooms();
      _loadInvoices();
    }
  }

  Future<void> _loadInvoices() async {
    try {
      _invoices = await _tenantInvoiceService.fetchMyInvoices();
      _invoicesLoaded = true;
      notifyListeners();
    } catch (_) {
      // Keep the home summary as a non-blocking fallback.
    }
  }

  Future<void> _loadActiveRooms() async {
    // First, seed from the home summary's rooms list (instant, no extra call)
    final summaryRooms = _summary?.rooms ?? [];
    if (summaryRooms.isNotEmpty && _activeRooms.isEmpty) {
      _activeRooms = summaryRooms
          .map(
            (r) => ActiveRoomItem(
              contractId: 0,
              contractCode: '',
              roomId: r.id ?? 0,
              roomCode: r.roomCode,
              roomName: r.name,
              propertyName: _summary?.tenant?.name ?? '',
            ),
          )
          .toList();
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
        if (_selectedRoom == null ||
            !rooms.any((r) => r.contractId == _selectedRoom!.contractId)) {
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
    rooms: const [
      HomeRoom(
        id: 101,
        roomCode: 'P.101',
        name: 'Phòng 101 - Tầng 1',
        currentStatus: 'OCCUPIED',
      ),
    ],
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
