import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService extends ChangeNotifier {
  BluetoothService._();

  static final BluetoothService instance = BluetoothService._();

  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _subscription;

  BluetoothDevice? device;
  bool busy = false;
  String status = 'Not connected';
  int receivedBytes = 0;

  bool get isConnected => _connection?.isConnected ?? false;

  bool connectedTo(String address) {
    return isConnected && device?.address == address;
  }

  Future<void> prepare() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw Exception('Please use an Android phone.');
    }

    // This first connection test targets your Android 12+ phone.
    final permissions = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    final allowed =
        permissions[Permission.bluetoothConnect]?.isGranted == true &&
            permissions[Permission.bluetoothScan]?.isGranted == true;

    if (!allowed) {
      throw Exception(
        'Allow Nearby devices permission in the app settings, '
            'then try again.',
      );
    }

    if (await _bluetooth.isAvailable != true) {
      throw Exception('Bluetooth is not available on this device.');
    }

    if (await _bluetooth.isEnabled != true) {
      await _bluetooth.requestEnable();

      if (await _bluetooth.isEnabled != true) {
        throw Exception('Turn on Bluetooth, then try again.');
      }
    }
  }

  Future<List<BluetoothDevice>> pairedDevices() async {
    await prepare();

    final devices = await _bluetooth.getBondedDevices();

    devices.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

    return devices;
  }

  Future<void> connect(BluetoothDevice selectedDevice) async {
    if (busy || controlChanging || connectedTo(selectedDevice.address)) return;

    if (isConnected) {
      throw Exception('Disconnect the current device first.');
    }

    busy = true;
    status = 'Connecting...';
    notifyListeners();

    try {
      await prepare();
      await _bluetooth.cancelDiscovery();

      bool expired = false;

      final pendingConnection =
      BluetoothConnection.toAddress(selectedDevice.address)
          .then((connection) {
        // Close a connection that completes after the timeout.
        if (expired) {
          connection.dispose();
        }
        return connection;
      });

      late final BluetoothConnection connection;

      try {
        connection = await pendingConnection.timeout(
          const Duration(seconds: 20),
        );
      } on TimeoutException {
        expired = true;
        throw Exception(
          'Connection timed out. Check module power and try again.',
        );
      }

      _connection = connection;
      device = selectedDevice;
      receivedBytes = 0;
      _rx.clear();
      controlStatus = 'Preview mode';

      _subscription = connection.input.listen(
            (data) {
          if (!identical(_connection, connection)) return;
          receivedBytes += data.length;
          _receive(data);
          notifyListeners();
        },
        onDone: () {
          _connectionEnded(connection, 'Device disconnected');
        },
        onError: (Object error) {
          _connectionEnded(connection, 'Connection lost: $error');
        },
        cancelOnError: true,
      );

      status = 'Connected';
    } catch (error) {
      status = error.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _connectionEnded(BluetoothConnection connection, String message) {
    if (!identical(_connection, connection)) return;

    _clearProtocol();
    _connection = null;
    device = null;
    _subscription = null;
    status = message;
    if (controlStatus.startsWith('LIVE')) {
      controlStatus = 'Live control stopped: $message';
    }

    connection.dispose();
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (busy) return;

    busy = true;
    notifyListeners();

    await stopControl();
    _clearProtocol();
    final connection = _connection;
    final subscription = _subscription;

    _connection = null;
    _subscription = null;
    device = null;

    try {
      await subscription?.cancel();
      connection?.dispose();
      status = 'Disconnected';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // GRIDMOTE v2: one request at a time, waiting for the Arduino reply.
  bool controlReady = false;
  bool controlChanging = false;
  String controlStatus = 'Preview mode';
  final Map<int, List<int>> _states = {};
  final Map<int, String> _inputTypes = {};
  final Map<int, List<int>> _desired = {};
  final Set<int> _dirty = {};
  final Map<int, int> _lastSent = {};
  final Stopwatch _clock = Stopwatch()..start();
  int _widgetCount = 0;
  int _session = 0;
  Future<void>? _runner;
  Future<void>? _starting;
  Future<void>? _stopping;
  Completer<Uint8List>? _reply;
  int _replyType = 0;
  final List<int> _rx = [];
  int _lastRx = 0;

  int? outputValue(int id, [int component = 0]) {
    if (!controlReady) return null;
    return _states[id]?[component];
  }

  static const _types = {
    'button': 1,
    'label': 2,
    'toggle': 3,
    'slider': 4,
    'joystick': 5,
    'led': 6,
    'gauge': 7,
    'knob': 8,
    'stepper': 9,
    'rgb': 10,
    'bar': 11,
    'digit': 12,
    'accel': 13,
    'buzzer': 14,
  };

  Uint8List _descriptor(
      double width,
      double height,
      List<Map<String, dynamic>> widgets,
      ) {
    final bytes = <int>[0x47, 0x4d, 2, widgets.length];
    void word(num n) {
      final v = n.toInt();
      bytes.addAll([v & 255, (v >> 8) & 255]);
    }

    if (widgets.length > 32) throw const FormatException('Too many widgets.');
    word(width);
    word(height);
    for (var i = 0; i < widgets.length; i++) {
      final w = widgets[i];
      final type = _types[w['type']];
      final label = utf8.encode(w['label'] as String);
      if (w['id'] != i || type == null || label.length > 96) {
        throw const FormatException('Invalid GRIDMOTE layout.');
      }
      bytes.addAll([i, type]);
      for (final key in ['x', 'y', 'w', 'h']) {
        word(w[key] as num);
      }
      bytes.add(label.length);
      bytes.addAll(label);
    }
    return Uint8List.fromList(bytes);
  }

  void _receive(Uint8List data) {
    final now = _clock.elapsedMilliseconds;
    if (now - _lastRx > 1000) _rx.clear();
    _lastRx = now;
    _rx.addAll(data);
    while (_rx.length >= 2) {
      if (_rx[0] != 0xa5 || _rx[1] != 0x5a) {
        _rx.removeAt(0);
        continue;
      }
      if (_rx.length < 5) break;
      final length = _rx[3] | (_rx[4] << 8);
      if (length > 3500 || (_rx[2] != 0x81 && _rx[2] != 0x82)) {
        _rx.removeAt(0);
        continue;
      }
      if (_rx.length < length + 6) break;
      var sum = 0;
      for (var i = 2; i < length + 5; i++) {
        sum ^= _rx[i];
      }
      if (sum != _rx[length + 5]) {
        _rx.removeAt(0);
        continue;
      }
      final type = _rx[2];
      final payload = Uint8List.fromList(_rx.sublist(5, length + 5));
      _rx.removeRange(0, length + 6);
      final pending = _reply;
      if (pending != null && !pending.isCompleted && type == _replyType) {
        pending.complete(payload);
      }
    }
  }

  Future<Uint8List> _exchange(int type, List<int> payload) async {
    final connection = _connection;
    if (connection == null || !connection.isConnected) {
      throw StateError('Bluetooth disconnected.');
    }
    if (_reply != null) throw StateError('Another request is pending.');
    final frame = <int>[
      0xa5,
      0x5a,
      type,
      payload.length & 255,
      (payload.length >> 8) & 255,
      ...payload,
    ];
    var sum = 0;
    for (var i = 2; i < frame.length; i++) {
      sum ^= frame[i];
    }
    frame.add(sum);
    final pending = Completer<Uint8List>();
    _reply = pending;
    _replyType = type == 1 ? 0x81 : 0x82;
    try {
      connection.output.add(Uint8List.fromList(frame));
      // Listen for both write errors and the response immediately.
      final results = await Future.wait<Uint8List>([
        pending.future,
        connection.output.allSent.then((_) => Uint8List(0)),
      ]).timeout(const Duration(seconds: 3));
      return results.first;
    } finally {
      if (identical(_reply, pending)) _reply = null;
    }
  }

  void _readState(Uint8List payload) {
    if (payload.length != _widgetCount * 7) {
      throw const FormatException('Arduino state size does not match layout.');
    }
    final next = <int, List<int>>{};
    final data = ByteData.sublistView(payload);
    for (var p = 0; p < payload.length; p += 7) {
      final id = payload[p];
      if (id >= _widgetCount || next.containsKey(id)) {
        throw const FormatException('Invalid Arduino widget ID.');
      }
      next[id] = List.generate(
        3,
            (j) => data.getInt16(p + 1 + j * 2, Endian.little),
      );
    }
    _states
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  Future<void> _writeInput(int id, List<int> values) async {
    final data = ByteData(7)..setUint8(0, id);
    for (var j = 0; j < 3; j++) {
      data.setInt16(1 + j * 2, values[j], Endian.little);
    }
    _readState(await _exchange(2, data.buffer.asUint8List()));
  }

  // Called by the screen; rapid joystick updates replace older unsent values.
  void setInput(int id, int x, [int y = 0, int z = 0]) {
    if (!controlReady || !_inputTypes.containsKey(id)) return;
    if (_inputTypes[id] == 'button') {
      x = x == 1 ? 1 : 0;
      y = 0;
      z = 0;
    } else {
      x = x.clamp(-100, 100).toInt();
      y = y.clamp(-100, 100).toInt();
      z = 0;
    }
    _desired[id] = [x, y, z];
    _dirty.add(id);
  }

  Future<void> startControl({
    required double width,
    required double height,
    required List<Map<String, dynamic>> widgets,
  }) async {
    if (controlChanging || controlReady || busy) return;
    controlChanging = true;
    final session = ++_session;
    controlStatus = 'Checking Arduino layout...';
    notifyListeners();
    final operation = _beginControl(session, width, height, widgets);
    _starting = operation;
    try {
      await operation;
    } finally {
      _starting = null;
      if (_stopping == null) controlChanging = false;
      notifyListeners();
    }
  }

  Future<void> _beginControl(
      int session,
      double width,
      double height,
      List<Map<String, dynamic>> widgets,
      ) async {
    try {
      final expected = _descriptor(width, height, widgets);
      final actual = await _exchange(1, []);
      if (session != _session) return;
      if (!listEquals(expected, actual)) {
        controlStatus =
        'Layout mismatch. Import the JSON matching the Arduino sketch.';
        return;
      }
      _widgetCount = widgets.length;
      _inputTypes.clear();
      _desired.clear();
      _dirty.clear();
      _lastSent.clear();
      for (final w in widgets) {
        if (w['type'] == 'button' || w['type'] == 'joystick') {
          final id = w['id'] as int;
          _inputTypes[id] = w['type'] as String;
          _desired[id] = [0, 0, 0];
          await _writeInput(id, [0, 0, 0]);
          if (session != _session) return;
        }
      }
      _readState(await _exchange(3, []));
      if (session != _session) return;
      controlReady = true;
      controlStatus = 'LIVE • Arduino layout verified';
      _runner = _runControl(session);
    } catch (error) {
      _protocolFailure(error);
    }
  }

  Future<void> _runControl(int session) async {
    var lastPoll = _clock.elapsedMilliseconds;
    try {
      while (controlReady && session == _session && isConnected) {
        final now = _clock.elapsedMilliseconds;
        int? sendId;
        // Button release takes priority over movement and heartbeats.
        for (final id in _dirty) {
          if (_inputTypes[id] == 'button' && _desired[id]![0] == 0) {
            sendId = id;
            break;
          }
        }
        // Held buttons are refreshed for the firmware's 1500 ms timeout.
        sendId ??= _inputTypes.keys.cast<int?>().firstWhere(
              (id) =>
          _inputTypes[id] == 'button' &&
              _desired[id]![0] == 1 &&
              now - (_lastSent[id] ?? 0) >= 400,
          orElse: () => null,
        );
        if (sendId == null && _dirty.isNotEmpty) sendId = _dirty.first;
        if (sendId != null) {
          final values = List<int>.from(_desired[sendId]!);
          _dirty.remove(sendId);
          await _writeInput(sendId, values);
          _lastSent[sendId] = _clock.elapsedMilliseconds;
          lastPoll = _clock.elapsedMilliseconds;
        } else if (now - lastPoll >= 300) {
          _readState(await _exchange(3, []));
          lastPoll = _clock.elapsedMilliseconds;
        }
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    } catch (error) {
      _protocolFailure(error);
    }
  }

  Future<void> stopControl() {
    final previous = _stopping;
    if (previous != null) return previous;
    ++_session;
    controlReady = false;
    controlChanging = true;
    // Start on a microtask so _stopping is assigned before completion.
    final future = Future<void>.microtask(_stopControl);
    _stopping = future;
    return future;
  }

  Future<void> _stopControl() async {
    try {
      await _starting;
      await _runner;
      if (isConnected) {
        for (final id in _inputTypes.keys.toList()) {
          await _writeInput(id, [0, 0, 0]);
        }
      }
      controlStatus = 'Preview mode • Live control stopped';
    } catch (error) {
      _protocolFailure(error);
    } finally {
      _inputTypes.clear();
      _desired.clear();
      _dirty.clear();
      _states.clear();
      _runner = null;
      _stopping = null;
      controlChanging = false;
      notifyListeners();
    }
  }

  void _protocolFailure(Object error) {
    controlStatus = error is TimeoutException
        ? 'No Arduino reply. Check uploaded sketch, RX/TX wiring and 9600 baud; reconnect.'
        : 'Live control stopped: $error';
    // A timeout has no request ID in v2: reconnect to avoid accepting a late reply.
    final connection = _connection;
    if (connection != null)
      _connectionEnded(connection, 'Disconnected: protocol error');
    else
      notifyListeners();
  }

  void _clearProtocol() {
    ++_session;
    controlReady = false;
    _states.clear();
    _rx.clear();
    _dirty.clear();
    _inputTypes.clear();
    _desired.clear();
    _lastSent.clear();
    final pending = _reply;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(StateError('Bluetooth disconnected.'));
    }
  }
}
