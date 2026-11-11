import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/project_model.dart';
import '../services/bluetooth_service.dart';

class LiveControlScreen extends StatefulWidget {
  final ProjectModel project;

  const LiveControlScreen({super.key, required this.project});

  @override
  State<LiveControlScreen> createState() => _LiveControlScreenState();
}

class _LiveControlScreenState extends State<LiveControlScreen>
    with WidgetsBindingObserver {
  final BluetoothService _bluetooth = BluetoothService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bluetooth.addListener(_onBluetoothChanged);
  }

  void _onBluetoothChanged() {
    if (!mounted) return;
    setState(() {
      if (!_bluetooth.controlReady) {
        _buttons.clear();
        _joysticks.clear();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _buttons.clear();
      _joysticks.clear();
      unawaited(_bluetooth.stopControl());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bluetooth.removeListener(_onBluetoothChanged);
    unawaited(_bluetooth.stopControl());
    super.dispose();
  }

  Future<void> _startLive() async {
    _reset();
    await _bluetooth.startControl(
      width: widget.project.canvasWidth,
      height: widget.project.canvasHeight,
      widgets: widget.project.widgets,
    );
  }

  Future<void> _stopLive() async {
    _buttons.clear();
    _joysticks.clear();
    await _bluetooth.stopControl();
  }

  bool get _canInteract =>
      !_bluetooth.controlChanging &&
          (_bluetooth.controlReady || !_bluetooth.isConnected);

  final Map<int, bool> _buttons = {};
  final Map<int, Offset> _joysticks = {};

  String _lastAction = 'Press a button or drag the joystick.';

  static const _supportedTypes = {'label', 'button', 'led', 'joystick'};

  void _setButton(int id, bool pressed) {
    if (!_canInteract) return;
    _bluetooth.setInput(id, pressed ? 1 : 0);
    setState(() {
      _buttons[id] = pressed;
      _lastAction = 'Button $id: ${pressed ? 1 : 0}';
    });
  }

  void _setJoystick(int id, Offset position) {
    if (!_canInteract) return;
    _bluetooth.setInput(
      id,
      (position.dx * 100).round(),
      (-position.dy * 100).round(),
    );
    setState(() {
      _joysticks[id] = position;

      final x = (position.dx * 100).round();
      final y = (-position.dy * 100).round();

      _lastAction = 'Joystick $id: X = $x, Y = $y';
    });
  }

  void _reset() {
    for (final item in widget.project.widgets) {
      if (item['type'] == 'button' || item['type'] == 'joystick') {
        _bluetooth.setInput(item['id'] as int, 0);
      }
    }
    setState(() {
      _buttons.clear();
      _joysticks.clear();
      _lastAction = 'Controls reset.';
    });
  }

  Widget _fitText(String text, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildWidget(Map<String, dynamic> item) {
    final id = item['id'] as int;
    final type = item['type'] as String;
    final label = item['label'] as String;

    switch (type) {
      case 'label':
        return Center(child: _fitText(label));

      case 'button':
        final pressed = _buttons[id] ?? false;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setButton(id, true),
          onTapUp: (_) => _setButton(id, false),
          onTapCancel: () => _setButton(id, false),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pressed
                  ? const Color(0xFF0284C7)
                  : const Color(0xFF38BDF8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: pressed ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: _fitText(label, color: const Color(0xFF082F49)),
          ),
        );

      case 'led':
        final value = _bluetooth.outputValue(id);
        return Tooltip(
          message:
          '$label: ${value == null ? 'Unknown — no live state' : (value != 0 ? 'ON' : 'OFF')}',
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value == null
                      ? const Color(0xFF374151)
                      : value != 0
                      ? Colors.greenAccent
                      : const Color(0xFF14532D),
                  border: Border.all(color: const Color(0xFF94A3B8), width: 2),
                ),
              ),
            ),
          ),
        );

      case 'joystick':
        return _buildJoystick(id, label);

      default:
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF422006),
            border: Border.all(color: Colors.orangeAccent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: _fitText('$type: not implemented', color: Colors.orangeAccent),
        );
    }
  }

  Widget _buildJoystick(int id, String label) {
    final position = _joysticks[id] ?? Offset.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final diameter = math.min(width, height);
        final thumbSize = diameter * 0.30;
        final travelRadius = diameter * 0.32;

        void updatePosition(Offset localPosition) {
          final center = Offset(width / 2, height / 2);
          var normalized = (localPosition - center) / travelRadius;

          // Restrict movement to a circle.
          if (normalized.distance > 1) {
            normalized = normalized / normalized.distance;
          }

          _setJoystick(id, normalized);
        }

        return Tooltip(
          message: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) {
              updatePosition(details.localPosition);
            },
            onPanUpdate: (details) {
              updatePosition(details.localPosition);
            },
            onPanEnd: (_) {
              _setJoystick(id, Offset.zero);
            },
            onPanCancel: () {
              _setJoystick(id, Offset.zero);
            },
            child: Stack(
              children: [
                Positioned(
                  left: (width - diameter) / 2,
                  top: (height - diameter) / 2,
                  width: diameter,
                  height: diameter,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E293B),
                      border: Border.all(
                        color: const Color(0xFF64748B),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: width / 2 - diameter * 0.35,
                  top: height / 2 - 0.5,
                  width: diameter * 0.70,
                  height: 1,
                  child: const ColoredBox(color: Color(0xFF475569)),
                ),
                Positioned(
                  left: width / 2 - 0.5,
                  top: height / 2 - diameter * 0.35,
                  width: 1,
                  height: diameter * 0.70,
                  child: const ColoredBox(color: Color(0xFF475569)),
                ),
                Positioned(
                  left: width / 2 + position.dx * travelRadius - thumbSize / 2,
                  top: height / 2 + position.dy * travelRadius - thumbSize / 2,
                  width: thumbSize,
                  height: thumbSize,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF38BDF8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;

    final hasUnsupportedWidgets = project.widgets.any(
          (item) => !_supportedTypes.contains(item['type']),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Control Panel'),
        actions: [
          IconButton(
            onPressed: _reset,
            tooltip: 'Reset controls',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF172554),
              child: Text(
                _bluetooth.controlChanging
                    ? 'Please wait • ${_bluetooth.controlStatus}'
                    : _bluetooth.controlStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7DD3FC),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed:
                    _bluetooth.isConnected &&
                        !_bluetooth.controlReady &&
                        !_bluetooth.controlChanging &&
                        !_bluetooth.busy
                        ? _startLive
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start live'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _bluetooth.controlReady ? _stopLive : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop live'),
                  ),
                ],
              ),
            ),
            if (!_bluetooth.isConnected)
              const Text(
                'Preview only. Connect HC-06 from Bluetooth Devices.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            if (hasUnsupportedWidgets)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Live controls support button and joystick; LED shows Arduino state. '
                      'Buzzer/audio and other widgets are not implemented yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: project.canvasWidth,
                      height: project.canvasHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            for (final item in project.widgets)
                              Positioned(
                                key: ValueKey(item['id']),
                                left: (item['x'] as num).toDouble(),
                                top: (item['y'] as num).toDouble(),
                                width: (item['w'] as num).toDouble(),
                                height: (item['h'] as num).toDouble(),
                                child: IgnorePointer(
                                  ignoring: !_canInteract,
                                  child: _buildWidget(item),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E293B),
              child: Text(
                _lastAction,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFCBD5E1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
