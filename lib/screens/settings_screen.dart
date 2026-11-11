import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'Bluetooth will disconnect. Your saved projects will remain '
                'in your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() => _loggingOut = true);

    try {
      await AuthService.instance.logout();
      // main.dart automatically returns to Login and clears navigation.
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AuthException
                ? error.message
                : 'Could not log out. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: AppSettings.instance,
          builder: (context, child) {
            final settings = AppSettings.instance;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Your Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(user?.name ?? 'Not signed in'),
                    subtitle: Text(user?.email ?? ''),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loggingOut ? null : _logout,
                  icon: _loggingOut
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.logout),
                  label: Text(_loggingOut ? 'Logging out…' : 'Log Out'),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Theme preferences apply to both users on this device.',
                ),
                const SizedBox(height: 16),
                for (final entry in const [
                  (
                  ThemeMode.dark,
                  Icons.dark_mode_outlined,
                  'Dark',
                  'GRIDMOTE dark appearance',
                  ),
                  (
                  ThemeMode.light,
                  Icons.light_mode_outlined,
                  'Light',
                  'A brighter interface',
                  ),
                  (
                  ThemeMode.system,
                  Icons.brightness_auto_outlined,
                  'System',
                  'Follow your phone settings',
                  ),
                ])
                  Card(
                    child: ListTile(
                      enabled: !settings.saving && !_loggingOut,
                      selected: settings.themeMode == entry.$1,
                      leading: Icon(entry.$2),
                      title: Text(entry.$3),
                      subtitle: Text(entry.$4),
                      trailing: settings.themeMode == entry.$1
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () => settings.setTheme(entry.$1),
                    ),
                  ),
                if (settings.saving) const LinearProgressIndicator(),
                if (settings.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      settings.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 28),
                const Text(
                  'About GRIDMOTE',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Design • Connect • Control',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Import a web-editor layout, connect your Arduino '
                              'over Bluetooth, and control your devices.',
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Built with Flutter and Dart for the '
                              'Mobile Application Development course.',
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Connection: Android Bluetooth Classic, '
                              'HC-05 / HC-06.\n'
                              'Firmware protocol: GRIDMOTE v2.',
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Live support: button, joystick and LED state. '
                              'Buzzer/audio and other live widgets '
                              'are not implemented yet.',
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Accounts and projects are local to this phone. '
                              'Each user has a separate saved-project list. '
                              'There is no cloud sync or email recovery.',
                        ),
                        SizedBox(height: 12),
                        Text(
                          'The control canvas keeps its dark styling.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}