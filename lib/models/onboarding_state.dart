class OnboardingState {
  const OnboardingState({
    required this.userId,
    required this.mustChangePassword,
    required this.identityCompleted,
    required this.nextStep,
  });

  static const changePassword = 'CHANGE_PASSWORD';
  static const identityVerification = 'IDENTITY_VERIFICATION';
  static const home = 'HOME';

  final int? userId;
  final bool mustChangePassword;
  final bool identityCompleted;
  final String nextStep;

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    final mustChangePassword = json['must_change_password'] == true;
    final rawNextStep = json['next_step']?.toString() ?? home;

    return OnboardingState(
      userId: int.tryParse(json['user_id']?.toString() ?? ''),
      mustChangePassword: mustChangePassword,
      identityCompleted: json['identity_completed'] == true,
      nextStep: _mobileNextStep(
        rawNextStep: rawNextStep,
        mustChangePassword: mustChangePassword,
      ),
    );
  }
}

String _mobileNextStep({
  required String rawNextStep,
  required bool mustChangePassword,
}) {
  if (mustChangePassword) {
    return OnboardingState.changePassword;
  }

  // Identity verification disabled for mobile onboarding.
  if (rawNextStep == OnboardingState.identityVerification) {
    return OnboardingState.home;
  }

  return rawNextStep;
}
