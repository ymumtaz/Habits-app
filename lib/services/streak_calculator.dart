import '../models/habit.dart';
import '../models/habit_log.dart';
import '../utils/week_config.dart';

/// Streak-length milestones a habit can earn a badge for. Checked
/// against [StreakResult.bestStreak] rather than the current streak,
/// so a badge is permanent once earned — it doesn't disappear if the
/// streak later breaks.
const milestoneThresholds = <int>[7, 30, 100, 365];

/// Result of a streak computation for one habit.
class StreakResult {
  final int currentStreak;
  final int bestStreak;
  final int completionsThisPeriod;
  final bool completedToday;

  const StreakResult({
    required this.currentStreak,
    required this.bestStreak,
    required this.completionsThisPeriod,
    required this.completedToday,
  });

  static const empty = StreakResult(
    currentStreak: 0,
    bestStreak: 0,
    completionsThisPeriod: 0,
    completedToday: false,
  );

  /// A simple streak "score": current streak weighted a bit higher
  /// than the historical best, so consistent recent behavior matters
  /// more than a long-past run. Tune freely later.
  int get score => currentStreak * 10 + bestStreak;

  /// Milestone thresholds reached so far, based on [bestStreak].
  List<int> get milestonesReached =>
      [for (final t in milestoneThresholds) if (bestStreak >= t) t];
}

/// Turns a habit's raw completion logs into streak numbers.
///
/// Daily habits: a streak is a run of consecutive calendar days that
/// are "done" (see below), optionally tolerating a small number of
/// missed days per calendar month (`Habit.tolerancePerMonth`) without
/// breaking the streak. Missing today doesn't break the streak until
/// the day is over (i.e. yesterday still counts as "current" until
/// today ends).
///
/// Weekly habits: a streak is a run of consecutive ISO weeks where the
/// number of *done* days in that week meets `Habit.targetPerWeek`.
/// `Habit.tolerancePerMonth` applies here too, and it's spent in the
/// same unit as the daily case — days, not weeks: if a week falls short
/// of target, its shortfall (target minus what was actually done) is
/// deducted from that calendar month's day budget. A week only breaks
/// the streak once that budget can't cover its shortfall.
///
/// "Done" depends on `Habit.type`:
/// - boolean: a log on that day means done.
/// - count/duration: the day's logged amount must reach
///   `Habit.dailyTarget` (e.g. 8 glasses, 20 minutes).
class StreakCalculator {
  /// [now] is normally left to default to the real current time — it's
  /// overridable so tests can pin "today" to a fixed, month-boundary-safe
  /// date instead of being at the mercy of whatever day the test suite
  /// happens to run on.
  static StreakResult compute(
    Habit habit,
    List<HabitLog> logs, {
    DateTime? now,
  }) {
    if (logs.isEmpty) return StreakResult.empty;
    final effectiveNow = now ?? DateTime.now();

    return habit.frequency == HabitFrequency.daily
        ? _computeDaily(habit, logs, effectiveNow)
        : _computeWeekly(habit, logs, effectiveNow);
  }

  /// Whether a single log entry counts as "done" for [habit] — public
  /// so the UI layer (monthly calendar, history list) can use the same
  /// definition the streak math uses, instead of drifting out of sync.
  static bool isLogComplete(Habit habit, HabitLog log) =>
      _isLogComplete(habit, log);

  static bool _isLogComplete(Habit habit, HabitLog log) {
    switch (habit.type) {
      case HabitType.boolean:
        return true; // the row's mere existence means done
      case HabitType.count:
      case HabitType.duration:
        final target = habit.dailyTarget ?? 1;
        return (log.amount ?? 0) >= target;
    }
  }

  static String _monthKey(DateTime day) => '${day.year}-${day.month}';

