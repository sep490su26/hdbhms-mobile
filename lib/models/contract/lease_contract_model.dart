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
    this.currentTenantProfileId,
    this.occupants = const [],
    this.isPrimary = false,
    this.canRecordIntention = false,
    this.canRecordOccupantIntention = false,
    this.occupantIntention = '',
    this.occupantIntentionNote = '',
    this.occupantIntentionRecordedAt,
    this.canRenew = false,
    this.canRenewBlockedReason = '',
    this.canLiquidate = false,
    this.canLiquidateBlockedReason = '',
    this.canAddCoOccupant = false,
    this.canAddCoOccupantBlockedReason = '',
    this.canChangeRoom = false,
    this.canChangeRoomBlockedReason = '',
    this.mustTransferAllOccupants = false,
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
  final int? currentTenantProfileId;
  final List<LeaseContractOccupant> occupants;
  final bool isPrimary;
  final bool canRecordIntention;
  final bool canRecordOccupantIntention;
  final String occupantIntention;
  final String occupantIntentionNote;
  final DateTime? occupantIntentionRecordedAt;
  final bool canRenew;
  final String canRenewBlockedReason;
  final bool canLiquidate;
  final String canLiquidateBlockedReason;
  final bool canAddCoOccupant;
  final String canAddCoOccupantBlockedReason;
  final bool canChangeRoom;
  final String canChangeRoomBlockedReason;
  final bool mustTransferAllOccupants;
  final DateTime? signedAt;

  double get expectedServiceFeeTotal =>
      serviceFees.fold<double>(0, (total, fee) => total + (fee.amount ?? 0));

  double get expectedTotal => (monthlyRent ?? 0) + expectedServiceFeeTotal;

  factory LeaseContract.fromJson(Map<String, dynamic> json) {
    final roomJson = _firstMap(json, const ['room', 'roomInfo', 'rentalRoom']);

    return LeaseContract(
      id: _asInt(json['id'] ?? json['contractId'] ?? json['contract_id']),
      contractCode: _firstString(json, const ['contractCode', 'contract_code']),
      status: _firstString(json, const [
        'status',
        'contractStatus',
        'contract_status',
      ]),
      room: LeaseRoom.fromJson(roomJson.isEmpty ? json : roomJson),
      monthlyRent: _firstDouble(json, const [
        'monthlyRent',
        'monthly_rent',
        'rentAmount',
        'rent_amount',
      ]),
      paymentCycleMonths: _asInt(
        json['paymentCycleMonths'] ??
            json['payment_cycle_months'] ??
            json['paymentCycle'] ??
            json['payment_cycle'],
      ),
      startDate: _firstDate(json, const ['startDate', 'start_date']),
      endDate: _firstDate(json, const ['endDate', 'end_date']),
      rentStartDate: _firstDate(json, const [
        'rentStartDate',
        'rent_start_date',
        'billingStartDate',
        'billing_start_date',
      ]),
      depositAmount: _firstDouble(json, const [
        'depositAmount',
        'deposit_amount',
        'deposit',
      ]),
      terms: _parseTerms(json),
      serviceFees: _parseServiceFees(json),
      contractFileUrl: _firstString(json, const [
        'signedFileDownloadUrl',
        'signed_file_download_url',
        'signedFileUrl',
        'signed_file_url',
        'contractFileDownloadUrl',
        'contract_file_download_url',
        'contractFileUrl',
        'contract_file_url',
        'fileUrl',
        'file_url',
        'documentUrl',
        'document_url',
      ]),
      tenantIntention: _firstString(json, const [
        'tenantIntention',
        'tenant_intention',
      ]),
      expectedVacantDate: _firstDate(json, const [
        'expectedVacantDate',
        'expected_vacant_date',
        'expectedMoveOutDate',
        'expected_move_out_date',
      ]),
      roleInContract: _firstString(json, const [
        'roleInContract',
        'role_in_contract',
      ]),
      currentTenantProfileId: _asInt(
        json['currentTenantProfileId'] ?? json['current_tenant_profile_id'],
      ),
      occupants: _parseOccupants(json),
      isPrimary: _firstBool(json, const ['isPrimary', 'is_primary']),
      canRecordIntention: _firstBool(json, const [
        'canRecordIntention',
        'can_record_intention',
      ]),
      canRecordOccupantIntention: _firstBool(json, const [
        'canRecordOccupantIntention',
        'can_record_occupant_intention',
      ]),
      occupantIntention: _firstString(json, const [
        'occupantIntention',
        'occupant_intention',
      ]),
      occupantIntentionNote: _firstString(json, const [
        'occupantIntentionNote',
        'occupant_intention_note',
      ]),
      occupantIntentionRecordedAt: _firstDate(json, const [
        'occupantIntentionRecordedAt',
        'occupant_intention_recorded_at',
      ]),
      canRenew: _firstBool(json, const ['canRenew', 'can_renew']),
      canRenewBlockedReason: _firstString(json, const [
        'canRenewBlockedReason',
        'can_renew_blocked_reason',
      ]),
      canLiquidate: _firstBool(json, const ['canLiquidate', 'can_liquidate']),
      canLiquidateBlockedReason: _firstString(json, const [
        'canLiquidateBlockedReason',
        'can_liquidate_blocked_reason',
      ]),
      canAddCoOccupant: _firstBool(json, const [
        'canAddCoOccupant',
        'can_add_co_occupant',
      ]),
      canAddCoOccupantBlockedReason: _firstString(json, const [
        'canAddCoOccupantBlockedReason',
        'can_add_co_occupant_blocked_reason',
      ]),
      canChangeRoom: _firstBool(json, const [
        'canChangeRoom',
        'can_change_room',
      ]),
      canChangeRoomBlockedReason: _firstString(json, const [
        'canChangeRoomBlockedReason',
        'can_change_room_blocked_reason',
      ]),
      mustTransferAllOccupants: _firstBool(json, const [
        'mustTransferAllOccupants',
        'must_transfer_all_occupants',
      ]),
      signedAt: _firstDate(json, const [
        'signedAt',
        'signed_at',
        'confirmedAt',
        'confirmed_at',
      ]),
    );
  }
}

