import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

import '../services/bluetooth_service.dart';

class DeviceDetailsScreen extends StatelessWidget {
  final BluetoothDevice device;

  const DeviceDetailsScreen({
    super.key,
    required this.device,
  });

  Future<void> _connect(BuildContext context) async {
    try {
      await BluetoothService.instance.connect(device);
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _disconnect(BuildContext context) async {
    try {
      await BluetoothService.instance.disconnect();
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = BluetoothService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Details'),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: service,
          builder: (context, _) {
            final connected = service.connectedTo(device.address);

            final anotherConnected =
                service.isConnected && !connected;

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  connected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth,
                  size: 80,
                  color: connected
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFF38BDF8),
                ),
                const SizedBox(height: 24),
                Text(
                  device.name ?? 'Unnamed device',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  device.address,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connection Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          anotherConnected
                              ? 'Another device is connected. '
                              'Disconnect it first.'
                              : service.status,
                        ),
                        if (connected) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Received: ${service.receivedBytes} bytes',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (service.busy)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                  service.busy || connected || anotherConnected
                      ? null
                      : () => _connect(context),
                  icon: const Icon(Icons.link),
                  label: const Text('Connect'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: service.busy || !connected
                      ? null
                      : () => _disconnect(context),
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'This step tests the Bluetooth connection only. '
                      'Arduino controls will be linked in the next step.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
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