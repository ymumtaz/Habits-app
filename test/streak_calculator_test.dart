// Unit tests for the streak math — the part of this app most worth
// covering with tests, since it's pure logic (no UI, no real database)
// and easy to get subtly wrong (off-by-one on "today", week boundaries).
//
// Run with:  flutter test
// Run just this file:  flutter test test/streak_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:habits_app/models/habit.dart';
import 'package:habits_app/models/habit_log.dart';
import 'package:habits_app/services/streak_calculator.dart';
import 'package:habits_app/utils/week_config.dart';

/// A fixed, month-boundary-safe "today" for tests that care about
/// monthly tolerance credits — mid-month, so a handful of days in
/// either direction never crosses into a different calendar month.
final _fixedNow = DateTime(2024, 6, 15);

/// Builds a habit for tests without needing to touch the database.
Habit _habit({
  HabitFrequency frequency = HabitFrequency.daily,
  int targetPerWeek = 7,
  HabitType type = HabitType.boolean,
  int? dailyTarget,
  TargetMode targetMode = TargetMode.atLeast,
  int tolerancePerMonth = 0,
  DateTime? createdAt,
}) {
  return Habit(
    id: 1,
    name: 'Test habit',
    frequency: frequency,
    targetPerWeek: targetPerWeek,
    type: type,
    dailyTarget: dailyTarget,
    targetMode: targetMode,
    tolerancePerMonth: tolerancePerMonth,
    createdAt: createdAt ?? DateTime(2024, 1, 1),
  );
}

/// A completion log [daysBefore] days before the fixed test "today".
HabitLog _fixedLog(int daysBefore, {int? amount}) {
  final date = _fixedNow.subtract(Duration(days: daysBefore));
  return HabitLog(habitId: 1, date: date, amount: amount, createdAt: date);
}

/// A completion log [daysAgo] days before today.
HabitLog _logDaysAgo(int daysAgo) {
  final date = DateTime.now().subtract(Duration(days: daysAgo));
  return HabitLog(habitId: 1, date: date, createdAt: date);
}

/// A completion log [offset] days after the Monday that starts the
/// *current* calendar week — guarantees the log lands in this week no
/// matter what day of the week the test happens to run on.
HabitLog _logInCurrentWeek(int offset) {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - DateTime.monday));
  final date = monday.add(Duration(days: offset));
  return HabitLog(habitId: 1, date: date, createdAt: date);
}

