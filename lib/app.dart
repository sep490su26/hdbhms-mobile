import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hdbhms_mobile/config/app_config.dart';
import 'package:hdbhms_mobile/models/onboarding_state.dart';
import 'package:hdbhms_mobile/screens/auth/change_password_page.dart';
import 'package:hdbhms_mobile/screens/home/home_screen.dart';
import 'package:hdbhms_mobile/screens/auth/identity_verification_page.dart';
import 'package:hdbhms_mobile/screens/auth/login_page.dart';
import 'package:hdbhms_mobile/services/auth/auth_service.dart';
import 'package:hdbhms_mobile/services/home/home_service.dart';
import 'package:hdbhms_mobile/services/payment/tenant_invoice_service.dart';
import 'package:hdbhms_mobile/services/profileRequest/tenant_profile_service.dart';
import 'package:hdbhms_mobile/screens/auth/reset_password_page.dart';
import 'package:hdbhms_mobile/screens/splash/app_splash_screen.dart';
import 'package:hdbhms_mobile/services/deep_link_service.dart';
import 'package:hdbhms_mobile/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    this.authService = const AuthService(),
    this.homeService = const HomeService(),
    this.profileService = const TenantProfileService(),
    this.tenantInvoiceService = const TenantInvoiceService(),
  });

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final AuthService authService;
  final HomeService homeService;
  final TenantProfileService profileService;
  final TenantInvoiceService tenantInvoiceService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: App.navigatorKey,
      theme: AppTheme.lightTheme,
      home: _AppRoot(
        authService: authService,
        homeService: homeService,
        profileService: profileService,
        tenantInvoiceService: tenantInvoiceService,
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot({
    required this.authService,
    required this.homeService,
    required this.profileService,
    required this.tenantInvoiceService,
  });

  final AuthService authService;
  final HomeService homeService;
  final TenantProfileService profileService;
  final TenantInvoiceService tenantInvoiceService;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late Future<Widget> _startPageFuture;

  @override
  void initState() {
    super.initState();
    _startPageFuture = _resolveStartPage();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    DeepLinkService.instance.initialize();
    DeepLinkService.instance.onResetPasswordToken.listen((token) {
      _handleResetPasswordToken(token);
    });
  }

  void _handleResetPasswordToken(String token) {
    App.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => ResetPasswordPage(token: token)),
    );
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  Future<Widget> _resolveStartPage() async {
    final minimumSplashTime = Future<void>.delayed(
      const Duration(milliseconds: 1800),
    );
    final prefs = await SharedPreferences.getInstance();
    final token = await widget.authService.accessToken;
    final sessionId = prefs.getString(AuthService.sessionIdKey);
    final hasToken = token != null && token.isNotEmpty;
    final hasSessionId = sessionId != null && sessionId.isNotEmpty;

    if (!hasToken && !hasSessionId) {
      await minimumSplashTime;
      return LoginPage(
        authService: widget.authService,
        homeService: widget.homeService,
        tenantInvoiceService: widget.tenantInvoiceService,
      );
    }

    try {
      final onboarding = await widget.authService.fetchOnboarding();
      await minimumSplashTime;
      return _pageFor(onboarding);
    } on SessionExpiredException {
      await minimumSplashTime;
      return LoginPage(
        authService: widget.authService,
        homeService: widget.homeService,
        tenantInvoiceService: widget.tenantInvoiceService,
      );
    } on AuthException {
      final cachedOnboarding = await widget.authService.getCachedOnboarding();
      if (cachedOnboarding != null) {
        await minimumSplashTime;
        return _pageFor(cachedOnboarding);
      }
      await minimumSplashTime;
      return LoginPage(
        authService: widget.authService,
        homeService: widget.homeService,
        tenantInvoiceService: widget.tenantInvoiceService,
      );
    }
  }

  Widget _pageFor(OnboardingState onboarding) {
    if (onboarding.onBoardingCompleted) {
      return HomeScreen(
        authService: widget.authService,
        homeService: widget.homeService,
        profileService: widget.profileService,
        tenantInvoiceService: widget.tenantInvoiceService,
      );
    }

    final nextStep = onboarding.nextStep;
    return switch (nextStep) {
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
        tenantInvoiceService: widget.tenantInvoiceService,
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

        return const AppSplashScreen();
      },
    );
  }
}
