import 'package:hdbhms_mobile/models/onboarding_action.dart';

class OnboardingState {
  const OnboardingState({
    required this.userId,
    required this.onBoardingCompleted,
    required this.actions,
  });

  final int? userId;
  final bool onBoardingCompleted;
  final List<OnboardingAction> actions;

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    final actionsJson = json['actions'];
    final actions = actionsJson is List
        ? actionsJson
              .whereType<Map<String, dynamic>>()
              .map(OnboardingAction.fromJson)
              .toList()
        : <OnboardingAction>[];
    final completed =
        json['onBoardingCompleted'] == true ||
        json['on_boarding_completed'] == true;

    if (actions.isEmpty && !completed) {
      final legacyStep =
          json['nextStep']?.toString() ?? json['next_step']?.toString();
      if (legacyStep != null && legacyStep != home) {
        actions.add(
          OnboardingAction(
            actionKey: legacyStep,
            label: legacyStep,
            completed: false,
            priority: 1,
          ),
        );
      }
    }

    return OnboardingState(
      userId: int.tryParse(
        (json['userId'] ?? json['user_id'])?.toString() ?? '',
      ),
      onBoardingCompleted: completed,
      actions: actions,
    );
  }

  static const changePassword = 'CHANGE_PASSWORD';
  static const identityVerification = 'IDENTITY_VERIFICATION';
  static const home = 'HOME';

  String get nextStep {
    if (onBoardingCompleted) return home;

    if (actions.isEmpty) return home;

    final sortedActions = List<OnboardingAction>.from(actions)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final nextAction = sortedActions.firstWhere(
      (action) => !action.completed,
      orElse: () => sortedActions.first,
    );

    return nextAction.actionKey;
  }

  bool get mustChangePassword =>
      actions.any((a) => a.actionKey == changePassword && !a.completed);

  bool get identityCompleted =>
      actions.any((a) => a.actionKey == identityVerification && a.completed);

  @override
  String toString() {
    return 'OnboardingState{userId: $userId, onBoardingCompleted: $onBoardingCompleted, actions: $actions}';
  }
}
