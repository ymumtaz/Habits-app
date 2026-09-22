import 'package:flutter/material.dart';

/// The set of selectable app themes. [system] follows the OS light/dark
/// setting using the default teal palette; the rest are fixed looks the
/// user can pick regardless of OS setting.
enum AppThemeOption { system, light, dark, navyTeal, pink, green }

extension AppThemeOptionLabel on AppThemeOption {
  String get label => switch (this) {
        AppThemeOption.system => 'System default',
        AppThemeOption.light => 'Light',
        AppThemeOption.dark => 'Dark',
        AppThemeOption.navyTeal => 'Navy & Teal',
        AppThemeOption.pink => 'Light Pink',
        AppThemeOption.green => 'Green',
      };

  /// A representative color for showing a little swatch next to the
  /// option in the picker.
  Color get swatch => switch (this) {
        AppThemeOption.system => Colors.teal,
        AppThemeOption.light => Colors.teal,
        AppThemeOption.dark => Colors.teal.shade700,
        AppThemeOption.navyTeal => const Color(0xFF00ACA0),
        AppThemeOption.pink => Colors.pink.shade300,
        AppThemeOption.green => Colors.green,
      };
}

String appThemeOptionToString(AppThemeOption option) => option.name;

AppThemeOption appThemeOptionFromString(String? value) {
  return AppThemeOption.values.firstWhere(
    (o) => o.name == value,
    orElse: () => AppThemeOption.system,
  );
}

/// Builds the actual [ThemeData] for each selectable theme, plus which
/// [ThemeMode] the app should run in once that theme is picked.
class AppTheme {
  static ThemeMode modeFor(AppThemeOption option) {
    switch (option) {
      case AppThemeOption.system:
        return ThemeMode.system;
      case AppThemeOption.light:
      case AppThemeOption.pink:
      case AppThemeOption.green:
        return ThemeMode.light;
      case AppThemeOption.dark:
      case AppThemeOption.navyTeal:
        return ThemeMode.dark;
    }
  }

  /// The [ThemeData] to use for the "light" slot of [MaterialApp] when
  /// [option] is active — only actually shown when [modeFor] resolves
  /// to a light appearance (directly, or via [ThemeMode.system]).
  static ThemeData lightThemeFor(AppThemeOption option) {
    switch (option) {
      case AppThemeOption.pink:
        return _fromSeed(Colors.pink.shade300, Brightness.light);
      case AppThemeOption.green:
        return _fromSeed(Colors.green, Brightness.light);
      case AppThemeOption.system:
      case AppThemeOption.light:
      case AppThemeOption.dark:
      case AppThemeOption.navyTeal:
        return _fromSeed(Colors.teal, Brightness.light);
    }
  }

  /// The [ThemeData] to use for the "dark" slot — only actually shown
  /// when [modeFor] resolves to a dark appearance.
  static ThemeData darkThemeFor(AppThemeOption option) {
    switch (option) {
      case AppThemeOption.navyTeal:
        return _navyTeal();
      case AppThemeOption.system:
      case AppThemeOption.light:
      case AppThemeOption.dark:
      case AppThemeOption.pink:
      case AppThemeOption.green:
        return _fromSeed(Colors.teal, Brightness.dark);
    }
  }

  static ThemeData _fromSeed(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return _themeFrom(scheme);
  }

  /// A dark theme built from the two brand colors requested: a deep
  /// navy (#1e2f48) for surfaces/backgrounds and a teal (#00aca0) as
  /// the accent/primary color.
  static ThemeData _navyTeal() {
    const navy = Color(0xFF1E2F48);
    const teal = Color(0xFF00ACA0);
    final base = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.dark,
    );
    final scheme = base.copyWith(
      primary: teal,
      onPrimary: navy,
      secondary: teal,
      surface: navy,
      surfaceContainerHigh: const Color(0xFF28405F),
      surfaceContainerHighest: const Color(0xFF2F4A6D),
      onSurface: Colors.white,
    );
    return _themeFrom(scheme);
  }

  static ThemeData _themeFrom(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    );
  }

  // Kept for anything still referencing the old plain API.
  static ThemeData light() => lightThemeFor(AppThemeOption.light);
  static ThemeData dark() => darkThemeFor(AppThemeOption.dark);
}
