import '../data/habit_provider.dart';
import '../models/habit.dart';

/// One habit's completion count for the current calendar month so far
/// — the building block for the cross-habit dashboard.
class HabitMonthlyStat {
  final Habit habit;
  final int doneDays;
  final int totalDays;

  const HabitMonthlyStat({
    required this.habit,
    required this.doneDays,
    required this.totalDays,
  });

  /// Fraction of days-so-far this month the habit was completed on,
  /// 0.0–1.0. Uses the same "done" definition the streak math uses
  /// (a plain log for boolean habits, hitting the daily target for
  /// count/duration habits).
  double get rate => totalDays == 0 ? 0 : doneDays / totalDays;
}

/// Per-habit stats for the current calendar month, one entry per
/// active habit, unsorted.
List<HabitMonthlyStat> habitMonthlyStats(HabitProvider provider) {
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final today = DateTime(now.year, now.month, now.day);
  final daysSoFar = today.difference(monthStart).inDays + 1;

  return [
    for (final habit in provider.habits)
      HabitMonthlyStat(
        habit: habit,
        doneDays: provider
            .doneDatesFor(habit)
            .where((d) => !d.isBefore(monthStart) && !d.isAfter(today))
            .length,
        totalDays: daysSoFar,
      ),
  ];
}

/// Overall completion rate across every habit's days-so-far this
/// month, 0.0–1.0. A simple average weighted by days-so-far (the same
/// for every habit in practice, since they're all measured against
/// the same calendar month).
double overallCompletionRate(List<HabitMonthlyStat> stats) {
  if (stats.isEmpty) return 0;
  final totalDone = stats.fold<int>(0, (sum, s) => sum + s.doneDays);
  final totalPossible = stats.fold<int>(0, (sum, s) => sum + s.totalDays);
  return totalPossible == 0 ? 0 : totalDone / totalPossible;
}

/// One day's overall habit completion, for the last-7-days strip on
/// the Habits home screen.
class HabitDayRate {
  final DateTime day;

  /// Fraction of active habits completed on [day], 0.0–1.0.
  final double rate;

  const HabitDayRate({required this.day, required this.rate});
}

/// Overall completion rate for each of the last 7 days (today
/// inclusive), oldest first — a rolling window, not aligned to the
/// calendar week, so it always reads as "the last week" the way a
/// step-counter or screen-time app's daily strip does.
List<HabitDayRate> habitLast7DaysRates(HabitProvider provider) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final total = provider.habits.length;

  return [
    for (var i = 6; i >= 0; i--)
      HabitDayRate(
        day: today.subtract(Duration(days: i)),
        rate: total == 0
            ? 0
            : provider.habits
                    .where((h) => provider
                        .doneDatesFor(h)
                        .contains(today.subtract(Duration(days: i))))
                    .length /
                total,
      ),
  ];
}

/// One habit's own last-7-days values (today inclusive, oldest
/// first) — for boolean habits, 1.0/0.0 per day; for count/duration
/// habits, the raw amount logged (0 if nothing was logged). Reuses
/// [HabitDayRate] as a plain (day, value) pair rather than a strict
/// 0–1 rate.
List<HabitDayRate> habitLast7DaysValuesFor(HabitProvider provider, Habit habit) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final isBoolean = habit.type == HabitType.boolean;

  return [
    for (var i = 6; i >= 0; i--)
      HabitDayRate(
        day: today.subtract(Duration(days: i)),
        rate: isBoolean
            ? (provider
                    .doneDatesFor(habit)
                    .contains(today.subtract(Duration(days: i)))
                ? 1.0
                : 0.0)
            : (provider.amountOn(habit, today.subtract(Duration(days: i))) ?? 0)
                .toDouble(),
      ),
  ];
}
