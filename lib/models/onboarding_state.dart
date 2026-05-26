import 'onboarding_action.dart';

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
    return OnboardingState(
      userId: int.tryParse(json['userId']?.toString() ?? ''),
      onBoardingCompleted: json['onBoardingCompleted'] == true,
      actions: actionsJson is List
          ? actionsJson
                .whereType<Map<String, dynamic>>()
                .map(OnboardingAction.fromJson)
                .toList()
          : const [],
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

  bool get mustChangePassword => actions.any(
    (a) => a.actionKey == changePassword && !a.completed
  );

  bool get identityCompleted => actions.any(
    (a) => a.actionKey == identityVerification && a.completed
  );
}
