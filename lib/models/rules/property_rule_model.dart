class PropertyRulesResponse {
  const PropertyRulesResponse({
    required this.updatedAt,
    required this.bannerImageUrl,
    required this.items,
    this.isFromCache = false,
  });

  final DateTime? updatedAt;
  final String bannerImageUrl;
  final List<PropertyRule> items;
  final bool isFromCache;

  PropertyRulesResponse copyWith({bool? isFromCache}) {
    return PropertyRulesResponse(
      updatedAt: updatedAt,
      bannerImageUrl: bannerImageUrl,
      items: items,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  factory PropertyRulesResponse.fromJson(Map<String, dynamic> json) {
    final source = _firstMap(json, const ['data', 'rulesData']);
    final data = source.isEmpty ? json : source;
    final rawItems = json['data'] is List
        ? json['data']
        : json['rulesData'] is List
        ? json['rulesData']
        : data['items'] ?? data['rules'] ?? const [];

    return PropertyRulesResponse(
      updatedAt: _firstDate(data, const ['updatedAt', 'updated_at']),
      bannerImageUrl: _firstString(data, const [
        'bannerImageUrl',
        'banner_image_url',
        'imageUrl',
        'image_url',
      ]),
      items:
          _asList(rawItems)
              .whereType<Map<String, dynamic>>()
              .map(PropertyRule.fromJson)
              .where((rule) => rule.isActive)
              .toList(growable: false)
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }
}

class PropertyRule {
  const PropertyRule({
    required this.id,
    required this.ruleCode,
    required this.category,
    required this.title,
    required this.description,
    required this.defaultFineAmount,
    required this.fineUnit,
    required this.sortOrder,
    required this.status,
  });

  final int? id;
  final String ruleCode;
  final RuleCategory category;
  final String title;
  final String description;
  final double? defaultFineAmount;
  final String fineUnit;
  final int sortOrder;
  final String status;

  bool get isActive {
    final normalized = status.trim().toUpperCase();
    return normalized.isEmpty || normalized == 'ACTIVE';
  }

  factory PropertyRule.fromJson(Map<String, dynamic> json) {
    final ruleCode = _firstString(json, const [
      'ruleCode',
      'rule_code',
      'code',
    ]);
    final rawCategory = _firstString(json, const [
      'ruleCategory',
      'rule_category',
      'category',
    ]);

    return PropertyRule(
      id: _asInt(json['id']),
      ruleCode: ruleCode,
      category: RuleCategory.fromBackend(rawCategory, ruleCode),
      title: _firstString(json, const ['title', 'name']),
      description: _firstString(json, const ['description', 'content', 'text']),
      defaultFineAmount: _firstDouble(json, const [
        'defaultFineAmount',
        'default_fine_amount',
        'fineAmount',
        'fine_amount',
      ]),
      fineUnit: _firstString(json, const ['fineUnit', 'fine_unit', 'unit']),
      sortOrder:
          _asInt(json['sortOrder'] ?? json['sort_order'] ?? json['order']) ??
          9999,
      status: _firstString(json, const ['status']),
    );
  }
}

enum RuleCategory {
  general,
  security,
  hygiene,
  utility,
  fine,
  other;

  static RuleCategory fromBackend(String value, String ruleCode) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isNotEmpty) {
      return switch (normalized) {
        'GENERAL' => RuleCategory.general,
        'SECURITY' => RuleCategory.security,
        'HYGIENE' => RuleCategory.hygiene,
        'UTILITY' => RuleCategory.utility,
        'FINE' => RuleCategory.fine,
        _ => RuleCategory.other,
      };
    }

    final code = ruleCode.trim().toUpperCase();
    if (code.startsWith('GENERAL_')) {
      return RuleCategory.general;
    }
    if (code.startsWith('SECURITY_')) {
      return RuleCategory.security;
    }
    if (code.startsWith('HYGIENE_')) {
      return RuleCategory.hygiene;
    }
    if (code.startsWith('UTILITY_')) {
      return RuleCategory.utility;
    }
    if (code.startsWith('FINE_') ||
        code.contains('WIFI_RESET') ||
        code.contains('UNAUTHORIZED_REPAIR')) {
      return RuleCategory.fine;
    }
    return RuleCategory.other;
  }
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

List<Object?> _asList(Object? value) {
  if (value is List) {
    return value;
  }
  return const [];
}

String _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') {
      return value;
    }
  }
  return '';
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

DateTime? _firstDate(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final parsed = DateTime.tryParse(json[key]?.toString() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}
