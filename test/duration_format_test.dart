import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits_app/l10n/app_localizations.dart';
import 'package:habits_app/utils/duration_format.dart';

void main() {
  // English — [formatDuration]/[formatDurationCoarse] take the active
  // locale's [AppLocalizations] since Turkish localization, for the
  // "h"/"m"/"s" unit abbreviations.
  final t = AppLocalizations(const Locale('en'));

  group('formatDuration', () {
    test('under a minute shows just seconds', () {
      expect(formatDuration(const Duration(seconds: 40), t), '40s');
    });

    test('minutes and seconds, no hours shown', () {
      expect(
          formatDuration(const Duration(minutes: 45, seconds: 9), t), '45m 9s');
    });

    test('hours, minutes and seconds', () {
      expect(
        formatDuration(const Duration(hours: 2, minutes: 14, seconds: 5), t),
        '2h 14m 5s',
      );
    });

    test('exact hour shows 0m 0s', () {
      expect(formatDuration(const Duration(hours: 3), t), '3h 0m 0s');
    });
  });

  group('formatDurationCoarse', () {
    test('under an hour shows just minutes', () {
      expect(
          formatDurationCoarse(const Duration(minutes: 45, seconds: 40), t),
          '45m');
    });

    test('hours and minutes, seconds dropped', () {
      expect(
        formatDurationCoarse(
            const Duration(hours: 2, minutes: 14, seconds: 59), t),
        '2h 14m',
      );
    });

    test('zero duration shows 0m', () {
      expect(formatDurationCoarse(Duration.zero, t), '0m');
    });
  });

  group('formatDurationClock', () {
    test('under an hour omits the hours field', () {
      expect(formatDurationClock(const Duration(minutes: 3, seconds: 45)),
          '03:45');
    });

    test('an hour or more includes the hours field', () {
      expect(
        formatDurationClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
    });
  });
}
