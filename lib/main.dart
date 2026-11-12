import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/app_settings.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppSettings.instance.load();
  await AuthService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0B1120)
          : const Color(0xFFF1F5F9),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0284C7),
        brightness: brightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppSettings.instance,
        AuthService.instance,
      ]),
      builder: (context, child) {
        final auth = AuthService.instance;

        Widget firstScreen;

        if (!auth.ready) {
          firstScreen = Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (auth.busy)
                        const CircularProgressIndicator()
                      else ...[
                        const Icon(Icons.lock_outline, size: 56),
                        const SizedBox(height: 16),
                        Text(
                          auth.startupError ?? 'Account storage is unavailable.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: auth.initialize,
                          child: const Text('Retry'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (auth.currentUser == null) {
          firstScreen = const LoginScreen();
        } else {
          firstScreen = const WelcomeScreen();
        }

        return MaterialApp(
          key: ValueKey(auth.currentUser?.id ?? 'signed-out'),
          title: 'GRIDMOTE',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: AppSettings.instance.themeMode,
          home: firstScreen,
        );
      },
    );
  }
}