void main() {
  group('daily habits', () {
    test('no logs at all -> everything is zero', () {
      final result = StreakCalculator.compute(_habit(), []);
      expect(result.currentStreak, 0);
      expect(result.bestStreak, 0);
      expect(result.completedToday, false);
    });

    test('completed only today -> streak of 1', () {
      final result = StreakCalculator.compute(_habit(), [_logDaysAgo(0)]);
      expect(result.currentStreak, 1);
      expect(result.completedToday, true);
    });

    test('5 consecutive days ending today -> streak of 5', () {
      final logs = [for (var i = 0; i < 5; i++) _logDaysAgo(i)];
      final result = StreakCalculator.compute(_habit(), logs);
      expect(result.currentStreak, 5);
    });

    test('done yesterday but not yet today -> streak still counts '
        'through yesterday', () {
      final logs = [for (var i = 1; i <= 4; i++) _logDaysAgo(i)];
      final result = StreakCalculator.compute(_habit(), logs);
      expect(result.currentStreak, 4);
      expect(result.completedToday, false);
    });

    test('a gap breaks the current streak', () {
      // Done today and yesterday, then a 2-day gap, then an older run.
      final logs = [
        _logDaysAgo(0),
        _logDaysAgo(1),
        _logDaysAgo(4),
        _logDaysAgo(5),
        _logDaysAgo(6),
      ];
      final result = StreakCalculator.compute(_habit(), logs);
      expect(result.currentStreak, 2); // today + yesterday only
      expect(result.bestStreak, 3); // the older 3-day run
    });

    test('missed two or more days ago -> current streak is 0', () {
      final logs = [_logDaysAgo(3), _logDaysAgo(4)];
      final result = StreakCalculator.compute(_habit(), logs);
      expect(result.currentStreak, 0);
      expect(result.bestStreak, 2);
    });

    test('duplicate logs on the same day do not inflate the streak', () {
      final day = DateTime.now();
      final logs = [
        HabitLog(habitId: 1, date: day, createdAt: day),
        HabitLog(habitId: 1, date: day, createdAt: day),
      ];
      final result = StreakCalculator.compute(_habit(), logs);
      expect(result.currentStreak, 1);
    });

    test('backfilling several past days counts them all toward the '
        'streak, even if they predate when the habit was added to the '
        'app', () {
      // The habit was only just added today, but its history was
      // backfilled for the past several days via the calendar -- the
      // streak should reflect the actual logged days, not stop short
      // just because they're "before" the habit's createdAt.
      final habit = _habit(createdAt: DateTime.now());
      final logs = [for (var i = 0; i < 6; i++) _logDaysAgo(i)];
      final result = StreakCalculator.compute(habit, logs);
      expect(result.currentStreak, 6);
    });
  });

  group('weekly habits (X times per week)', () {
    test('hitting the target this week keeps the streak alive', () {
      final habit = _habit(
        frequency: HabitFrequency.weekly,
        targetPerWeek: 3,
      );
      // 3 completions inside *this calendar week* (Mon–Sun). Anchored to
      // this week's Monday rather than "N days ago", since "N days ago"
      // can cross into last week depending on what day the test runs on
      // (e.g. 2 days before a Tuesday is a Sunday in the prior week).
      final logs = [_logInCurrentWeek(0), _logInCurrentWeek(1), _logInCurrentWeek(2)];
      final result = StreakCalculator.compute(habit, logs);
      expect(result.completionsThisPeriod, 3);
      expect(result.currentStreak, greaterThanOrEqualTo(1));
    });

    test('under target this week does not count this week toward '
        'the streak', () {
      final habit = _habit(
        frequency: HabitFrequency.weekly,
        targetPerWeek: 3,
      );
      // Only 1 completion this week (today), but the *previous*
      // calendar week hit target with 3. Anchored to fixed weeks
      // (like the monthly-tolerance tests below) rather than "N days
      // ago": a fixed offset in days can land in either the current or
      // previous week depending on what day the suite happens to run
      // on, which made this test flaky.
      final now = DateTime.now();
      final thisMonday = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - DateTime.monday));
      final lastMonday = thisMonday.subtract(const Duration(days: 7));
      final logs = [
        HabitLog(habitId: 1, date: now, createdAt: now),
        for (var i = 0; i < 3; i++)
          HabitLog(
            habitId: 1,
            date: lastMonday.add(Duration(days: i)),
            createdAt: lastMonday,
          ),
      ];
      final result = StreakCalculator.compute(habit, logs, now: now);
      expect(result.completionsThisPeriod, 1);
      // This week hasn't hit target, so it isn't part of the current
      // streak — best streak still reflects last week's run.
      expect(result.bestStreak, greaterThanOrEqualTo(1));
    });
  });

  group('first day of the week (WeekConfig)', () {
    // WeekConfig is a global static (see its doc comment for why), so
    // every test here must reset it afterward or it'd leak into every
    // other test in this file.
    tearDown(() => WeekConfig.firstWeekday = DateTime.monday);

    test('a Sunday-start week counts a Sunday completion as part of '
        'the *new* week, not the tail of the old one', () {
      WeekConfig.firstWeekday = DateTime.sunday;
      final habit = _habit(frequency: HabitFrequency.weekly, targetPerWeek: 1);
      // _fixedNow (2024-06-15) is a Saturday. With Sunday as the first
      // day, that Saturday is the *last* day of the week that started
      // Sunday 2024-06-09 -- so a completion on 2024-06-09 (Sunday)
      // should land in the *same* week as one on 2024-06-15 (Saturday).
      final sunday = DateTime(2024, 6, 9);
      final logs = [
        HabitLog(habitId: 1, date: sunday, createdAt: sunday),
        HabitLog(habitId: 1, date: _fixedNow, createdAt: _fixedNow),
      ];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      // Both logs count toward the same (Sunday-anchored) week, so
      // target 1 is met and it's the current week's streak.
      expect(result.completionsThisPeriod, 2);
      expect(result.currentStreak, 1);
    });

    test('the default (Monday-start) week splits the same two dates '
        'into different weeks', () {
      // Same two dates as above, but with the default Monday start:
      // 2024-06-09 (Sunday) is the *last* day of the Monday-anchored
      // week before _fixedNow's week, not the same week.
      final habit = _habit(frequency: HabitFrequency.weekly, targetPerWeek: 1);
      final sunday = DateTime(2024, 6, 9);
      final logs = [
        HabitLog(habitId: 1, date: sunday, createdAt: sunday),
        HabitLog(habitId: 1, date: _fixedNow, createdAt: _fixedNow),
      ];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      expect(result.completionsThisPeriod, 1);
    });
  });

  group('weekly habits with monthly tolerance ("streak freeze")', () {
    // Weeks are Mon–Sun; _fixedNow (2024-06-15) is a Saturday, so its
    // week starts Monday 2024-06-10. Helper builds a log for a given
    // number of *weeks* before that current week, on the Monday of
    // that week — enough to hit any target up to 7 via [count].
    List<HabitLog> _weekOf(int weeksBefore, int count) {
      final monday =
          DateTime(2024, 6, 10).subtract(Duration(days: weeksBefore * 7));
      return [
        for (var i = 0; i < count; i++)
          HabitLog(
            habitId: 1,
            date: monday.add(Duration(days: i)),
            createdAt: monday,
          ),
      ];
    }

    // Tolerance is spent in *days*, not weeks: an under-target week's
    // shortfall (target minus what was actually done) is deducted from
    // that calendar month's day budget. Weeks 0 and 1 (Mondays
    // 2024-06-10 and 2024-06-03) fall in June; week 2 (2024-05-27)
    // falls in May, so it draws from a separate month's budget.
    test('a shortfall that fits the remaining monthly day budget keeps '
        'the streak going, though only weeks that fully hit target add '
        'to the count', () {
      final habit = _habit(
        frequency: HabitFrequency.weekly,
        targetPerWeek: 3,
        tolerancePerMonth: 2,
      );
      // Week 0 hits target (3). Week 1 falls 2 short (only 1 done) —
      // exactly June's 2-day budget, so it's tolerated. Week 2 hits
      // target again, drawing on May's separate budget.
      final logs = [
        ..._weekOf(0, 3),
        ..._weekOf(1, 1),
        ..._weekOf(2, 3),
      ];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      // Week 1's shortfall doesn't break the walk, but only weeks 0 and
      // 2 (fully met) add to the current streak count.
      expect(result.currentStreak, 2);
    });

    test('a shortfall bigger than the remaining monthly day budget '
        'breaks the streak at that point', () {
      final habit = _habit(
        frequency: HabitFrequency.weekly,
        targetPerWeek: 3,
        tolerancePerMonth: 1,
      );
      // Week 1 falls 2 days short, but June's budget is only 1 -> the
      // walk stops there, so only week 0 counts.
      final logs = [
        ..._weekOf(0, 3),
        ..._weekOf(1, 1),
        ..._weekOf(2, 3),
      ];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      expect(result.currentStreak, 1);
    });

    test('with no tolerance set, any shortfall breaks the streak as '
        'before', () {
      final habit = _habit(
        frequency: HabitFrequency.weekly,
        targetPerWeek: 3,
      );
      final logs = [
        ..._weekOf(0, 3),
        ..._weekOf(1, 2), // just 1 day short
        ..._weekOf(2, 3),
      ];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      expect(result.currentStreak, 1);
    });
  });

  group('daily habits with monthly tolerance ("streak freeze")', () {
    test('one tolerated miss this month keeps the streak continuous', () {
      final habit = _habit(tolerancePerMonth: 1);
      // Done every day from 10 days ago through today, except a single
      // gap on day 5 — one missed day, covered by the monthly tolerance.
      final logs = [
        for (var i = 0; i <= 10; i++)
          if (i != 5) _fixedLog(i),
      ];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      // 11 calendar days, 1 tolerated miss -> 10 actually-done days,
      // and the streak isn't broken by the gap.
      expect(result.currentStreak, 10);
      expect(result.completedToday, true);
    });

    test('a second miss in the same month breaks the streak at that '
        'point', () {
      final habit = _habit(tolerancePerMonth: 1);
      // Missed both day 2 and day 5 — only one tolerance credit per
      // month, so the walk stops at the second miss.
      final logs = [
        for (var i = 0; i <= 6; i++)
          if (i != 2 && i != 5) _fixedLog(i),
      ];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      // Walking back from today: day0, day1 done: day2 tolerated miss;
      // day3, day4 done; day5 is the second miss this month -> stop.
      expect(result.currentStreak, 4);
    });

    test('with no tolerance set, a single miss breaks the streak as '
        'before', () {
      final habit = _habit(tolerancePerMonth: 0);
      final logs = [
        for (var i = 0; i <= 6; i++)
          if (i != 3) _fixedLog(i),
      ];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      // day0, 1, 2 done, then day3 missing with zero tolerance -> stop.
      expect(result.currentStreak, 3);
    });
  });

  group('count/duration habits (target-based completion)', () {
    test('a day only counts as done once its amount reaches the daily '
        'target', () {
      final habit = _habit(type: HabitType.count, dailyTarget: 8);
      final logs = [
        _fixedLog(0, amount: 8), // meets target -> done
        _fixedLog(1, amount: 8), // meets target -> done
        _fixedLog(2, amount: 3), // under target -> not done
      ];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      expect(result.completedToday, true);
      // The under-target day two days ago isn't "done", so it stops
      // the backward walk right after yesterday.
      expect(result.currentStreak, 2);
    });

    test('exceeding the daily target still just counts as done', () {
      final habit = _habit(type: HabitType.duration, dailyTarget: 20);
      final logs = [
        _fixedLog(0, amount: 45),
        _fixedLog(1, amount: 20),
      ];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      expect(result.currentStreak, 2);
    });

    test('a boolean-type log with no amount is unaffected by target '
        'logic', () {
      final habit = _habit(type: HabitType.boolean);
      final result =
          StreakCalculator.compute(habit, [_fixedLog(0)], now: _fixedNow);
      expect(result.completedToday, true);
      expect(result.currentStreak, 1);
    });
  });

  group('consistency score', () {
    test('no logs -> score is 0', () {
      final result = StreakCalculator.compute(_habit(), []);
      expect(result.consistencyScore, 0);
    });

    test('hit daily for the last two weeks settles around 90', () {
      final habit = _habit(createdAt: _fixedNow.subtract(const Duration(days: 40)));
      final logs = [for (var i = 0; i < 14; i++) _fixedLog(i)];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      expect(result.consistencyScore, inInclusiveRange(85, 95));
    });

    test('a long, consistent history scores higher than a fresh one '
        'with the same recent behavior', () {
      final freshHabit =
          _habit(createdAt: _fixedNow.subtract(const Duration(days: 13)));
      final oldHabit =
          _habit(createdAt: _fixedNow.subtract(const Duration(days: 300)));
      final recentLogs = [for (var i = 0; i < 14; i++) _fixedLog(i)];
      final longLogs = [for (var i = 0; i < 300; i++) _fixedLog(i)];

      final fresh = StreakCalculator.compute(freshHabit, recentLogs, now: _fixedNow);
      final established = StreakCalculator.compute(oldHabit, longLogs, now: _fixedNow);
      expect(established.consistencyScore, greaterThan(fresh.consistencyScore));
    });

    test('falling off after a long good run decays gradually, not to '
        'zero immediately', () {
      final habit = _habit(createdAt: _fixedNow.subtract(const Duration(days: 300)));
      // Done every day for the last 300 days, then missed just today.
      final logs = [for (var i = 1; i <= 300; i++) _fixedLog(i)];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      expect(result.consistencyScore, greaterThan(60));
    });

    test('a single good day-one entry does not jump straight to 90', () {
      // This is the exact behavior that was wrong before: a fresh habit
      // logged once, today, should score low -- it climbs to 90 only
      // after a couple of weeks of real consistency, not on day one.
      final habit = _habit(createdAt: _fixedNow);
      final result =
          StreakCalculator.compute(habit, [_fixedLog(0)], now: _fixedNow);
      expect(result.consistencyScore, lessThan(30));
    });

    test('an "at most" habit scores well when kept under its limit', () {
      final habit = _habit(
        type: HabitType.duration,
        dailyTarget: 60,
        targetMode: TargetMode.atMost,
        createdAt: _fixedNow.subtract(const Duration(days: 20)),
      );
      final logs = [
        for (var i = 0; i < 14; i++) _fixedLog(i, amount: 45),
      ];
      final result = StreakCalculator.compute(habit, logs, now: _fixedNow);
      expect(result.consistencyScore, greaterThan(85));
    });
  });
}
