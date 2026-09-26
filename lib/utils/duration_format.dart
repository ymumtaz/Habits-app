import '../l10n/app_localizations.dart';

/// Formats a [Duration] as a short human string, including seconds:
/// "2h 14m 5s", "45m 12s", or "12s" for anything under a minute. Used
/// anywhere we show total or elapsed project time.
String formatDuration(Duration d, AppLocalizations t) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  final h = t.hourAbbrev;
  final m = t.minuteAbbrevShort;
  final s = t.secondAbbrev;
  if (hours > 0) return '$hours$h $minutes$m $seconds$s';
  if (minutes > 0) return '$minutes$m $seconds$s';
  return '$seconds$s';
}

/// Formats a [Duration] to the nearest minute, no seconds — for totals
/// where second-level precision is just noise: "2h 14m", "45m", "0m".
String formatDurationCoarse(Duration d, AppLocalizations t) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final h = t.hourAbbrev;
  final m = t.minuteAbbrevShort;
  if (hours > 0) return '$hours$h $minutes$m';
  return '$minutes$m';
}

/// Formats with seconds for a live-ticking clock display, e.g.
/// "12:03:45" or "03:45" when under an hour. Purely numeric — no
/// translation needed.
String formatDurationClock(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
  return '$mm:$ss';
}
