import 'package:hdbhms_mobile/models/contract/handover_item_model.dart';

class HandoverRecord {
  const HandoverRecord({
    required this.handoverRecordId,
    required this.handoverType,
    required this.status,
    required this.handoverDate,
    required this.note,
    required this.signedDocumentId,
    required this.items,
    this.isFromCache = false,
  });

  final int? handoverRecordId;
  final String handoverType;
  final String status;
  final DateTime? handoverDate;
  final String note;
  final int? signedDocumentId;
  final List<HandoverItem> items;
  final bool isFromCache;

  factory HandoverRecord.fromJson(Map<String, dynamic> json) {
    final itemsValue =
        json['items'] ?? json['handover_items'] ?? json['handoverItems'];
    return HandoverRecord(
      handoverRecordId: _asInt(
        json['handoverRecordId'] ?? json['handover_record_id'] ?? json['id'],
      ),
      handoverType: _firstString(json, const [
        'handoverType',
        'handover_type',
      ], fallback: 'MOVE_IN'),
      status: _firstString(json, const ['status']),
      handoverDate: _firstDate(json, const ['handoverDate', 'handover_date']),
      note: _firstString(json, const ['note']),
      signedDocumentId: _asInt(
        json['signedDocumentId'] ?? json['signed_document_id'],
      ),
      items: itemsValue is List
          ? itemsValue
                .whereType<Map<String, dynamic>>()
                .map(HandoverItem.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  HandoverRecord copyWith({bool? isFromCache}) {
    return HandoverRecord(
      handoverRecordId: handoverRecordId,
      handoverType: handoverType,
      status: status,
      handoverDate: handoverDate,
      note: note,
      signedDocumentId: signedDocumentId,
      items: items,
      isFromCache: isFromCache ?? this.isFromCache,
    );
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

DateTime? _firstDate(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final parsed = DateTime.tryParse(json[key]?.toString() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}
