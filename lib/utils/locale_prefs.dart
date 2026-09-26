import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

// Mirrors SettingsProvider's private key. Code that runs outside a
// normal widget tree — a background isolate, or a plain service that
// has no [BuildContext] — can't reach [SettingsProvider] the usual way
// (`context.read`), so it reads the persisted language straight from
// SharedPreferences instead.
const languageCodeKey = 'language_code';

/// The app's currently-selected [AppLocalizations], read from disk.
/// For use anywhere a [BuildContext] isn't available — a background
/// isolate (home-screen widget taps) or a plain singleton service
/// (notifications) — rather than `context.l10n`.
Future<AppLocalizations> currentAppLocalizations() async {
  final prefs = await SharedPreferences.getInstance();
  return AppLocalizations(Locale(prefs.getString(languageCodeKey) ?? 'en'));
}
