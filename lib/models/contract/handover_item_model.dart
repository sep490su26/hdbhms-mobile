class HandoverItem {
  const HandoverItem({
    required this.id,
    required this.assetName,
    required this.quantity,
    required this.conditionStatus,
    required this.note,
    required this.evidenceFileId,
    required this.evidenceFileUrl,
  });

  final int? id;
  final String assetName;
  final int quantity;
  final String conditionStatus;
  final String note;
  final int? evidenceFileId;
  final String evidenceFileUrl;

  factory HandoverItem.fromJson(Map<String, dynamic> json) {
    return HandoverItem(
      id: _asInt(
        json['id'] ?? json['handover_item_id'] ?? json['handoverItemId'],
      ),
      assetName: _firstString(json, const ['assetName', 'asset_name', 'name']),
      quantity: _asInt(json['quantity']) ?? 1,
      conditionStatus: _firstString(json, const [
        'conditionStatus',
        'condition_status',
        'currentCondition',
        'current_condition',
      ], fallback: 'GOOD'),
      note: _firstString(json, const ['note', 'description']),
      evidenceFileId: _asInt(
        json['evidenceFileId'] ??
            json['evidence_file_id'] ??
            json['fileImageId'] ??
            json['file_image_id'],
      ),
      evidenceFileUrl: _firstString(json, const [
        'evidenceFileUrl',
        'evidence_file_url',
        'imageUrl',
        'image_url',
      ]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetName': assetName,
      'quantity': quantity,
      'conditionStatus': conditionStatus,
      'note': note,
      'evidenceFileId': evidenceFileId,
      'evidenceFileUrl': evidenceFileUrl,
    };
  }
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
