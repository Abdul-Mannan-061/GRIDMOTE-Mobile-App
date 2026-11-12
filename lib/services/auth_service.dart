import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'bluetooth_service.dart';

// Runs outside the UI isolate to keep the form responsive.
Future<String> _derivePasswordHash(List<String> input) async {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  );

  final key = await algorithm.deriveKeyFromPassword(
    password: input[0],
    nonce: base64Decode(input[1]),
  );

  return base64Encode(await key.extractBytes());
}

class OfflineUser {
  const OfflineUser({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _storageKey = 'gridmote_offline_accounts_v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  Map<String, dynamic> _data = {
    'version': 1,
    'users': <dynamic>[],
    'rememberedId': null,
    'attempts': 0,
    'blockedUntil': 0,
  };

  OfflineUser? _user;

  bool ready = false;
  bool busy = false;
  String? startupError;

  OfflineUser? get currentUser => _user;

  List<Map<String, dynamic>> get _accounts {
    return (_data['users'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  bool get hasAccounts => _accounts.length == 2;

  String? get legacyOwnerId {
    final accounts = _accounts;
    return accounts.isEmpty ? null : accounts.first['id'] as String;
  }

  static bool validEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());
  }

  OfflineUser _publicUser(Map<String, dynamic> account) {
    return OfflineUser(
      id: account['id'] as String,
      name: account['name'] as String,
      email: account['email'] as String,
    );
  }

  Future<void> initialize() async {
    if (busy) return;

    busy = true;
    ready = false;
    startupError = null;
    notifyListeners();

    try {
      final raw = await _storage.read(key: _storageKey);

      if (raw != null) {
        final decoded = jsonDecode(raw);

        if (decoded is! Map<String, dynamic> ||
            decoded['version'] != 1 ||
            decoded['users'] is! List ||
            (decoded['users'] as List).length != 2 ||
            decoded['attempts'] is! int ||
            decoded['blockedUntil'] is! int) {
          throw const FormatException('Invalid account data.');
        }

        final ids = <String>{};
        final emails = <String>{};

        for (final item in decoded['users'] as List) {
          if (item is! Map<String, dynamic> ||
              item['id'] is! String ||
              item['name'] is! String ||
              item['email'] is! String ||
              item['salt'] is! String ||
              item['hash'] is! String) {
            throw const FormatException('Invalid account.');
          }

          final id = item['id'] as String;
          final email = item['email'] as String;

          if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id) ||
              !ids.add(id) ||
              !emails.add(email) ||
              base64Decode(item['salt'] as String).length != 16 ||
              base64Decode(item['hash'] as String).length != 32) {
            throw const FormatException('Invalid account.');
          }
        }

        final remembered = decoded['rememberedId'];

        if (remembered != null &&
            (remembered is! String || !ids.contains(remembered))) {
          throw const FormatException('Invalid saved session.');
        }

        _data = decoded;
      }

      _user = null;

      for (final account in _accounts) {
        if (account['id'] == _data['rememberedId']) {
          _user = _publicUser(account);
        }
      }

      ready = true;
    } catch (_) {
      _user = null;
      startupError =
      'Could not read secure account storage. Unlock your phone '
          'and tap Retry. Existing accounts have not been reset.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _commit(Map<String, dynamic> next) async {
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(next),
    );

    _data = next;
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (!ready) {
      throw const AuthException('Account storage is not ready.');
    }

    if (busy) {
      throw const AuthException('Please wait for the current operation.');
    }

    busy = true;
    notifyListeners();

    try {
      await operation();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _createAccount(
      String name,
      String email,
      String password,
      ) async {
    final random = Random.secure();
    final id = List.generate(
      16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    final salt = base64Encode(
      List.generate(16, (_) => random.nextInt(256)),
    );

    final hash = await compute(
      _derivePasswordHash,
      [password, salt],
    );

    return {
      'id': id,
      'name': name,
      'email': email,
      'salt': salt,
      'hash': hash,
    };
  }

  Future<void> setupAccounts({
    required String firstEmail,
    required String firstPassword,
    required String secondEmail,
    required String secondPassword,
  }) {
    return _run(() async {
      if (hasAccounts) {
        throw const AuthException('Accounts have already been set up.');
      }

      final email1 = firstEmail.trim().toLowerCase();
      final email2 = secondEmail.trim().toLowerCase();

      if (!validEmail(email1) || !validEmail(email2)) {
        throw const AuthException('Enter valid email addresses.');
      }

      if (email1 == email2) {
        throw const AuthException('Use a different email for each user.');
      }

      for (final password in [firstPassword, secondPassword]) {
        if (password.length < 8 ||
            password.length > 128 ||
            password.trim().isEmpty) {
          throw const AuthException(
            'Passwords must contain 8 to 128 characters.',
          );
        }
      }

      final first = await _createAccount(
        'Abdul Mannan',
        email1,
        firstPassword,
      );

      final second = await _createAccount(
        'Muneeb',
        email2,
        secondPassword,
      );

      // Both accounts are saved together.
      await _commit({
        'version': 1,
        'users': [first, second],
        'rememberedId': null,
        'attempts': 0,
        'blockedUntil': 0,
      });
    });
  }

  bool _sameHash(String first, String second) {
    final a = base64Decode(first);
    final b = base64Decode(second);

    if (a.length != b.length) return false;

    var difference = 0;

    for (var index = 0; index < a.length; index++) {
      difference |= a[index] ^ b[index];
    }

    return difference == 0;
  }

  Future<void> login({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) {
    return _run(() async {
      if (!hasAccounts) {
        throw const AuthException('Set up both accounts first.');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final blockedUntil = _data['blockedUntil'] as int;

      if (now < blockedUntil) {
        final seconds = ((blockedUntil - now) / 1000).ceil();

        throw AuthException(
          'Too many attempts. Try again in $seconds seconds.',
        );
      }

      if (password.length > 128) {
        throw const AuthException('Password is too long.');
      }

      final entered = identifier.trim().toLowerCase();
      Map<String, dynamic>? match;

      for (final account in _accounts) {
        if ((account['email'] as String).toLowerCase() == entered ||
            (account['name'] as String).toLowerCase() == entered) {
          match = account;
          break;
        }
      }

      // Also perform password hashing for an unknown username.
      final candidate = match ?? _accounts.first;

      final calculated = await compute(
        _derivePasswordHash,
        [password, candidate['salt'] as String],
      );

      final correctHash = _sameHash(
        calculated,
        candidate['hash'] as String,
      );

      if (match == null || !correctHash) {
        final attempts = (_data['attempts'] as int) + 1;
        final lock = attempts >= 5;

        await _commit({
          ..._data,
          'attempts': lock ? 0 : attempts,
          'blockedUntil': lock
              ? DateTime.now().millisecondsSinceEpoch + 30000
              : 0,
        });

        throw AuthException(
          lock
              ? 'Too many attempts. Wait 30 seconds and try again.'
              : 'Incorrect name/email or password.',
        );
      }

      await _commit({
        ..._data,
        'rememberedId': rememberMe ? match['id'] : null,
        'attempts': 0,
        'blockedUntil': 0,
      });

      _user = _publicUser(match);
    });
  }

  Future<void> logout() {
    return _run(() async {
      final bluetooth = BluetoothService.instance;

      if (bluetooth.busy) {
        throw const AuthException(
          'Wait for the Bluetooth operation to finish, then log out.',
        );
      }

      await bluetooth.disconnect();

      if (bluetooth.isConnected) {
        throw const AuthException(
          'Disconnect Bluetooth before logging out.',
        );
      }

      await _commit({
        ..._data,
        'rememberedId': null,
      });

      _user = null;
    });
  }
}
