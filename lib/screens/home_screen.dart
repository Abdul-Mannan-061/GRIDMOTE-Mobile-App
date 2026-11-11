import 'package:flutter/material.dart';

import '../services/bluetooth_service.dart';
import 'bluetooth_devices_screen.dart';
import 'connection_guide_screen.dart';
import 'import_layout_screen.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GRIDMOTE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Your Control Hub',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your layouts and connect your devices.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: BluetoothService.instance,
              builder: (context, child) {
                final bluetooth = BluetoothService.instance;

                return Card(
                  color: colors.primaryContainer,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: Icon(
                      bluetooth.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth,
                      size: 36,
                      color: colors.onPrimaryContainer,
                    ),
                    title: Text(
                      bluetooth.isConnected
                          ? 'Connected to '
                          '${bluetooth.device?.name ?? "Bluetooth device"}'
                          : 'No device connected',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      bluetooth.status,
                      style: TextStyle(color: colors.onPrimaryContainer),
                    ),
                    onTap: () => _open(
                      context,
                      const BluetoothDevicesScreen(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _action(
              context,
              Icons.folder_outlined,
              'My Projects',
              'View your saved control layouts',
              const ProjectsScreen(),
            ),
            _action(
              context,
              Icons.file_upload_outlined,
              'Import Layout',
              'Load a layout from the web editor',
              const ImportLayoutScreen(),
            ),
            _action(
              context,
              Icons.bluetooth_searching,
              'Bluetooth Devices',
              'Connect to your Arduino Bluetooth module',
              const BluetoothDevicesScreen(),
            ),
            _action(
              context,
              Icons.sports_esports_outlined,
              'Live Control Panel',
              'Choose a saved layout to control',
              const ProjectsScreen(forControl: true),
            ),
            _action(
              context,
              Icons.help_outline,
              'Connection Guide',
              'Wiring, setup and troubleshooting',
              const ConnectionGuideScreen(),
            ),
            _action(
              context,
              Icons.settings_outlined,
              'Settings',
              'Appearance and app information',
              const SettingsScreen(),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => screen,
      ),
    );
  }

  Widget _action(
      BuildContext context,
      IconData icon,
      String title,
      String subtitle,
      Widget screen,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(context, screen),
      ),
    );
  }
}