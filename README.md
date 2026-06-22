# hdbhms_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

## Local backend connection

The app reads API URLs from Dart defines first, then falls back to emulator defaults.

Android Emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1 --dart-define=FRONTEND_BASE_URL=http://10.0.2.2:3000
```

Android real device over USB/Wi-Fi:

1. Make sure the phone and laptop are on the same LAN.
2. Find the laptop IPv4 address, for example `192.168.1.23`.
3. Start Spring Boot bound to all interfaces or the LAN interface on port `8080`.
4. Run:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8080/api/v1 --dart-define=FRONTEND_BASE_URL=http://192.168.1.23:3000
```

Do not use `localhost`, `127.0.0.1`, or `10.0.2.2` for a real Android device. `10.0.2.2` is only for Android Emulator.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