class LeaseContractOccupant {
  const LeaseContractOccupant({
    required this.tenantProfileId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.occupantRole,
    required this.status,
    this.moveInDate,
    this.moveOutDate,
  });

  final int? tenantProfileId;
  final String fullName;
  final String phone;
  final String email;
  final String occupantRole;
  final String status;
  final DateTime? moveInDate;
  final DateTime? moveOutDate;

  bool get isActive => status.trim().toUpperCase() == 'ACTIVE';
  bool get isPrimary => occupantRole.trim().toUpperCase() == 'PRIMARY';

  String get displayName {
    final name = fullName.trim();
    if (name.isNotEmpty) return name;
    final contact = phone.trim().isNotEmpty ? phone.trim() : email.trim();
    return contact.isNotEmpty ? contact : 'Người ở cùng';
  }

  factory LeaseContractOccupant.fromJson(Map<String, dynamic> json) {
    return LeaseContractOccupant(
      tenantProfileId: _asInt(
        json['tenantProfileId'] ??
            json['tenant_profile_id'] ??
            json['profileId'] ??
            json['profile_id'],
      ),
      fullName: _firstString(json, const ['fullName', 'full_name', 'name']),
      phone: _firstString(json, const ['phone']),
      email: _firstString(json, const ['email']),
      occupantRole: _firstString(json, const [
        'occupantRole',
        'occupant_role',
        'role',
      ]),
      status: _firstString(json, const ['status']),
      moveInDate: _firstDate(json, const ['moveInDate', 'move_in_date']),
      moveOutDate: _firstDate(json, const ['moveOutDate', 'move_out_date']),
    );
  }
}

class LeaseRoom {
  const LeaseRoom({
    this.id,
    required this.roomCode,
    required this.roomName,
    required this.area,
    required this.imageUrl,
    this.propertyId,
    this.propertyName = '',
    this.currentStatus = '',
    this.maxOccupants,
  });

  final int? id;
  final String roomCode;
  final String roomName;
  final double? area;
  final String imageUrl;
  final int? propertyId;
  final String propertyName;
  final String currentStatus;
  final int? maxOccupants;

  factory LeaseRoom.fromJson(Map<String, dynamic> json) {
    return LeaseRoom(
      id: _asInt(json['id'] ?? json['roomId'] ?? json['room_id']),
      roomCode: _firstString(json, const ['roomCode', 'room_code', 'code']),
      roomName: _firstString(json, const ['roomName', 'room_name', 'name']),
      area: _firstDouble(json, const [
        'area',
        'areaM2',
        'area_m2',
        'roomArea',
        'room_area',
      ]),
      imageUrl: _firstString(json, const [
        'imageUrl',
        'image_url',
        'roomImageUrl',
        'room_image_url',
        'thumbnailUrl',
        'thumbnail_url',
      ]),
      propertyId: _asInt(json['propertyId'] ?? json['property_id']),
      propertyName: _firstString(json, const ['propertyName', 'property_name']),
      currentStatus: _firstString(json, const [
        'currentStatus',
        'current_status',
        'roomStatus',
        'room_status',
      ]),
      maxOccupants: _asInt(json['maxOccupants'] ?? json['max_occupants']),
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
        'serviceName',
        'service_name',
        'label',
      ], fallback: 'Phí dịch vụ'),
      amount: _firstDouble(json, const [
        'amount',
        'fee',
        'price',
        'monthlyAmount',
        'monthly_amount',
      ]),
    );
  }
}

List<String> _parseTerms(Map<String, dynamic> json) {
  final value = json['terms'] ?? json['mainTerms'] ?? json['contractTerms'];
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
    'serviceFee',
    'service_fee',
    'fixedServiceFee',
    'fixed_service_fee',
    'serviceFeeAmount',
    'service_fee_amount',
  ]);
  final values =
      json['serviceFees'] ??
      json['service_fees'] ??
      json['fees'] ??
      json['expectedServiceFees'] ??
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

List<LeaseContractOccupant> _parseOccupants(Map<String, dynamic> json) {
  final values =
      json['occupants'] ??
      json['contractOccupants'] ??
      json['contract_occupants'];
  if (values is! List) {
    return const [];
  }
  return values
      .whereType<Map>()
      .map(
        (item) =>
            LeaseContractOccupant.fromJson(Map<String, dynamic>.from(item)),
      )
      .where((item) => item.tenantProfileId != null)
      .toList(growable: false);
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
