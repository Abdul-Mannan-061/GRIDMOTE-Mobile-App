import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  ThemeMode themeMode = ThemeMode.dark;
  bool saving = false;
  String? error;

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();

    return File('${directory.path}/gridmote_settings.json');
  }

  Future<void> load() async {
    try {
      final file = await _file();

      if (!await file.exists()) return;

      final data = jsonDecode(await file.readAsString());

      themeMode = ThemeMode.values.firstWhere(
            (mode) => mode.name == data['themeMode'],
        orElse: () => ThemeMode.dark,
      );
    } catch (_) {
      themeMode = ThemeMode.dark;
      error = 'Could not load preferences. Using the dark theme.';
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (saving) return;

    final previous = themeMode;

    saving = true;
    error = null;
    themeMode = mode;
    notifyListeners();

    try {
      final file = await _file();

      await file.writeAsString(
        jsonEncode({
          'themeMode': mode.name,
        }),
        flush: true,
      );
    } catch (_) {
      themeMode = previous;
      error = 'Could not save the theme. Please try again.';
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
