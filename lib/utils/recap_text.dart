import '../data/habit_provider.dart';
import '../l10n/app_localizations.dart';

/// The daily recap notification's body, computed from the habits
/// completed so far today.
String dailyRecapText(HabitProvider habits, AppLocalizations t) {
  final list = habits.habits;
  if (list.isEmpty) return t.openHabitsCheckInToday;
  var done = 0;
  for (final h in list) {
    if (habits.isCompletedToday(h)) done++;
  }
  return t.dailyRecapBody(done, list.length);
}

/// The weekly recap notification's body — a rough completions-over-the-
/// last-7-days summary. Intentionally simple (not weighted by each
/// habit's frequency/target) since this is a nudge, not a report; the
/// in-app Insights tab has the precise numbers.
String weeklyRecapText(HabitProvider habits, AppLocalizations t) {
  final list = habits.habits;
  if (list.isEmpty) return t.openHabitsCheckInWeek;
  final weekAgo = DateTime.now().subtract(const Duration(days: 7));

  var totalDone = 0;
  for (final h in list) {
    totalDone += habits.doneDatesFor(h).where((d) => d.isAfter(weekAgo)).length;
  }
  return t.weeklyRecapBody(totalDone, list.length);
}
