import 'dart:math' as math;

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

  /// A 0-100 "how consistently is this habit actually being kept"
  /// score — see [StreakCalculator]'s scoring section for the formula.
  /// Unlike [currentStreak]/[bestStreak], this isn't a streak count at
  /// all: it blends how close you are to your target lately with how
  /// long you've sustained that, so it moves smoothly instead of
  /// swinging with every streak break.
  final int consistencyScore;

  const StreakResult({
    required this.currentStreak,
    required this.bestStreak,
    required this.completionsThisPeriod,
    required this.completedToday,
    this.consistencyScore = 0,
  });

  static const empty = StreakResult(
    currentStreak: 0,
    bestStreak: 0,
    completionsThisPeriod: 0,
    completedToday: false,
  );

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

    final base = habit.frequency == HabitFrequency.daily
        ? _computeDaily(habit, logs, effectiveNow)
        : _computeWeekly(habit, logs, effectiveNow);
    final score = habit.frequency == HabitFrequency.daily
        ? _dailyConsistencyScore(habit, logs, effectiveNow)
        : _weeklyConsistencyScore(habit, logs, effectiveNow);
    return StreakResult(
      currentStreak: base.currentStreak,
      bestStreak: base.bestStreak,
      completionsThisPeriod: base.completionsThisPeriod,
      completedToday: base.completedToday,
      consistencyScore: score,
    );
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
        final actual = log.amount ?? 0;
        // An "at most" habit (e.g. screen time) is done by staying at
        // or under its target instead of reaching it.
        return habit.targetMode == TargetMode.atMost
            ? actual <= target
            : actual >= target;
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
    // Never walk further back than the earliest day that's actually
    // logged done. A sparsely-logged habit with a generous tolerance
    // would otherwise "refill" its tolerance credit every calendar
    // month (the per-month counter resets on each new key) and walk
    // backward indefinitely even with almost nothing logged. We used
    // to bound this by the habit's creation date instead, but that
    // wrongly ignored days you'd backfilled from before you added the
    // habit to the app — the actual data is the real boundary.
    final earliestDone = doneDays.reduce((a, b) => a.isBefore(b) ? a : b);

    // Current streak: walk backwards from today (or yesterday, if
    // today isn't done yet). A missed day doesn't stop the walk as
    // long as that calendar month still has tolerance credits left;
    // it also doesn't add to the streak count, it just doesn't break
    // it — same idea as a "streak freeze".
    final usedBackward = <String, int>{};
    var cursor = completedToday ? today : today.subtract(const Duration(days: 1));
    var current = 0;
    while (!cursor.isBefore(earliestDone)) {
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
    // Same reasoning as the daily case: bound the walk by the earliest
    // week that actually has data, not the habit's creation date, so a
    // generous tolerance can't send it wandering back indefinitely
    // through weeks with no data — while still honoring weeks you
    // backfilled from before the habit existed in the app.
    final earliestWeekStart = byWeek.keys.reduce((a, b) => a.isBefore(b) ? a : b);

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
    while (!cursor.isBefore(earliestWeekStart)) {
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

  // ==== Consistency score ==================================================
  //
  // A 0-100 score built from two things, on purpose kept separate from
  // the streak-length math above:
  //
  // - "Base": how close to target you've been *lately* (a trailing
  //   window — 2 weeks for a daily habit, 3 weeks for a weekly one).
  //   This is what lets a brand-new habit already sit at a fair score
  //   within a couple of weeks, rather than waiting on history it
  //   can't have yet. Hitting your target exactly settles at 90;
  //   overshooting nudges it up toward 95; falling short (even within
  //   your tolerance) eases it down smoothly — no cliff at any point.
  // - "Bonus": up to +10 more for having kept that up for a long time
  //   — modeled as a slowly-charging exponential average (~75-day
  //   half-life) that starts at zero for every habit and can only be
  //   earned by racking up real elapsed time at or above target. This
  //   is deliberately the *only* way to close in on 100: it doesn't
  //   move any faster just because you overachieved today, so doing a
  //   habit to the extreme for a few days can't shortcut what only
  //   months of steady consistency actually earns.
  //
  // Both pieces use the same 0-100-ish curve ([_curve]) so "on target"
  // always means the same thing in either one.

  static const _baseWindowDays = 14;
  static const _baseWindowWeeks = 3;
  static const _bonusHalfLifeDays = 75.0;
  static const _bonusMaxLookbackDays = 500;
  static const _bonusMaxPoints = 10.0;

  static DateTime _laterOf(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  /// Maps a single "actual vs. target" ratio to a 0-100-ish value.
  /// Exactly on target (r=1) is 90. Short of target eases down with a
  /// gentle (concave) curve — a small shortfall barely costs anything,
  /// a big one costs more — reaching 0 only at r=0. Beyond target,
  /// it creeps up toward 95 but never quite gets there; the rest of
  /// the way to 100 is [_bonusMaxPoints]'s job, not this curve's.
  static double _curve(double r) {
    if (r <= 0) return 0;
    if (r >= 1) return 90 + 5 * (1 - 1 / r);
    return 90 * math.pow(r, 0.6).toDouble();
  }

  /// A ratio of "how much was actually done" against [habit]'s daily
  /// target for one day's (optional) log — 1.0 means exactly on
  /// target, >1 overachieving, 0 means nothing logged that day at all
  /// (no credit for a day you didn't check in on, same as everywhere
  /// else in this calculator). Capped at 3x so one wild outlier day
  /// can't distort the rolling averages below.
  static double _dailyRatio(Habit habit, HabitLog? log) {
    if (log == null) return 0;
    if (habit.type == HabitType.boolean) return 1;
    final target = habit.dailyTarget ?? 1;
    final actual = log.amount ?? 0;
    if (habit.targetMode == TargetMode.atMost) {
      if (actual <= 0) return 3; // used none of it -- can't do better
      return (target / actual).clamp(0.0, 3.0);
    }
    if (target <= 0) return 1;
    return (actual / target).clamp(0.0, 3.0);
  }

  /// The slow-building [_bonusMaxPoints]-point bonus: an exponential
  /// average of [ratios] (oldest first), each capped at 1 before being
  /// folded in — overachieving a day doesn't earn bonus any faster
  /// than just hitting target does, since this bonus is about *time*
  /// kept up, not magnitude. Starts at 0 regardless of how good the
  /// very first entries were, so it only fills in as real time passes.
  static double _bonusFraction(List<double> ratiosOldestFirst, double halfLifeUnits) {
    if (ratiosOldestFirst.isEmpty) return 0;
    final alpha = 1 - math.pow(0.5, 1 / halfLifeUnits).toDouble();
    var ema = 0.0;
    for (final r in ratiosOldestFirst) {
      final input = r.clamp(0.0, 1.0);
      ema = alpha * input + (1 - alpha) * ema;
    }
    return ema;
  }

  static int _dailyConsistencyScore(
    Habit habit,
    List<HabitLog> logs,
    DateTime now,
  ) {
    final logByDay = <DateTime, HabitLog>{};
    for (final log in logs) {
      logByDay[HabitLog.dayOnly(log.date)] = log;
    }
    final today = HabitLog.dayOnly(now);

    // Always average over the full fixed-length window, even for a
    // brand-new habit — a day with no log (whether that's because it's
    // before the habit was created, before you started backfilling, or
    // you just plain missed it) contributes a ratio of 0 via
    // `_dailyRatio`'s null case. That's what makes a single great day-one
    // entry score low instead of jumping straight to 90: it's one good
    // day averaged against ~13 "empty" ones. We used to clamp this
    // window to the habit's creation date, which shrank the averaging
    // denominator for a young habit and let day one hit 90 immediately —
    // exactly backwards from "climbs to 90 after a couple of weeks".
    final baseStart = today.subtract(const Duration(days: _baseWindowDays - 1));
    var baseSum = 0.0;
    var baseCount = 0;
    for (var d = baseStart; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      baseSum += _dailyRatio(habit, logByDay[d]);
      baseCount++;
    }
    final base = _curve(baseCount == 0 ? 0 : baseSum / baseCount);

    // The bonus only looks as far back as real logged data goes (not
    // the habit's creation date) — so a long run you backfilled from
    // before you added the habit to the app still earns its bonus, the
    // same as if you'd been logging it here the whole time.
    final bonusStart = logByDay.isEmpty
        ? today
        : _laterOf(
            logByDay.keys.reduce((a, b) => a.isBefore(b) ? a : b),
            today.subtract(const Duration(days: _bonusMaxLookbackDays - 1)),
          );
    final ratios = <double>[];
    for (var d = bonusStart; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      ratios.add(_dailyRatio(habit, logByDay[d]));
    }
    final bonus = _bonusMaxPoints * _bonusFraction(ratios, _bonusHalfLifeDays);

    return (base + bonus).clamp(0, 100).round();
  }

  static int _weeklyConsistencyScore(
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
    final byWeek = <DateTime, int>{};
    for (final day in doneDays) {
      final ws = _weekStart(day);
      byWeek[ws] = (byWeek[ws] ?? 0) + 1;
    }
    double weekRatio(DateTime weekStart) =>
        ((byWeek[weekStart] ?? 0) / target).clamp(0.0, 3.0);

    final thisWeekStart = _weekStart(HabitLog.dayOnly(now));

    // Same fix as the daily version: always average the full fixed
    // window of weeks, so a brand-new habit's first on-target week
    // isn't averaged against nothing — it's averaged against the
    // ~2 mostly-empty (ratio 0) weeks before it, the same way a real
    // missed week would be.
    final baseStart =
        thisWeekStart.subtract(Duration(days: 7 * (_baseWindowWeeks - 1)));
    var baseSum = 0.0;
    var baseCount = 0;
    for (var w = baseStart; !w.isAfter(thisWeekStart); w = w.add(const Duration(days: 7))) {
      baseSum += weekRatio(w);
      baseCount++;
    }
    final base = _curve(baseCount == 0 ? 0 : baseSum / baseCount);

    final bonusHalfLifeWeeks = _bonusHalfLifeDays / 7;
    final bonusMaxLookbackWeeks = _bonusMaxLookbackDays ~/ 7;
    // As with the daily bonus, bound by the earliest week with real
    // data rather than the habit's creation date, so backfilled
    // history earns its bonus too.
    final bonusStart = byWeek.isEmpty
        ? thisWeekStart
        : _laterOf(
            byWeek.keys.reduce((a, b) => a.isBefore(b) ? a : b),
            thisWeekStart.subtract(Duration(days: 7 * (bonusMaxLookbackWeeks - 1))),
          );
    final ratios = <double>[];
    for (var w = bonusStart; !w.isAfter(thisWeekStart); w = w.add(const Duration(days: 7))) {
      ratios.add(weekRatio(w));
    }
    final bonus = _bonusMaxPoints * _bonusFraction(ratios, bonusHalfLifeWeeks);

    return (base + bonus).clamp(0, 100).round();
  }
}
