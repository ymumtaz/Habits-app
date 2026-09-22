import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Holds the currently-selected app theme and persists the choice
/// locally so it survives a restart.
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'app_theme_option';

  AppThemeOption _option = AppThemeOption.system;
  bool _loaded = false;

  AppThemeOption get option => _option;
  bool get isLoaded => _loaded;

  ThemeMode get themeMode => AppTheme.modeFor(_option);
  ThemeData get lightTheme => AppTheme.lightThemeFor(_option);
  ThemeData get darkTheme => AppTheme.darkThemeFor(_option);

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) {
        _option = appThemeOptionFromString(saved);
      }
    } catch (_) {
      // Fall back to the default theme if prefs aren't available for
      // some reason (e.g. running in a plain unit test).
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setOption(AppThemeOption option) async {
    if (option == _option) return;
    _option = option;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, appThemeOptionToString(option));
    } catch (_) {
      // Selection still applies for this session even if it can't be
      // persisted.
    }
  }
}
