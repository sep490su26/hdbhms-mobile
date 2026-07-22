import 'package:flutter/foundation.dart';

import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/utils/display_formatters.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider({
    HomeService homeService = const HomeService(),
    LeaseContractService leaseContractService = const LeaseContractService(),
    TenantInvoiceService tenantInvoiceService = const TenantInvoiceService(),
    ActiveRoomItem? initialRoom,
  }) : _homeService = homeService,
       _leaseContractService = leaseContractService,
       _tenantInvoiceService = tenantInvoiceService,
       _initialRoom = initialRoom;

  final HomeService _homeService;
  final LeaseContractService _leaseContractService;
  final TenantInvoiceService _tenantInvoiceService;
  final ActiveRoomItem? _initialRoom;

  HomeSummary? _summary;
  String? _errorMessage;
  bool _isLoading = false;
  bool _sessionExpired = false;
  bool _invoicesLoaded = false;
  List<TenantInvoice> _invoices = const [];

  // Active rooms for the room switcher
  List<ActiveRoomItem> _activeRooms = const [];
  ActiveRoomItem? _selectedRoom;

  // Room-specific utility summary (loaded on demand when room is selected)
  UtilitySummary? _roomUtilitySummary;
  bool _loadingUtilities = false;

  HomeSummary? get summary => _summary;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get sessionExpired => _sessionExpired;
  List<ActiveRoomItem> get activeRooms => _activeRooms;
  ActiveRoomItem? get selectedRoom => _selectedRoom;
  UtilitySummary get roomUtilitySummary {
    // Return room-specific summary if loaded, otherwise fall back to home summary
    return _roomUtilitySummary ??
        _summary?.utilitySummary ??
        const UtilitySummary();
  }

  bool get loadingUtilities => _loadingUtilities;
  List<TenantInvoice> get invoices => List.unmodifiable(_invoices);

  UtilityInvoiceTrend? get electricityTrend => _utilityTrendFor('ELECTRICITY');

  UtilityInvoiceTrend? get waterTrend => _utilityTrendFor('WATER');

  List<TenantInvoice> get selectedRoomInvoices {
    final room = _selectedRoom;
    final contractId = room?.contractId ?? _summary?.contract?.id ?? 0;
    final contractCode =
        room?.contractCode ?? _summary?.contract?.contractCode ?? '';
    final roomId = room?.roomId ?? _summary?.room?.id ?? 0;
    final roomCode = room?.roomCode ?? _summary?.room?.roomCode ?? '';

    if (contractId <= 0 && roomId <= 0 && roomCode.isEmpty) {
      return _invoices;
    }

    return _invoices
        .where((invoice) {
          if (invoice.contractId != null && contractId > 0) {
            return invoice.contractId == contractId;
          }
          if (invoice.roomId != null && roomId > 0) {
            return invoice.roomId == roomId;
          }
          if (invoice.contractCode.isNotEmpty && contractCode.isNotEmpty) {
            return invoice.contractCode == contractCode;
          }
          return invoice.roomCode == roomCode;
        })
        .toList(growable: false);
  }

  List<TenantInvoice> get payableInvoices => selectedRoomInvoices
      .where((invoice) => invoice.canPay && invoice.remainingAmount > 0)
      .toList(growable: false);

  UtilityInvoiceTrend? _utilityTrendFor(String lineType) {
    final samples = <_UtilityInvoiceSample>[];

    for (final invoice in selectedRoomInvoices) {
      for (final line in invoice.utilityMeterLines) {
        if (line.lineType.toUpperCase() != lineType || !_hasMeterData(line)) {
          continue;
        }
        samples.add(_UtilityInvoiceSample(invoice: invoice, line: line));
      }
    }

    if (samples.isEmpty) {
      return null;
    }

    samples.sort(_compareUtilitySamplesNewestFirst);
    final latest = samples.first;
    final previous = samples
        .skip(1)
        .cast<_UtilityInvoiceSample?>()
        .firstWhere(
          (sample) => sample!.periodKey != latest.periodKey,
          orElse: () => null,
        );

    final currentUsage = _usageOf(latest.line);
    final previousUsage = previous == null ? null : _usageOf(previous.line);
    final difference = currentUsage != null && previousUsage != null
        ? currentUsage - previousUsage
        : null;
    final percentChange = difference != null && previousUsage != null
        ? (previousUsage == 0 ? null : (difference / previousUsage) * 100)
        : null;

    return UtilityInvoiceTrend(
      invoice: latest.invoice,
      line: latest.line,
      previousReading: latest.line.previousValue ?? previous?.line.currentValue,
      previousUsage: previousUsage,
      difference: difference,
      percentChange: percentChange,
    );
  }

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
    _summary = null;
    _activeRooms = const [];
    _selectedRoom = _initialRoom;
    notifyListeners();

    try {
      final contractId = _initialRoom?.contractId;
      _summary = await _homeService.fetchHomeSummary(
        contractId: contractId != null && contractId > 0 ? contractId : null,
      );
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
              propertyName: formatPropertyName(_summary?.tenant?.name ?? ''),
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
    _roomUtilitySummary = null; // Clear cached utility data
    notifyListeners();
    _loadRoomUtilities();
  }

  Future<void> _loadRoomUtilities() async {
    final contractId = _selectedRoom?.contractId;
    if (contractId == null || contractId <= 0) return;

    _loadingUtilities = true;
    notifyListeners();

    try {
      final roomSummary = await _homeService.fetchHomeSummary(
        contractId: contractId,
      );
      _roomUtilitySummary = roomSummary.utilitySummary;
    } catch (_) {
      // Keep the previous data as fallback
    } finally {
      _loadingUtilities = false;
      notifyListeners();
    }
  }
}

