import '../data/habit_provider.dart';

/// The daily recap notification's body, computed from the habits
/// completed so far today.
String dailyRecapText(HabitProvider habits) {
  final list = habits.habits;
  if (list.isEmpty) return 'Open Habits to check in on today.';
  var done = 0;
  for (final h in list) {
    if (habits.isCompletedToday(h)) done++;
  }
  return 'You completed $done/${list.length} habit'
      '${list.length == 1 ? '' : 's'} today.';
}

/// The weekly recap notification's body — a rough completions-over-the-
/// last-7-days summary. Intentionally simple (not weighted by each
/// habit's frequency/target) since this is a nudge, not a report; the
/// in-app Insights tab has the precise numbers.
String weeklyRecapText(HabitProvider habits) {
  final list = habits.habits;
  if (list.isEmpty) return 'Open Habits to check in on your week.';
  final weekAgo = DateTime.now().subtract(const Duration(days: 7));

  var totalDone = 0;
  for (final h in list) {
    totalDone += habits.doneDatesFor(h).where((d) => d.isAfter(weekAgo)).length;
  }
  return 'This past week you logged $totalDone completion'
      '${totalDone == 1 ? '' : 's'} across ${list.length} habit'
      '${list.length == 1 ? '' : 's'}.';
}
