import 'package:hdbhms_mobile/models/onboarding_state.dart';

class HomeSummary {
  const HomeSummary({
    required this.user,
    required this.tenant,
    required this.room,
    required this.rooms,
    required this.contract,
    required this.invoiceSummary,
    required this.notificationSummary,
    required this.utilitySummary,
    this.onboarding,
  });

  final HomeUser user;
  final HomeTenant? tenant;
  final HomeRoom? room;
  final List<HomeRoom> rooms;
  final HomeContract? contract;
  final InvoiceSummary invoiceSummary;
  final NotificationSummary notificationSummary;
  final UtilitySummary utilitySummary;
  final OnboardingState? onboarding;

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    final roomsList = (json['rooms'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(HomeRoom.fromJson)
        .toList();
    return HomeSummary(
      user: HomeUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      tenant: json['tenant'] != null
          ? HomeTenant.fromJson(json['tenant'] as Map<String, dynamic>)
          : null,
      room: json['room'] != null
          ? HomeRoom.fromJson(json['room'] as Map<String, dynamic>)
          : (roomsList.isNotEmpty ? roomsList.first : null),
      rooms: roomsList,
      contract: json['contract'] != null
          ? HomeContract.fromJson(json['contract'] as Map<String, dynamic>)
          : null,
      invoiceSummary:
          InvoiceSummary.fromJson(json['invoiceSummary'] as Map<String, dynamic>? ?? {}),
      notificationSummary: NotificationSummary.fromJson(
        json['notificationSummary'] as Map<String, dynamic>? ?? {},
      ),
      utilitySummary: UtilitySummary.fromHomeJson(json),
      onboarding: json['onboarding'] != null
          ? OnboardingState.fromJson(json['onboarding'] as Map<String, dynamic>)
          : null,
    );
  }
}

class HomeUser {
  const HomeUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.role,
    this.avatarUrl = '',
  });

  final int? id;
  final String fullName;
  final String phone;
  final String email;
  final String role;
  final String avatarUrl;

  factory HomeUser.fromJson(Map<String, dynamic> json) {
    return HomeUser(
      id: int.tryParse(json['id']?.toString() ?? ''),
      fullName: _firstString(json, ['fullName']),
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      avatarUrl: _firstString(json, [
        'avatarUrl',
        'avatar',
        'profilePhotoUrl',
        'photoUrl',
      ]),
    );
  }
}

class HomeTenant {
  const HomeTenant({
    required this.id,
    required this.name,
    this.address = '',
    this.propertyPhone = '',
    this.imageUrls = const [],
  });

  final int? id;
  final String name;
  final String address;
  final String propertyPhone;
  final List<String> imageUrls;

  factory HomeTenant.fromJson(Map<String, dynamic> json) {
    final rawImages =
        json['imageUrls'] ??
        json['images'] ??
        json['imageUrl'] ??
        json['thumbnailUrl'] ??
        json['photoUrls'];

    return HomeTenant(
      id: int.tryParse(json['id']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      address: _firstString(json, [
        'address',
        'propertyAddress',
        'fullAddress',
        'location',
      ]),
      propertyPhone: _firstString(json, [
        'propertyPhone',
        'phone',
        'phoneNumber',
        'hotline',
      ]),
      imageUrls: _stringList(rawImages),
    );
  }
}

class HomeRoom {
  const HomeRoom({
    required this.id,
    required this.roomCode,
    required this.name,
    required this.currentStatus,
  });

  final int? id;
  final String roomCode;
  final String name;
  final String currentStatus;

  factory HomeRoom.fromJson(Map<String, dynamic> json) {
    return HomeRoom(
      id: int.tryParse(json['id']?.toString() ?? ''),
      roomCode: _firstString(json, ['roomCode']),
      name: json['name']?.toString() ?? '',
      currentStatus: _firstString(json, ['currentStatus']),
    );
  }
}

class HomeContract {
  const HomeContract({
    required this.id,
    required this.contractCode,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  final int? id;
  final String contractCode;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;

  factory HomeContract.fromJson(Map<String, dynamic> json) {
    return HomeContract(
      id: int.tryParse(json['id']?.toString() ?? ''),
      contractCode: _firstString(json, ['contractCode']),
      status: json['status']?.toString() ?? '',
      startDate: DateTime.tryParse(_firstString(json, ['startDate'])),
      endDate: DateTime.tryParse(_firstString(json, ['endDate'])),
    );
  }
}

class InvoiceSummary {
  const InvoiceSummary({
    required this.unpaidCount,
    required this.totalUnpaidAmount,
    required this.nearestDueDate,
  });

  final int unpaidCount;
  final double totalUnpaidAmount;
  final DateTime? nearestDueDate;

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) {
    return InvoiceSummary(
      unpaidCount: int.tryParse(json['unpaidCount']?.toString() ?? '') ?? 0,
      totalUnpaidAmount:
          double.tryParse(json['totalUnpaidAmount']?.toString() ?? '') ?? 0,
      nearestDueDate: DateTime.tryParse(json['nearestDueDate']?.toString() ?? ''),
    );
  }
}

class NotificationSummary {
  const NotificationSummary({required this.unreadCount});

