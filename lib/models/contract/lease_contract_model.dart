class LeaseContract {
  const LeaseContract({
    required this.id,
    required this.contractCode,
    required this.status,
    required this.room,
    required this.monthlyRent,
    required this.paymentCycleMonths,
    required this.startDate,
    required this.endDate,
    required this.rentStartDate,
    required this.depositAmount,
    required this.terms,
    required this.serviceFees,
    required this.contractFileUrl,
    this.tenantIntention = '',
    this.expectedVacantDate,
    this.roleInContract = '',
    this.isPrimary = false,
    this.canRecordIntention = false,
    this.canRenew = false,
    this.canRenewBlockedReason = '',
    this.signedAt,
  });

  final int? id;
  final String contractCode;
  final String status;
  final LeaseRoom room;
  final double? monthlyRent;
  final int? paymentCycleMonths;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? rentStartDate;
  final double? depositAmount;
  final List<String> terms;
  final List<LeaseServiceFee> serviceFees;
  final String contractFileUrl;
  final String tenantIntention;
  final DateTime? expectedVacantDate;
  final String roleInContract;
  final bool isPrimary;
  final bool canRecordIntention;
  final bool canRenew;
  final String canRenewBlockedReason;
  final DateTime? signedAt;

  double get expectedServiceFeeTotal =>
      serviceFees.fold<double>(0, (total, fee) => total + (fee.amount ?? 0));

  double get expectedTotal => (monthlyRent ?? 0) + expectedServiceFeeTotal;

  factory LeaseContract.fromJson(Map<String, dynamic> json) {
    final roomJson = _firstMap(json, const [
      'room',
      'room_info',
      'roomInfo',
      'rental_room',
      'rentalRoom',
    ]);

    return LeaseContract(
      id: _asInt(json['id'] ?? json['contract_id']),
      contractCode: _firstString(json, const ['contract_code', 'contractCode']),
      status: _firstString(json, const ['status', 'contract_status']),
      room: LeaseRoom.fromJson(roomJson.isEmpty ? json : roomJson),
      monthlyRent: _firstDouble(json, const [
        'monthly_rent',
        'monthlyRent',
        'rent_amount',
        'rentAmount',
      ]),
      paymentCycleMonths: _asInt(
        json['payment_cycle_months'] ??
            json['paymentCycleMonths'] ??
            json['payment_cycle'],
      ),
      startDate: _firstDate(json, const ['start_date', 'startDate']),
      endDate: _firstDate(json, const ['end_date', 'endDate']),
      rentStartDate: _firstDate(json, const [
        'rent_start_date',
        'rentStartDate',
        'billing_start_date',
      ]),
      depositAmount: _firstDouble(json, const [
        'deposit_amount',
        'depositAmount',
        'deposit',
      ]),
      terms: _parseTerms(json),
      serviceFees: _parseServiceFees(json),
      contractFileUrl: _firstString(json, const [
        'contract_file_download_url',
        'contractFileDownloadUrl',
        'contract_file_url',
        'contractFileUrl',
        'signed_file_download_url',
        'signedFileDownloadUrl',
        'file_url',
        'fileUrl',
        'document_url',
        'documentUrl',
      ]),
      tenantIntention: _firstString(json, const [
        'tenant_intention',
        'tenantIntention',
      ]),
      expectedVacantDate: _firstDate(json, const [
        'expected_vacant_date',
        'expectedVacantDate',
        'expected_move_out_date',
        'expectedMoveOutDate',
      ]),
      roleInContract: _firstString(json, const [
        'role_in_contract',
        'roleInContract',
      ]),
      isPrimary: _firstBool(json, const ['is_primary', 'isPrimary']),
      canRecordIntention: _firstBool(json, const [
        'can_record_intention',
        'canRecordIntention',
      ]),
      canRenew: _firstBool(json, const ['can_renew', 'canRenew']),
      canRenewBlockedReason: _firstString(json, const [
        'can_renew_blocked_reason',
        'canRenewBlockedReason',
      ]),
      signedAt: _firstDate(json, const [
        'signed_at',
        'signedAt',
        'confirmedAt',
      ]),
    );
  }
}

class LeaseRoom {
  const LeaseRoom({
    required this.roomCode,
    required this.roomName,
    required this.area,
    required this.imageUrl,
  });

  final String roomCode;
  final String roomName;
  final double? area;
  final String imageUrl;

  factory LeaseRoom.fromJson(Map<String, dynamic> json) {
    return LeaseRoom(
      roomCode: _firstString(json, const ['room_code', 'roomCode', 'code']),
      roomName: _firstString(json, const ['room_name', 'roomName', 'name']),
      area: _firstDouble(json, const ['area', 'area_m2', 'room_area']),
      imageUrl: _firstString(json, const [
        'image_url',
        'imageUrl',
        'room_image_url',
        'roomImageUrl',
        'thumbnail_url',
      ]),
    );
  }
}

class LeaseServiceFee {
  const LeaseServiceFee({required this.name, required this.amount});

  final String name;
  final double? amount;

  factory LeaseServiceFee.fromJson(Map<String, dynamic> json) {
    return LeaseServiceFee(
      name: _firstString(json, const [
        'name',
        'service_name',
        'serviceName',
        'label',
      ], fallback: 'Phí dịch vụ'),
      amount: _firstDouble(json, const [
        'amount',
        'fee',
        'price',
        'monthly_amount',
        'monthlyAmount',
      ]),
    );
  }
}

List<String> _parseTerms(Map<String, dynamic> json) {
  final value =
      json['terms'] ??
      json['main_terms'] ??
      json['mainTerms'] ??
      json['contract_terms'] ??
      json['contractTerms'];
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'\r?\n|;'))
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
  }
  if (value is List) {
    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return _firstString(item, const [
              'content',
              'description',
              'text',
              'term',
              'title',
            ]);
          }
          return item?.toString().trim() ?? '';
        })
        .where((term) => term.isNotEmpty && term != 'null')
        .toList(growable: false);
  }
  return const [];
}

List<LeaseServiceFee> _parseServiceFees(Map<String, dynamic> json) {
  final serviceFeeTotal = _firstDouble(json, const [
    'service_fee',
    'serviceFee',
    'fixed_service_fee',
    'fixedServiceFee',
    'service_fee_amount',
  ]);
  final values =
      json['service_fees'] ??
      json['serviceFees'] ??
      json['fees'] ??
      json['expected_service_fees'];

  final fees = <LeaseServiceFee>[
    if (serviceFeeTotal != null)
      LeaseServiceFee(name: 'Phí dịch vụ (cố định)', amount: serviceFeeTotal),
  ];

  if (values is List) {
    for (final item in values) {
      if (item is Map<String, dynamic>) {
        fees.add(LeaseServiceFee.fromJson(item));
      }
    }
  }
  return fees;
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

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
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

bool _firstBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) {
      return value;
    }
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return false;
}

DateTime? _firstDate(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final parsed = DateTime.tryParse(json[key]?.toString() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}
