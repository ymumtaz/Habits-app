import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/habit_repository.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import 'streak_calculator.dart';

const _progressWidgetName = 'HabitProgressWidgetProvider';
const _gridWidgetName = 'HabitMonthlyGridWidgetProvider';
const _gridHabitIndexKey = 'home_widget_grid_habit_index';

/// Refreshes both home-screen widgets straight from the database.
/// Always reads fresh (rather than being handed cached provider
/// state) so it works identically whether it's called from the
/// running app or from the background isolate that handles a widget
/// tap. Best-effort: callers should wrap this in a try/catch, since a
/// widget-plugin hiccup should never take down the app itself.
Future<void> refreshHomeWidgets() async {
  final repo = HabitRepository();
  final habits = await repo.fetchHabits();
  await _refreshProgressWidget(repo, habits);
  await _refreshGridWidget(repo, habits);
}

Future<void> _refreshProgressWidget(
  HabitRepository repo,
  List<Habit> habits,
) async {
  final today = HabitLog.dayOnly(DateTime.now());
  var doneCount = 0;
  final firstThreeDone = <bool>[];

  for (var i = 0; i < habits.length; i++) {
    final habit = habits[i];
    if (habit.id == null) continue;
    final logs = await repo.fetchLogs(habit.id!);
    final todaysLog =
        logs.where((l) => HabitLog.dayOnly(l.date) == today).toList();
    final done = todaysLog.isNotEmpty &&
        StreakCalculator.isLogComplete(habit, todaysLog.first);
    if (done) doneCount++;
    if (i < 3) firstThreeDone.add(done);
  }

  await HomeWidget.saveWidgetData<String>(
    'progress_text',
    habits.isEmpty
        ? 'Add a habit to get started'
        : '$doneCount/${habits.length} done today',
  );
  for (var i = 0; i < 3; i++) {
    if (i < habits.length) {
      final habit = habits[i];
      await HomeWidget.saveWidgetData<String>('habit_${i}_name', habit.name);
      await HomeWidget.saveWidgetData<bool>('habit_${i}_done', firstThreeDone[i]);
      await HomeWidget.saveWidgetData<int>('habit_${i}_id', habit.id ?? -1);
    } else {
      await HomeWidget.saveWidgetData<String>('habit_${i}_name', '');
    }
  }
  await HomeWidget.updateWidget(androidName: _progressWidgetName);
}

Future<void> _refreshGridWidget(
  HabitRepository repo,
  List<Habit> habits,
) async {
  if (habits.isEmpty) {
    await HomeWidget.saveWidgetData<String>('grid_habit_name', 'Add a habit');
    for (var i = 0; i < 42; i++) {
      await HomeWidget.saveWidgetData<int>('cell_${i}_argb', 0);
    }
    await HomeWidget.updateWidget(androidName: _gridWidgetName);
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  var index = prefs.getInt(_gridHabitIndexKey) ?? 0;
  index = ((index % habits.length) + habits.length) % habits.length;
  final habit = habits[index];
  if (habit.id == null) return;

  final logs = await repo.fetchLogs(habit.id!);
  final doneDates = <DateTime>{
    for (final l in logs)
      if (StreakCalculator.isLogComplete(habit, l)) HabitLog.dayOnly(l.date),
  };

  final now = DateTime.now();
  final firstOfMonth = DateTime(now.year, now.month, 1);
  final gridStart = firstOfMonth
      .subtract(Duration(days: (firstOfMonth.weekday - DateTime.monday) % 7));

  await HomeWidget.saveWidgetData<String>('grid_habit_name', habit.name);
  for (var i = 0; i < 42; i++) {
    final day = gridStart.add(Duration(days: i));
    int argb;
    if (day.month != now.month) {
      argb = 0; // outside this month -> blank cell
    } else if (doneDates.contains(DateTime(day.year, day.month, day.day))) {
      argb = habit.color.toARGB32();
    } else {
      argb = 0xFFEFEFEF; // this month, not done
    }
    await HomeWidget.saveWidgetData<int>('cell_${i}_argb', argb);
  }
  await HomeWidget.updateWidget(androidName: _gridWidgetName);
}

/// Entry point for widget taps that need to run Dart code in the
/// background: toggling a habit from the progress widget, or moving
/// the grid widget's "currently shown habit" index. Runs in a
/// separate, minimal Flutter engine — no access to the running app's
/// provider state, so it works straight off the database, same as
/// [refreshHomeWidgets].
///
/// Registered once at startup via [registerHomeWidgetCallback], and
/// needs `@pragma('vm:entry-point')` so release builds don't tree-shake
/// it away (it's never called directly from Dart, only reflectively by
/// the native side).
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  final repo = HabitRepository();

  if (uri.host == 'toggleHabit') {
    final id = int.tryParse(uri.queryParameters['id'] ?? '');
    if (id != null) {
      final habits = await repo.fetchHabits();
      Habit? habit;
      for (final h in habits) {
        if (h.id == id) {
          habit = h;
          break;
        }
      }
      // Only boolean habits can be toggled blind, with no extra input.
      // Count/duration habits need an amount the widget can't collect,
      // so tapping those rows is a harmless no-op here — the row still
      // shows the habit and its current state, just isn't tappable.
      if (habit != null && habit.type == HabitType.boolean) {
        final today = HabitLog.dayOnly(DateTime.now());
        final isDone = await repo.isCompletedOn(id, today);
        if (isDone) {
          await repo.removeCompletion(id, today);
        } else {
          await repo.logCompletion(id, today);
        }
      }
    }
  } else if (uri.host == 'switchGridHabit') {
    final habits = await repo.fetchHabits();
    if (habits.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      var index = prefs.getInt(_gridHabitIndexKey) ?? 0;
      index += uri.queryParameters['direction'] == 'prev' ? -1 : 1;
      index = ((index % habits.length) + habits.length) % habits.length;
      await prefs.setInt(_gridHabitIndexKey, index);
    }
  }

  try {
    await refreshHomeWidgets();
  } catch (_) {}
}

/// Registers [homeWidgetBackgroundCallback] as the background entry
/// point for widget taps — call once at app startup, before `runApp`.
Future<void> registerHomeWidgetCallback() async {
  await HomeWidget.registerBackgroundCallback(homeWidgetBackgroundCallback);
}
