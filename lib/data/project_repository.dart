import 'package:sqflite/sqflite.dart';

import '../models/project.dart';
import '../models/project_task.dart';
import '../models/time_entry.dart';
import 'database.dart';

/// All reads/writes for projects and their time entries.
///
/// Only one timer runs at a time app-wide: starting a timer on any
/// project stops whatever else was running first. That matches how
/// people actually track time (you're doing one thing at once) and
/// keeps "total time" unambiguous.
class ProjectRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  // ---- Projects ------------------------------------------------------

  Future<int> createProject(Project project) async {
    final db = await _db;
    final nextOrder = await _nextSortOrder(db, 'projects');
    final map = project.toMap()
      ..remove('id')
      ..['sort_order'] = nextOrder;
    return db.insert('projects', map);
  }

  /// One past the highest existing `sort_order` in [table], so a new
  /// row lands at the end of the user's current order.
  Future<int> _nextSortOrder(Database db, String table) async {
    final rows = await db
        .rawQuery('SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM $table');
    return rows.first['next'] as int;
  }

  /// Persists a new drag-to-reorder order: [orderedIds] is the full
  /// list of project ids in their new display order.
  Future<void> reorderProjects(List<int> orderedIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update('projects', {'sort_order': i},
            where: 'id = ?', whereArgs: [orderedIds[i]]);
      }
    });
  }

  Future<void> updateProject(Project project) async {
    assert(project.id != null, 'Cannot update a project without an id');
    final db = await _db;
    await db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  Future<void> archiveProject(int projectId, {bool archived = true}) async {
    final db = await _db;
    await db.update(
      'projects',
      {'archived': archived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [projectId],
    );
  }

  Future<void> deleteProject(int projectId) async {
    final db = await _db;
    await db.delete('projects', where: 'id = ?', whereArgs: [projectId]);
  }

  Future<List<Project>> fetchProjects({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'projects',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'sort_order ASC',
    );
    return rows.map(Project.fromMap).toList();
  }

  // ---- Time entries ----------------------------------------------------

  Future<List<TimeEntry>> fetchEntries(int projectId) async {
    final db = await _db;
    final rows = await db.query(
      'time_entries',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'started_at DESC',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  /// All time entries for every project at once, grouped by project id.
  Future<Map<int, List<TimeEntry>>> fetchAllEntries() async {
    final db = await _db;
    final rows = await db.query('time_entries', orderBy: 'started_at DESC');
    final grouped = <int, List<TimeEntry>>{};
    for (final row in rows) {
      final entry = TimeEntry.fromMap(row);
      grouped.putIfAbsent(entry.projectId, () => []).add(entry);
    }
    return grouped;
  }

  /// The currently-open entry (running or paused) across all
  /// projects, if any.
  Future<TimeEntry?> fetchActiveEntry() async {
    final db = await _db;
    final rows = await db.query(
      'time_entries',
      where: 'ended_at IS NULL',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : TimeEntry.fromMap(rows.first);
  }

  /// Ends whatever other session (running or paused) is currently
  /// active anywhere, then begins a brand-new running session for
  /// [projectId]. Only one project's session is ever open at a time.
  Future<void> beginSession(int projectId) async {
    final db = await _db;
    final now = DateTime.now();
    await db.transaction((txn) async {
      await txn.update(
        'time_entries',
        {'ended_at': now.toIso8601String()},
        where: 'ended_at IS NULL',
      );
      await txn.insert('time_entries', {
        'project_id': projectId,
        'started_at': now.toIso8601String(),
        'ended_at': null,
        'note': null,
        'paused_at': null,
        'paused_seconds': 0,
      });
    });
  }

  /// Pauses the currently-running entry [entryId] — stops it from
  /// accumulating time until [resumeSession] is called.
  Future<void> pauseSession(int entryId) async {
    final db = await _db;
    await db.update(
      'time_entries',
      {'paused_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND ended_at IS NULL AND paused_at IS NULL',
      whereArgs: [entryId],
    );
  }

  /// Resumes a paused entry [entryId] — folds the just-finished pause
  /// interval into `paused_seconds` and starts ticking again.
  Future<void> resumeSession(int entryId) async {
    final db = await _db;
    final rows = await db.query('time_entries',
        where: 'id = ?', whereArgs: [entryId], limit: 1);
    if (rows.isEmpty) return;
    final entry = TimeEntry.fromMap(rows.first);
    if (entry.pausedAt == null) return;
    final justPaused = DateTime.now().difference(entry.pausedAt!).inSeconds;
    await db.update(
      'time_entries',
      {
        'paused_seconds': entry.pausedSeconds + justPaused,
        'paused_at': null,
      },
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  /// Adds [seconds] to a running entry's `paused_seconds` without
  /// otherwise touching it — used by idle detection to retroactively
  /// exclude time the app spent backgrounded from the recorded
  /// duration, the same mechanism pause/resume already uses.
  Future<void> addPausedSeconds(int entryId, int seconds) async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE time_entries SET paused_seconds = paused_seconds + ? '
      'WHERE id = ? AND ended_at IS NULL',
      [seconds, entryId],
    );
  }

  /// Logs a already-completed session — e.g. "I worked on this for 2h
  /// yesterday" — without using the live timer. [startedAt] + [duration]
  /// determines [TimeEntry.endedAt]; doesn't touch any running timer.
  Future<void> addManualEntry({
    required int projectId,
    required DateTime startedAt,
    required Duration duration,
    String? note,
  }) async {
    final db = await _db;
    await db.insert('time_entries', {
      'project_id': projectId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': startedAt.add(duration).toIso8601String(),
      'note': note,
    });
  }

  /// Updates an existing time entry's start time, end time, and/or
  /// note — used to fix a manually-logged or timer-recorded session
  /// after the fact.
  Future<void> updateEntry(TimeEntry entry) async {
    assert(entry.id != null, 'Cannot update a time entry without an id');
    final db = await _db;
    await db.update(
      'time_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Re-inserts a previously-deleted time entry exactly as it was
  /// (same start/end time and note) — used to power an "Undo" after a
  /// session deletion.
  Future<void> restoreEntry(TimeEntry entry) async {
    final db = await _db;
    await db.insert('time_entries', entry.toMap()..remove('id'));
  }

  /// Ends & records [entryId] — whether it was running or paused, its
  /// final [TimeEntry.duration] is fixed as of now and it stops being
  /// the active session.
  Future<void> endSession(int entryId) async {
    final db = await _db;
    await db.update(
      'time_entries',
      {'ended_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<void> deleteEntry(int entryId) async {
    final db = await _db;
    await db.delete('time_entries', where: 'id = ?', whereArgs: [entryId]);
  }

  // ---- Project tasks (optional checklist) -----------------------------

  Future<List<ProjectTask>> fetchTasks(int projectId) async {
    final db = await _db;
    final rows = await db.query(
      'project_tasks',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(ProjectTask.fromMap).toList();
  }

  /// All tasks for every project at once, grouped by project id — same
  /// one-query-instead-of-N pattern [fetchAllEntries] uses.
  Future<Map<int, List<ProjectTask>>> fetchAllTasks() async {
    final db = await _db;
    final rows = await db.query('project_tasks', orderBy: 'sort_order ASC');
    final grouped = <int, List<ProjectTask>>{};
    for (final row in rows) {
      final task = ProjectTask.fromMap(row);
      grouped.putIfAbsent(task.projectId, () => []).add(task);
    }
    return grouped;
  }

  Future<int> createTask(ProjectTask task) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM project_tasks '
      'WHERE project_id = ?',
      [task.projectId],
    );
    final nextOrder = rows.first['next'] as int;
    final map = task.toMap()
      ..remove('id')
      ..['sort_order'] = nextOrder;
    return db.insert('project_tasks', map);
  }

  Future<void> updateTask(ProjectTask task) async {
    assert(task.id != null, 'Cannot update a task without an id');
    final db = await _db;
    await db.update('project_tasks', task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(int taskId) async {
    final db = await _db;
    await db.delete('project_tasks', where: 'id = ?', whereArgs: [taskId]);
  }
}
