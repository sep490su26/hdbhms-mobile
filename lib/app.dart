import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'models/onboarding_state.dart';
import 'screens/change_password_page.dart';
import 'screens/home_screen.dart';
import 'screens/identity_verification_page.dart';
import 'screens/login_page.dart';
import 'services/auth_service.dart';
import 'services/home_service.dart';
import 'services/tenant_profile_service.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    this.authService = const AuthService(),
    this.homeService = const HomeService(),
    this.profileService = const TenantProfileService(),
  });

  final AuthService authService;
  final HomeService homeService;
  final TenantProfileService profileService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: {
        '/identity-verification': (context) =>
            const CompleteProfileUploadScreen(),
      },
      home: _AppRoot(
        authService: authService,
        homeService: homeService,
        profileService: profileService,
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot({
    required this.authService,
    required this.homeService,
    required this.profileService,
  });

  final AuthService authService;
  final HomeService homeService;
  final TenantProfileService profileService;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late Future<Widget> _startPageFuture;

  @override
  void initState() {
    super.initState();
    _startPageFuture = _resolveStartPage();
  }

  Future<Widget> _resolveStartPage() async {
    final token = await widget.authService.accessToken;
    if (token == null || token.isEmpty) {
      return LoginPage(
        authService: widget.authService,
        homeService: widget.homeService,
      );
    }

    try {
      final onboarding = await widget.authService.fetchOnboarding();
      return _pageFor(onboarding);
    } on AuthException {
      final cachedOnboarding = await widget.authService.getCachedOnboarding();
      if (cachedOnboarding != null) {
        return _pageFor(cachedOnboarding);
      }
      return LoginPage(
        authService: widget.authService,
        homeService: widget.homeService,
      );
    }
  }

  Widget _pageFor(OnboardingState onboarding) {
    return switch (onboarding.nextStep) {
      OnboardingState.changePassword => ChangePasswordPage(
        authService: widget.authService,
        homeService: widget.homeService,
        isRequired: true,
      ),
      OnboardingState.identityVerification => CompleteProfileUploadScreen(
        isRequired: true,
        authService: widget.authService,
        homeService: widget.homeService,
      ),
      _ => HomeScreen(
        authService: widget.authService,
        homeService: widget.homeService,
        profileService: widget.profileService,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _startPageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
