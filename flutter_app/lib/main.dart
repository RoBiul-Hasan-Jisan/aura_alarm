import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'nav.dart';
import 'services/alarm_scheduler.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(SetupErrorApp(message: e.toString()));
    return;
  }
  try {
    await AlarmScheduler.init(); // real alarms (Android/iOS) or in-tab alarms (web)
  } catch (e) {
    debugPrint('Alarm init failed: $e');
  }
  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Aura Alarm',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        scrollBehavior: const AppScrollBehavior(),
        // On wide screens (web/desktop/tablet) keep the app a phone-width column over the glowing background.
        builder: (context, child) => AuraBackground(
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: child!)),
        ),
        home: const SplashScreen(next: AuthGate()),
      );
}

/// Chooses Login or Home from Firebase's auth state – this is also what makes logout instant.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: AuthService.changes,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snap.hasData ? const HomeShell() : const LoginScreen();
        },
      );
}

/// Shown when Firebase can't start, so the problem is visible instead of a blank screen.
class SetupErrorApp extends StatelessWidget {
  final String message;
  const SetupErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) => AuraBackground(child: child!),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.settings_suggest_outlined, size: 56, color: dawn),
                const SizedBox(height: 16),
                Text('Firebase setup needed', style: serif(22)),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
              ]),
            ),
          ),
        ),
      );
}

/// Lets mouse and trackpad users drag lists and the quote pager (Flutter web ignores mouse drags by default).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices =>
      {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus};
}
