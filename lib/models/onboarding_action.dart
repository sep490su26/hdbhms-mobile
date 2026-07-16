class OnboardingAction {
  const OnboardingAction({
    required this.actionKey,
    required this.label,
    required this.completed,
    required this.priority,
    this.actionUrl,
  });

  final String actionKey;
  final String label;
  final bool completed;
  final int priority;
  final String? actionUrl;

  factory OnboardingAction.fromJson(Map<String, dynamic> json) {
    return OnboardingAction(
      actionKey:
          json['actionKey']?.toString() ?? json['action_key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      completed: _asBool(json['completed']),
      priority: _asInt(json['priority']) ?? 0,
      actionUrl:
          json['actionUrl']?.toString() ?? json['action_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actionKey': actionKey,
      'label': label,
      'completed': completed,
      'priority': priority,
      'actionUrl': actionUrl,
    };
  }

  @override
  String toString() {
    return 'OnboardingAction{actionKey: $actionKey, label: $label, completed: $completed, priority: $priority, actionUrl: $actionUrl}';
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}
