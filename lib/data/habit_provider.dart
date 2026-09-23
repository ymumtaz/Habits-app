import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../services/streak_calculator.dart';
import 'habit_repository.dart';

/// Observable app state for habits: loads them from [HabitRepository],
/// keeps a cached streak result per habit, and notifies listeners
/// after every mutation so screens rebuild automatically.
class HabitProvider extends ChangeNotifier {
  HabitProvider({HabitRepository? repository})
      : _repo = repository ?? HabitRepository();

  final HabitRepository _repo;

  List<Habit> _habits = [];
  Map<int, List<HabitLog>> _logsByHabit = {};
  bool _loading = true;

  List<Habit> get habits => List.unmodifiable(_habits);
  bool get isLoading => _loading;

  StreakResult streakFor(Habit habit) {
    if (habit.id == null) return StreakResult.empty;
    final logs = _logsByHabit[habit.id] ?? const [];
    return StreakCalculator.compute(habit, logs);
  }

  bool isCompletedToday(Habit habit) => streakFor(habit).completedToday;

  /// Raw logs for a habit, most recent first — carries the amount for
  /// count/duration habits. Used by the history list and the monthly
  /// calendar.
  List<HabitLog> rawLogsFor(int habitId) =>
      List.unmodifiable(_logsByHabit[habitId] ?? const []);

  /// Days that count as "done" for [habit] — same definition the
  /// streak math uses (a plain log for boolean habits, an amount that
  /// reaches the daily target for count/duration habits). Used to
  /// paint the monthly calendar.
  Set<DateTime> doneDatesFor(Habit habit) => rawLogsFor(habit.id ?? -1)
      .where((log) => StreakCalculator.isLogComplete(habit, log))
      .map((log) => HabitLog.dayOnly(log.date))
      .toSet();

  /// The logged amount for [habit] on [date], or null if nothing was
  /// logged that day. Only meaningful for count/duration habits.
  int? amountOn(Habit habit, DateTime date) {
    final day = HabitLog.dayOnly(date);
    for (final log in rawLogsFor(habit.id ?? -1)) {
      if (HabitLog.dayOnly(log.date) == day) return log.amount;
    }
    return null;
  }

  /// The full log entry for [habit] on [date], or null if nothing was
  /// logged that day — used to capture a log before deleting it, so a
  /// delete can offer an "Undo" that restores the exact same row.
  HabitLog? logOn(Habit habit, DateTime date) {
    final day = HabitLog.dayOnly(date);
    for (final log in rawLogsFor(habit.id ?? -1)) {
      if (HabitLog.dayOnly(log.date) == day) return log;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final results = await Future.wait([
      _repo.fetchHabits(),
      _repo.fetchAllLogs(),
    ]);
    _habits = results[0] as List<Habit>;
    _logsByHabit = results[1] as Map<int, List<HabitLog>>;

    _loading = false;
    notifyListeners();
  }

  Future<void> addHabit(Habit habit) async {
    await _repo.createHabit(habit);
    await load();
  }

  Future<void> updateHabit(Habit habit) async {
    await _repo.updateHabit(habit);
    await load();
  }

  Future<void> archiveHabit(Habit habit) async {
    if (habit.id == null) return;
    await _repo.archiveHabit(habit.id!);
    await load();
  }

  Future<void> deleteHabit(Habit habit) async {
    if (habit.id == null) return;
    await _repo.deleteHabit(habit.id!);
    await load();
  }

  /// Archived habits — not part of the normal cached [habits] list
  /// (which only ever holds active ones), fetched fresh each time the
  /// Archived screen opens.
  Future<List<Habit>> fetchArchivedHabits() => _repo.fetchArchivedHabits();

  /// Restores an archived habit to active. Refreshes the normal
  /// (active-only) [habits] list; the caller is responsible for
  /// refreshing its own archived list afterward.
  Future<void> unarchiveHabit(Habit habit) async {
    if (habit.id == null) return;
    await _repo.archiveHabit(habit.id!, archived: false);
    await load();
  }

  Future<void> _refreshLogsFor(int habitId) async {
    final freshLogs = await _repo.fetchLogs(habitId);
    _logsByHabit[habitId] = freshLogs;
    notifyListeners();
  }

  /// Toggles today's completion for a **boolean** [habit] and refreshes
  /// local state without a full reload, so the UI feels instant.
  Future<void> toggleToday(Habit habit) async {
    if (habit.id == null) return;
    await toggleForDate(habit, DateTime.now());
  }

  /// Toggles completion for a **boolean** [habit] on an arbitrary
  /// [date] — used to log/undo a past day (backfilling, or testing the
  /// streak) rather than just today. [date]'s time-of-day is ignored.
  ///
  /// Only meaningful for [HabitType.boolean] habits — count/duration
  /// habits should use [logAmountForDate] / [removeLogForDate] instead,
  /// since "toggle" doesn't make sense once a day has a quantity.
  Future<void> toggleForDate(Habit habit, DateTime date) async {
    if (habit.id == null) return;
    final day = HabitLog.dayOnly(date);
    final currentlyDone = doneDatesFor(habit).contains(day);

    if (currentlyDone) {
      await _repo.removeCompletion(habit.id!, day);
    } else {
      await _repo.logCompletion(habit.id!, day);
    }
    await _refreshLogsFor(habit.id!);
  }

  /// Sets the logged amount for a count/duration [habit] on [date].
  Future<void> logAmountForDate(Habit habit, DateTime date, int amount) async {
    if (habit.id == null) return;
    await _repo.logAmount(habit.id!, HabitLog.dayOnly(date), amount);
    await _refreshLogsFor(habit.id!);
  }

  /// Clears whatever was logged for [habit] on [date] — works for any
  /// habit type, since "remove the row" is the same operation either
  /// way.
  Future<void> removeLogForDate(Habit habit, DateTime date) async {
    if (habit.id == null) return;
    await _repo.removeCompletion(habit.id!, HabitLog.dayOnly(date));
    await _refreshLogsFor(habit.id!);
  }

  /// Re-inserts a log that was just deleted — pairs with a delete
  /// confirmation's "Undo" snackbar action.
  Future<void> restoreLog(Habit habit, HabitLog log) async {
    if (habit.id == null) return;
    await _repo.restoreLog(log);
    await _refreshLogsFor(habit.id!);
  }

  /// Applies a drag-to-reorder move on the home screen and persists
  /// the new order. Updates local state immediately so the drag feels
  /// instant, rather than waiting on a full reload.
  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final updated = List<Habit>.from(_habits);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    _habits = updated;
    notifyListeners();

    final ids = [for (final h in updated) if (h.id != null) h.id!];
    await _repo.reorderHabits(ids);
  }
}
