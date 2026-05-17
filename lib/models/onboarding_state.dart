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
    return OnboardingState(
      userId: int.tryParse(json['user_id']?.toString() ?? ''),
      mustChangePassword: json['must_change_password'] == true,
      identityCompleted: json['identity_completed'] == true,
      nextStep: json['next_step']?.toString() ?? home,
    );
  }
}
