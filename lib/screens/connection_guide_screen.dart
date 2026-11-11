import 'package:flutter/material.dart';

import 'bluetooth_devices_screen.dart';

class ConnectionGuideScreen extends StatelessWidget {
  const ConnectionGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection Guide')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Arduino + Bluetooth',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'For Arduino Uno firmware using SoftwareSerial '
                  'RX = D2, TX = D3 at 9600 baud.',
            ),
            const SizedBox(height: 20),
            _section(
              '1. Wire with power disconnected',
              [
                const Text(
                  'Unplug the Arduino before moving wires. Read the module '
                      'labels; wire colours are not standard.',
                ),
                const SizedBox(height: 16),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                  },
                  children: [
                    for (final row in const [
                      ['Module', 'Arduino Uno'],
                      ['TXD', 'D2 (receive)'],
                      ['RXD', 'D3 through a 5V-to-3.3V divider'],
                      ['GND', 'GND (common ground)'],
                      ['VCC', '5V only for a breakout marked 3.6–6V'],
                      ['STATE / EN', 'Leave disconnected for this setup'],
                    ])
                      TableRow(
                        children: [
                          for (final text in row)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 8,
                                bottom: 12,
                              ),
                              child: Text(text),
                            ),
                        ],
                      ),
                  ],
                ),
                const Text(
                  'RXD divider: D3 → 1 kΩ resistor → junction → RXD. '
                      'Connect a 2 kΩ resistor from that junction to GND. '
                      'Direct 5V can damage a 3.3V RXD input.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use the sockets labelled 2 and ~3, '
                      'not 0/RX and 1/TX.',
                ),
              ],
            ),
            _section(
              '2. Upload matching firmware',
              const [
                Text(
                  'Download the Arduino sketch and JSON layout from the '
                      'same web-editor design. Upload the sketch to your Uno '
                      'using Arduino IDE, then power the board.',
                ),
                SizedBox(height: 8),
                Text(
                  'The module UART speed must match 9600 baud. '
                      'Hardware actions must be coded in the sketch; placing '
                      'a widget does not assign an Arduino pin automatically.',
                ),
              ],
            ),
            _section(
              '3. Pair and connect',
              [
                const Text(
                  'Pair HC-05 / HC-06 in your Android Bluetooth settings '
                      'using the module PIN. Then open Bluetooth Devices in '
                      'GRIDMOTE, allow requested permissions, choose the '
                      'paired module and tap Connect.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BluetoothDevicesScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('Bluetooth Devices'),
                ),
              ],
            ),
            _section(
              '4. Open your controls',
              const [
                Text(
                  'Import the matching JSON and tap Save to My Projects. '
                      'On Home, choose Live Control Panel, select your saved '
                      'layout and tap Start live.',
                ),
                SizedBox(height: 8),
                Text(
                  'Wait for “LIVE • Arduino layout verified”. In the '
                      'six-widget LED test sketch, button ID 5 drives the '
                      'built-in L LED, and LED widget ID 4 displays its state. '
                      'Hold to turn on; release to turn off.',
                ),
                SizedBox(height: 8),
                Text(
                  'Joystick values are transmitted, but the LED test '
                      'sketch does not attach them to a motor or servo. '
                      'Buzzer/audio is not implemented.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Troubleshooting',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in const [
              [
                'No Arduino reply',
                'Check board power, common GND, TXD → D2, '
                    'D3 → RXD through the divider, matching baud rate '
                    'and the uploaded GRIDMOTE v2 sketch. '
                    'Pairing alone does not verify Arduino communication.',
              ],
              [
                'Layout mismatch',
                'Use JSON exported from the same design as the uploaded '
                    'sketch. Changed labels, positions or widget IDs '
                    'require matching exports.',
              ],
              [
                'Start live is disabled',
                'Connect from Bluetooth Devices first. If live mode is '
                    'already running, Stop live is enabled instead.',
              ],
              [
                'No saved layouts',
                'Import a JSON layout and tap Save to My Projects '
                    'on its details page.',
              ],
              [
                'LED does not respond',
                'Check that live mode is verified and the sketch has a '
                    'hardware action for the correct button ID. '
                    'Use the built-in L LED for the LED test.',
              ],
            ])
              Card(
                child: ExpansionTile(
                  title: Text(item[0]),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(item[1]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}