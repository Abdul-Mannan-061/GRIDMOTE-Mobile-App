import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/bluetooth_service.dart';
import 'device_details_screen.dart';

class BluetoothDevicesScreen extends StatefulWidget {
  const BluetoothDevicesScreen({super.key});

  @override
  State<BluetoothDevicesScreen> createState() =>
      _BluetoothDevicesScreenState();
}

class _BluetoothDevicesScreenState
    extends State<BluetoothDevicesScreen> {
  final _service = BluetoothService.instance;

  List<BluetoothDevice> _devices = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDevices();
    });
  }

  Future<void> _loadDevices() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final devices = await _service.pairedDevices();

      if (!mounted) return;

      setState(() {
        _devices = devices;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _devices = [];
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openDevice(BluetoothDevice device) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceDetailsScreen(device: device),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Devices'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadDevices,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload paired devices',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(
              Icons.bluetooth,
              size: 64,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(height: 20),
            const Text(
              'Paired Devices',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select your HC-06 module. New devices must first '
                  'be paired in your phone’s Bluetooth settings.',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await openAppSettings();
                },
                child: const Text('Open App Permissions'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _loadDevices,
                child: const Text('Try Again'),
              ),
            ],
            if (!_loading && _error == null && _devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No paired devices found. Pair HC-06 in phone '
                      'settings, then tap Refresh.',
                ),
              ),
            for (final device in _devices)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(
                    Icons.bluetooth,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(device.name ?? 'Unnamed device'),
                  subtitle: Text(device.address),
                  trailing: Icon(
                    _service.connectedTo(device.address)
                        ? Icons.check_circle
                        : Icons.chevron_right,
                  ),
                  onTap: () => _openDevice(device),
                ),
              ),
          ],
        ),
      ),
    );
  }
}