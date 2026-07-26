/// Theme provider with local persistence.
///
/// Supports System, Light, and Dark themes.
/// Persists the user's choice locally using SharedPreferences.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available theme modes.
enum AnythingThemeMode { system, light, dark }

/// Manages the current theme mode with local persistence.
class AnythingThemeNotifier extends ChangeNotifier {
  static const String _prefKey = 'anything_theme_mode';

  AnythingThemeMode _mode = AnythingThemeMode.system;

  AnythingThemeMode get mode => _mode;

  ThemeMode get themeMode {
    switch (_mode) {
      case AnythingThemeMode.system:
        return ThemeMode.system;
      case AnythingThemeMode.light:
        return ThemeMode.light;
      case AnythingThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  /// Load the persisted theme preference.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_prefKey) ?? 0;
    if (index >= 0 && index < AnythingThemeMode.values.length) {
      _mode = AnythingThemeMode.values[index];
      notifyListeners();
    }
  }

  /// Set the theme mode and persist it.
  Future<void> setMode(AnythingThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, mode.index);
  }
}
