import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'screens/identity_verification_page.dart';
import 'screens/login_page.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: {
        '/identity-verification': (context) => const IdentityVerificationPage(),
      },
      home: const LoginPage(),
    );
  }
}
