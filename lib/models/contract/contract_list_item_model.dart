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
      id:
          _asInt(
            json['id'] ??
                json['depositAgreementId'] ??
                json['deposit_agreement_id'] ??
                json['leaseContractId'] ??
                json['lease_contract_id'] ??
                json['contractId'] ??
                json['contract_id'],
          ) ??
          0,
      contractCode: _str(json, [
        'contractCode',
        'depositCode',
        'contract_code',
        'deposit_code',
      ]),
      roomCode: _str(json, ['roomCode', 'room_code']),
      signedAt: _date(json, [
        'confirmedAt',
        'signedAt',
        'createdAt',
        'confirmed_at',
        'signed_at',
        'created_at',
      ]),
      status: _str(json, ['signatureStatus', 'signature_status', 'status']),
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
    final roomJson = _firstMap(json, ['room', 'roomInfo', 'room_info']);
    final signedFileId = _asInt(json['signedFileId'] ?? json['signed_file_id']);
    final signedFileUrl = _str(json, [
      'signedFileDownloadUrl',
      'signedFileUrl',
      'signed_file_download_url',
      'signed_file_url',
    ]);

    return DepositContract(
      id: _asInt(
        json['id'] ??
            json['depositAgreementId'] ??
            json['deposit_agreement_id'],
      ),
      depositCode: _str(json, ['depositCode', 'deposit_code']),
      status: _str(json, ['status']),
      room: DepositRoom.fromJson(roomJson.isEmpty ? json : roomJson),
      amount: _dbl(json, ['amount', 'depositAmount', 'deposit_amount']),
      expectedMoveInDate: _date(json, [
        'expectedMoveInDate',
        'expected_move_in_date',
      ]),
      expectedLeaseSignDate: _date(json, [
        'expectedLeaseSignDate',
        'expected_lease_sign_date',
      ]),
      depositExpiresAt: _date(json, ['depositExpiresAt', 'deposit_expires_at']),
      createdAt: _date(json, [
        'createdAt',
        'confirmedAt',
        'created_at',
        'confirmed_at',
      ]),
      note: _str(json, ['note']),
      // Mobile chỉ hiển thị bản đã ký. Không fallback sang draft PDF khi chưa có signedFileId.
      contractFileUrl: signedFileUrl.isNotEmpty
          ? signedFileUrl
          : signedFileId != null
          ? _str(json, ['contractFileUrl', 'contract_file_url'])
          : '',
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
      roomCode: _str(json, ['roomCode', 'room_code', 'code']),
      roomName: _str(json, ['roomName', 'room_name', 'name']),
      area: _dbl(json, ['area', 'areaM2', 'roomArea', 'area_m2', 'room_area']),
      imageUrl: _str(json, [
        'imageUrl',
        'roomImageUrl',
        'image_url',
        'room_image_url',
      ]),
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