  final int unreadCount;

  factory NotificationSummary.fromJson(Map<String, dynamic> json) {
    return NotificationSummary(
      unreadCount: int.tryParse(json['unreadCount']?.toString() ?? '') ?? 0,
    );
  }
}

class UtilitySummary {
  const UtilitySummary({this.electricity, this.water});

  final UtilityUsage? electricity;
  final UtilityUsage? water;

  bool get hasAnyReading =>
      electricity?.hasReading == true || water?.hasReading == true;

  factory UtilitySummary.fromHomeJson(Map<String, dynamic> json) {
    final utilityMap = _firstMap(json, [
      'utilitySummary',
      'utilities',
      'utility',
      'meterSummary',
      'meterReadings',
      'usageSummary',
      'serviceUsage',
    ]);

    final source = utilityMap.isEmpty ? json : utilityMap;
    UtilityUsage? electricity = _usageFromMap(
      source,
      const ['electricity', 'electric', 'power', 'dien'],
      defaultName: 'Điện',
      defaultUnit: 'kWh',
    );
    UtilityUsage? water = _usageFromMap(
      source,
      const ['water', 'nuoc'],
      defaultName: 'Nước',
      defaultUnit: 'm3',
    );

    if (electricity == null || water == null) {
      for (final key in [
        'items',
        'readings',
        'services',
        'utilities',
        'data',
        'meters',
      ]) {
        final values = source[key];
        if (values is! List) {
          continue;
        }
        for (final item in values) {
          if (item is! Map<String, dynamic>) {
            continue;
          }
          final label = [
            item['type'],
            item['serviceType'],
            item['serviceCode'],
            item['name'],
            item['serviceName'],
          ].whereType<Object>().join(' ').toLowerCase();

          if (electricity == null &&
              (label.contains('electric') ||
                  label.contains('power') ||
                  label.contains('dien') ||
                  label.contains('điện'))) {
            electricity = UtilityUsage.fromJson(
              item,
              defaultName: 'Điện',
              defaultUnit: 'kWh',
            );
          }
          if (water == null &&
              (label.contains('water') ||
                  label.contains('nuoc') ||
                  label.contains('nước'))) {
            water = UtilityUsage.fromJson(
              item,
              defaultName: 'Nước',
              defaultUnit: 'm3',
            );
          }
        }
      }
    }

    return UtilitySummary(electricity: electricity, water: water);
  }
}

class UtilityUsage {
  const UtilityUsage({
    required this.name,
    required this.value,
    required this.unit,
    required this.percentChange,
    required this.status,
  });

  final String name;
  final double? value;
  final String unit;
  final double? percentChange;
  final String status;

  bool get hasReading => value != null;

  factory UtilityUsage.fromJson(
    Map<String, dynamic> json, {
    required String defaultName,
    required String defaultUnit,
  }) {
    return UtilityUsage(
      name: _firstString(json, [
        'name',
        'serviceName',
        'label',
      ], fallback: defaultName),
      value: _firstDouble(json, [
        'currentUsage',
        'usage',
        'value',
        'reading',
        'consumption',
        'currentReading',
        'currentValue',
        'total',
        'kwh',
        'm3',
      ]),
      unit: _firstString(json, [
        'unit',
        'measurementUnit',
      ], fallback: defaultUnit),
      percentChange: _firstDouble(json, [
        'changePercent',
        'percentChange',
        'changePercentage',
        'monthOverMonthPercent',
        'momPercent',
        'previousMonthChangePercent',
      ]),
      status: _firstString(json, [
        'status',
        'currentStatus',
        'readingStatus',
      ]),
    );
  }
}

// Global Parsing Helpers
UtilityUsage? _usageFromMap(
  Map<String, dynamic> json,
  List<String> keys, {
  required String defaultName,
  required String defaultUnit,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map<String, dynamic>) {
      return UtilityUsage.fromJson(
        value,
        defaultName: defaultName,
        defaultUnit: defaultUnit,
      );
    }
  }
  return null;
}

Map<String, dynamic> _firstMap(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
  }
  return const {};
}

String _firstString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') {
      return value;
    }
  }
  return fallback;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty && item != 'null')
        .toList(growable: false);
  }

  final single = value?.toString().trim();
  if (single == null || single.isEmpty || single == 'null') {
    return const [];
  }

  return [single];
}

double? _firstDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}
