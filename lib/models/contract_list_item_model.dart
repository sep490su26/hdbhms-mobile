class ContractListItem {
  const ContractListItem({
    required this.id,
    required this.contractCode,
    required this.roomCode,
    required this.signedAt,
    required this.status,
  });

  final int id;
  final String contractCode;
  final String roomCode;
  final DateTime? signedAt;
  final String status;

  factory ContractListItem.fromJson(Map<String, dynamic> json) {
    return ContractListItem(
      id: _asInt(json['id']) ?? 0,
      contractCode: _str(json, ['contract_code', 'contractCode', 'deposit_code', 'depositCode']),
      roomCode: _str(json, ['room_code', 'roomCode']),
      signedAt: _date(json, ['confirmed_at', 'confirmedAt', 'signed_at', 'signedAt', 'created_at', 'createdAt']),
      status: _str(json, ['status']),
    );
  }
}

class DepositContract {
  const DepositContract({
    required this.id,
    required this.depositCode,
    required this.status,
    required this.room,
    required this.amount,
    required this.expectedMoveInDate,
    required this.expectedLeaseSignDate,
    required this.depositExpiresAt,
    required this.createdAt,
    required this.note,
    required this.contractFileUrl,
  });

  final int? id;
  final String depositCode;
  final String status;
  final DepositRoom room;
  final double? amount;
  final DateTime? expectedMoveInDate;
  final DateTime? expectedLeaseSignDate;
  final DateTime? depositExpiresAt;
  final DateTime? createdAt;
  final String note;
  final String contractFileUrl;

  factory DepositContract.fromJson(Map<String, dynamic> json) {
    final roomJson = _firstMap(json, ['room', 'room_info', 'roomInfo']);

    return DepositContract(
      id: _asInt(json['id']),
      depositCode: _str(json, ['deposit_code', 'depositCode']),
      status: _str(json, ['status']),
      room: DepositRoom.fromJson(roomJson.isEmpty ? json : roomJson),
      amount: _dbl(json, ['amount', 'deposit_amount', 'depositAmount']),
      expectedMoveInDate: _date(json, ['expected_move_in_date', 'expectedMoveInDate']),
      expectedLeaseSignDate: _date(json, ['expected_lease_sign_date', 'expectedLeaseSignDate']),
      depositExpiresAt: _date(json, ['deposit_expires_at', 'depositExpiresAt']),
      createdAt: _date(json, ['created_at', 'createdAt', 'confirmedAt', 'confirmed_at']),
      note: _str(json, ['note']),
      contractFileUrl: _str(json, ['contract_file_url', 'contractFileUrl']),
    );
  }
}

class DepositRoom {
  const DepositRoom({
    required this.roomCode,
    required this.roomName,
    required this.area,
    required this.imageUrl,
  });

  final String roomCode;
  final String roomName;
  final double? area;
  final String imageUrl;

  factory DepositRoom.fromJson(Map<String, dynamic> json) {
    return DepositRoom(
      roomCode: _str(json, ['room_code', 'roomCode', 'code']),
      roomName: _str(json, ['room_name', 'roomName', 'name']),
      area: _dbl(json, ['area', 'area_m2', 'room_area']),
      imageUrl: _str(json, ['image_url', 'imageUrl', 'room_image_url']),
    );
  }
}

// ── helpers ──

Map<String, dynamic> _firstMap(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
  }
  return const {};
}

String _str(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') return value;
  }
  return '';
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _dbl(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? _date(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final parsed = DateTime.tryParse(json[key]?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}