  static StreakResult _computeDaily(
    Habit habit,
    List<HabitLog> logs,
    DateTime now,
  ) {
    final doneDays = <DateTime>{};
    for (final log in logs) {
      if (_isLogComplete(habit, log)) {
        doneDays.add(HabitLog.dayOnly(log.date));
      }
    }
    if (doneDays.isEmpty) return StreakResult.empty;

    final tolerance = habit.tolerancePerMonth;
    final today = HabitLog.dayOnly(now);
    final completedToday = doneDays.contains(today);
    // Never walk further back than the habit's own creation date. A
    // sparsely-logged habit with a generous tolerance would otherwise
    // "refill" its tolerance credit every calendar month (the per-month
    // counter resets on each new key) and walk backward indefinitely
    // even with almost nothing logged.
    final habitStart = HabitLog.dayOnly(habit.createdAt);

    // Current streak: walk backwards from today (or yesterday, if
    // today isn't done yet). A missed day doesn't stop the walk as
    // long as that calendar month still has tolerance credits left;
    // it also doesn't add to the streak count, it just doesn't break
    // it — same idea as a "streak freeze".
    final usedBackward = <String, int>{};
    var cursor = completedToday ? today : today.subtract(const Duration(days: 1));
    var current = 0;
    while (!cursor.isBefore(habitStart)) {
      if (doneDays.contains(cursor)) {
        current++;
      } else {
        final key = _monthKey(cursor);
        final used = usedBackward[key] ?? 0;
        if (used >= tolerance) break;
        usedBackward[key] = used + 1;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Best streak: scan forward, day by day, from the earliest done
    // day through today, applying the same tolerance rule as we go.
    final sortedDone = doneDays.toList()..sort();
    final usedForward = <String, int>{};
    var run = 0;
    var best = 0;
    var day = sortedDone.first;
    while (!day.isAfter(today)) {
      if (doneDays.contains(day)) {
        run++;
      } else {
        final key = _monthKey(day);
        final used = usedForward[key] ?? 0;
        if (used < tolerance) {
          usedForward[key] = used + 1;
          // tolerated miss: run continues, doesn't grow, doesn't reset
        } else {
          best = run > best ? run : best;
          run = 0;
        }
      }
      day = day.add(const Duration(days: 1));
    }
    best = run > best ? run : best;

    return StreakResult(
      currentStreak: current,
      bestStreak: best < current ? current : best,
      completionsThisPeriod: doneDays.where((d) => _isThisWeek(d, now)).length,
      completedToday: completedToday,
    );
  }

  static StreakResult _computeWeekly(
    Habit habit,
    List<HabitLog> logs,
    DateTime now,
  ) {
    final target = habit.targetPerWeek.clamp(1, 7);

    final doneDays = <DateTime>{};
    for (final log in logs) {
      if (_isLogComplete(habit, log)) {
        doneDays.add(HabitLog.dayOnly(log.date));
      }
    }
    if (doneDays.isEmpty) return StreakResult.empty;

    // Group done days by the Monday that starts their week.
    final byWeek = <DateTime, int>{};
    for (final day in doneDays) {
      final weekStart = _weekStart(day);
      byWeek[weekStart] = (byWeek[weekStart] ?? 0) + 1;
    }

    final today = HabitLog.dayOnly(now);
    final thisWeekStart = _weekStart(today);
    final completionsThisWeek = byWeek[thisWeekStart] ?? 0;
    final tolerance = habit.tolerancePerMonth;
    // Same reasoning as the daily case: bound the walk by the habit's
    // creation date so a generous tolerance can't send it wandering back
    // indefinitely through weeks with no data.
    final habitWeekStart = _weekStart(HabitLog.dayOnly(habit.createdAt));

    // Current streak: walk backwards week by week from this week (or
    // last week, if this week hasn't hit target yet). A week that falls
    // short of target doesn't stop the walk as long as its shortfall
    // (in days) still fits inside that calendar month's remaining
    // tolerance budget — the same "N missed days per month" allowance
    // daily habits use.
    final usedBackward = <String, int>{};
    var cursor = (completionsThisWeek >= target)
        ? thisWeekStart
        : thisWeekStart.subtract(const Duration(days: 7));
    var current = 0;
    while (!cursor.isBefore(habitWeekStart)) {
      final shortfall = target - (byWeek[cursor] ?? 0);
      if (shortfall <= 0) {
        current++;
      } else {
        final key = _monthKey(cursor);
        final used = usedBackward[key] ?? 0;
        if (used + shortfall > tolerance) break;
        usedBackward[key] = used + shortfall;
      }
      cursor = cursor.subtract(const Duration(days: 7));
    }

    // Best streak: scan forward, week by week, from the earliest
    // recorded week through this week, spending the same day budget as
    // we go (mirrors the daily best-streak scan).
    final weekKeys = byWeek.keys.toList()..sort();
    final usedForward = <String, int>{};
    var run = 0;
    var best = 0;
    var w = weekKeys.first;
    while (!w.isAfter(thisWeekStart)) {
      final shortfall = target - (byWeek[w] ?? 0);
      if (shortfall <= 0) {
        run++;
      } else {
        final key = _monthKey(w);
        final used = usedForward[key] ?? 0;
        if (used + shortfall <= tolerance) {
          usedForward[key] = used + shortfall;
          // tolerated shortfall: run continues, doesn't grow
        } else {
          best = run > best ? run : best;
          run = 0;
        }
      }
      w = w.add(const Duration(days: 7));
    }
    best = run > best ? run : best;

    return StreakResult(
      currentStreak: current,
      bestStreak: best < current ? current : best,
      completionsThisPeriod: completionsThisWeek,
      completedToday: doneDays.contains(today),
    );
  }

  /// The start of [day]'s week, honoring [WeekConfig.firstWeekday]
  /// (Monday by default, Sunday if the user set that in Settings).
  static DateTime _weekStart(DateTime day) {
    final offset = (day.weekday - WeekConfig.firstWeekday) % 7;
    return day.subtract(Duration(days: offset));
  }

  static bool _isThisWeek(DateTime day, DateTime now) =>
      _weekStart(day) == _weekStart(HabitLog.dayOnly(now));
}
