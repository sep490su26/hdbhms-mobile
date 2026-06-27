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
                json['leaseContractId'] ??
                json['contractId'],
          ) ??
          0,
      contractCode: _str(json, ['contractCode', 'depositCode']),
      roomCode: _str(json, ['roomCode']),
      signedAt: _date(json, ['confirmedAt', 'signedAt', 'createdAt']),
      status: _str(json, ['signatureStatus', 'status']),
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
    final roomJson = _firstMap(json, ['room', 'roomInfo']);
    final signedFileId = _asInt(json['signedFileId']);
    final signedFileUrl = _str(json, [
      'signedFileDownloadUrl',
      'signedFileUrl',
    ]);

    return DepositContract(
      id: _asInt(json['id'] ?? json['depositAgreementId']),
      depositCode: _str(json, ['depositCode']),
      status: _str(json, ['status']),
      room: DepositRoom.fromJson(roomJson.isEmpty ? json : roomJson),
      amount: _dbl(json, ['amount', 'depositAmount']),
      expectedMoveInDate: _date(json, ['expectedMoveInDate']),
      expectedLeaseSignDate: _date(json, ['expectedLeaseSignDate']),
      depositExpiresAt: _date(json, ['depositExpiresAt']),
      createdAt: _date(json, ['createdAt', 'confirmedAt']),
      note: _str(json, ['note']),
      // Mobile chỉ hiển thị bản đã ký. Không fallback sang draft PDF khi chưa có signedFileId.
      contractFileUrl: signedFileUrl.isNotEmpty
          ? signedFileUrl
          : signedFileId != null
          ? _str(json, ['contractFileUrl'])
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
      roomCode: _str(json, ['roomCode', 'code']),
      roomName: _str(json, ['roomName', 'name']),
      area: _dbl(json, ['area', 'areaM2', 'roomArea']),
      imageUrl: _str(json, ['imageUrl']),
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
