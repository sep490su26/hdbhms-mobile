import 'package:flutter/foundation.dart';

import 'package:hdbhms_mobile/models/home/home_summary_model.dart';
import 'package:hdbhms_mobile/models/home/electricity_consumption_entry.dart';
import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/models/payment/tenant_invoice_model.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/services/profile_request/tenant_profile_service.dart';
import 'package:hdbhms_mobile/utils/display_formatters.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider({
    HomeService homeService = const HomeService(),
    LeaseContractService leaseContractService = const LeaseContractService(),
    TenantInvoiceService tenantInvoiceService = const TenantInvoiceService(),
    TenantProfileService tenantProfileService = const TenantProfileService(),
    ActiveRoomItem? initialRoom,
  }) : _homeService = homeService,
       _leaseContractService = leaseContractService,
       _tenantInvoiceService = tenantInvoiceService,
       _tenantProfileService = tenantProfileService,
       _initialRoom = initialRoom;

  final HomeService _homeService;
  final LeaseContractService _leaseContractService;
  final TenantInvoiceService _tenantInvoiceService;
  final TenantProfileService _tenantProfileService;
  final ActiveRoomItem? _initialRoom;

  HomeSummary? _summary;
  String? _errorMessage;
  bool _isLoading = false;
  bool _sessionExpired = false;
  bool _invoicesLoaded = false;
  List<TenantInvoice> _invoices = const [];
  Future<int?>? _tenantProfileIdRequest;
  final Map<int, Future<_OccupancyWindow?>> _occupancyRequests = {};
  _OccupancyWindow? _electricityOccupancy;

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

  List<ElectricityConsumptionEntry> get electricityConsumptionEntries {
    final occupancy = _electricityOccupancy;
    if (occupancy == null) return const [];
    return buildTenantScopedElectricityEntries(
      invoices: _invoices,
      selectedContractId: occupancy.contractId,
      occupancyStart: occupancy.start,
      occupancyEnd: occupancy.end,
    );
  }

  DateTime? get electricityOccupancyStart => _electricityOccupancy?.start;

  String get electricityRoomLabel {
    final selected = _selectedRoom;
    if (selected != null && selected.displayLabel.trim().isNotEmpty) {
      return selected.displayLabel;
    }
    final room = _summary?.room;
    return room?.name.trim().isNotEmpty == true ? room!.name : 'Phòng';
  }

  UtilityInvoiceTrend? get electricityTrend =>
      _electricityTrendFor(electricityConsumptionEntries);

  UtilityInvoiceTrend? get waterTrend => _utilityTrendFor('WATER');

  List<TenantInvoice> get selectedRoomInvoices {
    final room = _selectedRoom;
    final contractId = _selectedContractId;
    final contractCode = _selectedContractCode;
    final roomId = room?.roomId ?? _summary?.room?.id ?? 0;
    final roomCode = room?.roomCode ?? _summary?.room?.roomCode ?? '';

    if (contractId > 0) {
      return _invoices
          .where((invoice) => invoice.contractId == contractId)
          .toList(growable: false);
    }

    if (contractCode.isNotEmpty) {
      return _invoices
          .where((invoice) => invoice.contractCode == contractCode)
          .toList(growable: false);
    }

    if (roomId <= 0 && roomCode.isEmpty) {
      return _invoices;
    }

    return _invoices
        .where((invoice) {
          if (invoice.roomId != null && roomId > 0) {
            return invoice.roomId == roomId;
          }
          if (invoice.roomCode.isNotEmpty && roomCode.isNotEmpty) {
            return invoice.roomCode == roomCode;
          }
          return false;
        })
        .toList(growable: false);
  }

  List<TenantInvoice> get payableInvoices => selectedRoomInvoices
      .where((invoice) => invoice.canPay && invoice.remainingAmount > 0)
      .toList(growable: false);

  int get _selectedContractId {
    final room = _selectedRoom;
    if (room != null) {
      if (room.contractId > 0) return room.contractId;
      if (room.roomId > 0 && room.roomId == _summary?.room?.id) {
        return _summary?.contract?.id ?? 0;
      }
      return 0;
    }
    return _summary?.contract?.id ?? 0;
  }

  String get _selectedContractCode {
    final room = _selectedRoom;
    if (room != null) {
      if (room.contractCode.trim().isNotEmpty) return room.contractCode.trim();
      if (room.roomId > 0 && room.roomId == _summary?.room?.id) {
        return _summary?.contract?.contractCode.trim() ?? '';
      }
      return '';
    }
    return _summary?.contract?.contractCode.trim() ?? '';
  }

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

  UtilityInvoiceTrend? _electricityTrendFor(
    List<ElectricityConsumptionEntry> entries,
  ) {
    if (entries.isEmpty) return null;

    final latest = entries.first;
    final previous = entries
        .skip(1)
        .cast<ElectricityConsumptionEntry?>()
        .firstWhere(
          (entry) => entry!.periodKey != latest.periodKey,
          orElse: () => null,
        );
    final difference = latest.usage != null && previous?.usage != null
        ? latest.usage! - previous!.usage!
        : null;
    final percentChange = difference != null && previous?.usage != null
        ? (previous!.usage == 0 ? null : (difference / previous.usage!) * 100)
        : null;

    return UtilityInvoiceTrend(
      invoice: latest.invoice,
      line: latest.line,
      previousReading: latest.previousReading ?? previous?.currentReading,
      previousUsage: previous?.usage,
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
    _electricityOccupancy = null;
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
      _resolveSelectedElectricityContext();
    } catch (_) {
      // Keep the home summary as a non-blocking fallback.
    }
  }

  Future<void> _loadActiveRooms() async {
    // First, seed from the home summary's rooms list (instant, no extra call)
    final summaryRooms = _summary?.rooms ?? [];
    if (summaryRooms.isNotEmpty && _activeRooms.isEmpty) {
      _activeRooms = dedupeActiveRoomsByRoom(
        summaryRooms.map(
          (r) => ActiveRoomItem(
            contractId: 0,
            contractCode: '',
            roomId: r.id ?? 0,
            roomCode: r.roomCode,
            roomName: r.name,
            propertyName: formatPropertyName(_summary?.tenant?.name ?? ''),
          ),
        ),
      );
      if (_selectedRoom == null && _activeRooms.isNotEmpty) {
        _selectedRoom = _activeRooms.first;
      }
      notifyListeners();
      _resolveSelectedElectricityContext();
    }

    // Then fetch the richer list from the dedicated endpoint
    try {
      final rooms = await _leaseContractService.fetchMyActiveRooms();
      if (rooms.isNotEmpty) {
        _activeRooms = dedupeActiveRoomsByRoom(rooms);
        // Preserve selection or pick by matching room id
        final summaryRoomId = _summary?.room?.id;
        if (_selectedRoom == null ||
            !_activeRooms.any(
              (r) => r.roomIdentityKey == _selectedRoom!.roomIdentityKey,
            )) {
          _selectedRoom = summaryRoomId != null
              ? _activeRooms.firstWhere(
                  (r) => r.roomId == summaryRoomId,
                  orElse: () => _activeRooms.first,
                )
              : _activeRooms.first;
        }
        notifyListeners();
        _resolveSelectedElectricityContext();
      }
    } catch (_) {
      // Non-fatal: fall back to what we already seeded from summary.rooms
    }
  }

  void selectRoom(ActiveRoomItem room) {
    if (_selectedRoom?.roomIdentityKey == room.roomIdentityKey) return;
    _selectedRoom = room;
    _roomUtilitySummary = null; // Clear cached utility data
    _electricityOccupancy = null;
    notifyListeners();
    _loadRoomUtilities();
    _resolveSelectedElectricityContext();
  }

  Future<void> _resolveSelectedElectricityContext() async {
    final contractId = _selectedContractId;
    _electricityOccupancy = null;
    if (contractId <= 0) {
      notifyListeners();
      return;
    }

    notifyListeners();
    final request = _occupancyRequests.putIfAbsent(
      contractId,
      () => _resolveOccupancyWindow(contractId),
    );
    final occupancy = await request;
    if (_selectedContractId != contractId) return;
    _electricityOccupancy = occupancy;
    notifyListeners();
  }

  Future<_OccupancyWindow?> _resolveOccupancyWindow(int contractId) async {
    try {
      final profileRequest = _tenantProfileIdRequest ??= _loadTenantProfileId();
      final profileId = await profileRequest;
      if (profileId == null) return null;

      final contract = await _leaseContractService.getContractById(contractId);
      final occupant = contract.occupants
          .cast<LeaseContractOccupant?>()
          .firstWhere(
            (item) => item?.tenantProfileId == profileId,
            orElse: () => null,
          );
      if (occupant == null) return null;

      final start = occupant.moveInDate ?? contract.startDate;
      if (start == null) return null;
      return _OccupancyWindow(
        contractId: contractId,
        start: _dateOnly(start),
        end: occupant.moveOutDate == null
            ? null
            : _dateOnly(occupant.moveOutDate!),
      );
    } catch (_) {
      return null;
    }
  }

  Future<int?> _loadTenantProfileId() async {
    final profile = await _tenantProfileService.getMyProfile();
    return profile.tenantProfileId;
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

class _OccupancyWindow {
  const _OccupancyWindow({
    required this.contractId,
    required this.start,
    required this.end,
  });

  final int contractId;
  final DateTime start;
  final DateTime? end;
}

/// Builds the privacy-scoped electricity sample set shared by Home and History.
///
/// A period that overlaps the tenancy boundary without an exact reading date is
/// deliberately omitted: presenting room-wide data from before move-in would be
/// worse than an incomplete chart.
List<ElectricityConsumptionEntry> buildTenantScopedElectricityEntries({
  required List<TenantInvoice> invoices,
  required int selectedContractId,
  required DateTime occupancyStart,
  DateTime? occupancyEnd,
}) {
  if (selectedContractId <= 0) return const [];

  final lowerBound = _dateOnly(occupancyStart);
  final upperBound = occupancyEnd == null ? null : _dateOnly(occupancyEnd);
  if (upperBound != null && upperBound.isBefore(lowerBound)) return const [];

  final byPeriod = <String, ElectricityConsumptionEntry>{};
  for (final invoice in invoices) {
    if (invoice.contractId != selectedContractId) continue;

    for (final line in invoice.utilityMeterLines) {
      if (line.lineType.trim().toUpperCase() != 'ELECTRICITY' ||
          !_hasMeterData(line)) {
        continue;
      }

      final period = _invoicePeriod(line, invoice);
      final readingDate = line.readingDate == null
          ? null
          : _dateOnly(line.readingDate!);
      DateTime? referenceDate;

      if (readingDate != null) {
        if (!_isInsideOccupancy(readingDate, lowerBound, upperBound)) {
          continue;
        }
        referenceDate = readingDate;
      } else if (period != null) {
        if (period.start.isBefore(lowerBound) ||
            (upperBound != null && period.end.isAfter(upperBound))) {
          continue;
        }
        referenceDate = period.end;
      } else {
        final issuedAt = invoice.issuedAt == null
            ? null
            : _dateOnly(invoice.issuedAt!);
        if (issuedAt == null ||
            !_isInsideOccupancy(issuedAt, lowerBound, upperBound)) {
          continue;
        }
        referenceDate = issuedAt;
      }

      final periodKey = period?.key ?? _dateKey(referenceDate);
      final entry = ElectricityConsumptionEntry(
        invoice: invoice,
        line: line,
        periodKey: periodKey,
        periodLabel: period?.label ?? _fullDateLabel(referenceDate),
        referenceDate: referenceDate,
        previousReading: line.previousValue,
        currentReading: line.currentValue,
        usage: _usageOf(line),
        unitPrice: line.unitPrice,
        amount: line.amount,
      );
      final existing = byPeriod[periodKey];
      if (existing == null ||
          entry.referenceDate.isAfter(existing.referenceDate) ||
          (entry.referenceDate == existing.referenceDate &&
              (entry.invoice.id ?? 0) > (existing.invoice.id ?? 0))) {
        byPeriod[periodKey] = entry;
      }
    }
  }

  final entries = byPeriod.values.toList(growable: false)
    ..sort((first, second) {
      final dateCompare = second.referenceDate.compareTo(first.referenceDate);
      return dateCompare != 0
          ? dateCompare
          : second.periodKey.compareTo(first.periodKey);
    });
  return List.unmodifiable(entries);
}

class _InvoicePeriod {
  const _InvoicePeriod({
    required this.key,
    required this.label,
    required this.start,
    required this.end,
  });

  final String key;
  final String label;
  final DateTime start;
  final DateTime end;
}

_InvoicePeriod? _invoicePeriod(TenantInvoiceLine line, TenantInvoice invoice) {
  final raw = line.readingPeriod.trim().isNotEmpty
      ? line.readingPeriod.trim()
      : invoice.billingPeriod.trim();
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(raw);
  if (match == null) return null;

  final year = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  if (year == null || month == null || month < 1 || month > 12) return null;

  final start = DateTime(year, month);
  final end = DateTime(year, month + 1).subtract(const Duration(days: 1));
  return _InvoicePeriod(
    key: raw,
    label: 'Kỳ ${month.toString().padLeft(2, '0')}/$year',
    start: start,
    end: end,
  );
}

bool _isInsideOccupancy(DateTime value, DateTime start, DateTime? end) {
  return !value.isBefore(start) && (end == null || !value.isAfter(end));
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _fullDateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