class UtilityInvoiceTrend {
  const UtilityInvoiceTrend({
    required this.invoice,
    required this.line,
    required this.previousReading,
    required this.previousUsage,
    required this.difference,
    required this.percentChange,
  });

  final TenantInvoice invoice;
  final TenantInvoiceLine line;
  final double? previousReading;
  final double? previousUsage;
  final double? difference;
  final double? percentChange;

  double? get currentReading => line.currentValue;
  double? get currentUsage => _usageOf(line);

  UtilityTrendDirection get direction {
    final value = difference;
    if (value == null) {
      return UtilityTrendDirection.unavailable;
    }
    if (value > 0) {
      return UtilityTrendDirection.increase;
    }
    if (value < 0) {
      return UtilityTrendDirection.decrease;
    }
    return UtilityTrendDirection.stable;
  }
}

enum UtilityTrendDirection { increase, decrease, stable, unavailable }

class _UtilityInvoiceSample {
  const _UtilityInvoiceSample({required this.invoice, required this.line});

  final TenantInvoice invoice;
  final TenantInvoiceLine line;

  String get periodKey {
    final readingPeriod = line.readingPeriod.trim();
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(readingPeriod)) {
      return readingPeriod;
    }
    final billingPeriod = invoice.billingPeriod.trim();
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(billingPeriod)) {
      return billingPeriod;
    }
    return invoice.issuedAt?.toIso8601String() ?? '';
  }
}

bool _hasMeterData(TenantInvoiceLine line) {
  return line.currentValue != null ||
      line.previousValue != null ||
      line.usageAmount != null;
}

double? _usageOf(TenantInvoiceLine line) {
  return line.usageAmount ??
      (line.currentValue != null && line.previousValue != null
          ? line.currentValue! - line.previousValue!
          : null);
}

int _compareUtilitySamplesNewestFirst(
  _UtilityInvoiceSample first,
  _UtilityInvoiceSample second,
) {
  final periodCompare = second.periodKey.compareTo(first.periodKey);
  if (periodCompare != 0) {
    return periodCompare;
  }
  return (second.invoice.issuedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
      .compareTo(
        first.invoice.issuedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
