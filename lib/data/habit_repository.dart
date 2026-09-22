import 'package:sqflite/sqflite.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import 'database.dart';

/// All reads/writes for habits and their completion logs.
///
/// Kept as plain async CRUD over sqflite — [HabitProvider] is the layer
/// that turns this into observable state for the UI.
class HabitRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  // ---- Habits ------------------------------------------------------

  Future<int> createHabit(Habit habit) async {
    final db = await _db;
    final nextOrder = await _nextSortOrder(db, 'habits');
    final map = habit.toMap()
      ..remove('id')
      ..['sort_order'] = nextOrder;
    return db.insert('habits', map);
  }

  /// One past the highest existing `sort_order` in [table], so a new
  /// row lands at the end of the user's current order.
  Future<int> _nextSortOrder(Database db, String table) async {
    final rows =
        await db.rawQuery('SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM $table');
    return rows.first['next'] as int;
  }

  /// Persists a new drag-to-reorder order: [orderedIds] is the full
  /// list of habit ids in their new display order.
  Future<void> reorderHabits(List<int> orderedIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update('habits', {'sort_order': i},
            where: 'id = ?', whereArgs: [orderedIds[i]]);
      }
    });
  }

  Future<void> updateHabit(Habit habit) async {
    assert(habit.id != null, 'Cannot update a habit without an id');
    final db = await _db;
    await db.update(
      'habits',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<void> archiveHabit(int habitId, {bool archived = true}) async {
    final db = await _db;
    await db.update(
      'habits',
      {'archived': archived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<void> deleteHabit(int habitId) async {
    final db = await _db;
    await db.delete('habits', where: 'id = ?', whereArgs: [habitId]);
  }

  Future<List<Habit>> fetchHabits({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'habits',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'sort_order ASC',
    );
    return rows.map(Habit.fromMap).toList();
  }

  // ---- Logs ----------------------------------------------------------

  /// Marks [habit] as done on [date]. Idempotent: logging the same day
  /// twice is a no-op thanks to the UNIQUE(habit_id, date) constraint.
  Future<void> logCompletion(int habitId, DateTime date) async {
    final db = await _db;
    final log = HabitLog(
      habitId: habitId,
      date: date,
      createdAt: DateTime.now(),
    );
    await db.insert(
      'habit_logs',
      log.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Sets the logged amount for a count/duration habit on [date] —
  /// upserts, since a day can only have one amount (the UNIQUE
  /// constraint on habit_id+date). Passing 0 still leaves a row rather
  /// than deleting it, so a "logged 0 today" is distinguishable from
  /// "never logged" if that's ever useful; callers that want to clear
  /// a day entirely should use [removeCompletion] instead.
  Future<void> logAmount(int habitId, DateTime date, int amount) async {
    final db = await _db;
    final log = HabitLog(
      habitId: habitId,
      date: date,
      amount: amount,
      createdAt: DateTime.now(),
    );
    await db.insert(
      'habit_logs',
      log.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Re-inserts a previously-deleted log exactly as it was (same day,
  /// amount, and original `createdAt`) — used to power an "Undo" after
  /// a log deletion.
  Future<void> restoreLog(HabitLog log) async {
    final db = await _db;
    await db.insert(
      'habit_logs',
      log.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Undoes a completion for [habit] on [date].
  Future<void> removeCompletion(int habitId, DateTime date) async {
    final db = await _db;
    await db.delete(
      'habit_logs',
      where: 'habit_id = ? AND date = ?',
      whereArgs: [habitId, HabitLog.dayOnly(date).toIso8601String()],
    );
  }

  Future<bool> isCompletedOn(int habitId, DateTime date) async {
    final db = await _db;
    final rows = await db.query(
      'habit_logs',
      where: 'habit_id = ? AND date = ?',
      whereArgs: [habitId, HabitLog.dayOnly(date).toIso8601String()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// All logs for a habit, most recent first. Used for streak
  /// calculation and the habit detail history view.
  Future<List<HabitLog>> fetchLogs(int habitId) async {
    final db = await _db;
    final rows = await db.query(
      'habit_logs',
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'date DESC',
    );
    return rows.map(HabitLog.fromMap).toList();
  }

  /// Logs for every habit at once, grouped by habit id. One query
  /// instead of N so the home screen doesn't hit the DB per habit.
  Future<Map<int, List<HabitLog>>> fetchAllLogs() async {
    final db = await _db;
    final rows = await db.query('habit_logs', orderBy: 'date DESC');
    final grouped = <int, List<HabitLog>>{};
    for (final row in rows) {
      final log = HabitLog.fromMap(row);
      grouped.putIfAbsent(log.habitId, () => []).add(log);
    }
    return grouped;
  }
}
