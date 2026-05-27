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
      actionKey: json['action_key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      completed: json['completed'] == true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      actionUrl: json['action_url']?.toString(),
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
