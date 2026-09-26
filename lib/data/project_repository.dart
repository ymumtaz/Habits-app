import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/project.dart';
import '../models/project_category.dart';
import '../models/session_tag.dart';
import '../models/task.dart';
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

  /// Only the archived projects — powers the "Archived" screen, which
  /// unlike the normal project list needs to see exactly the ones
  /// [fetchProjects] leaves out.
  Future<List<Project>> fetchArchivedProjects() async {
    final db = await _db;
    final rows = await db.query(
      'projects',
      where: 'archived = 1',
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
  Future<void> beginSession(int projectId, {int? targetMinutes}) async {
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
        'target_minutes': targetMinutes,
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
    String? title,
    String? note,
    List<int> tagIds = const [],
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final id = await txn.insert('time_entries', {
        'project_id': projectId,
        'started_at': startedAt.toIso8601String(),
        'ended_at': startedAt.add(duration).toIso8601String(),
        'title': title,
        'note': note,
      });
      await _setEntryTags(txn, id, tagIds);
    });
  }

  /// Updates an existing time entry's start time, end time, and/or
  /// note — used to fix a manually-logged or timer-recorded session
  /// after the fact. Pass [tagIds] to also replace its tags; omit it
  /// to leave the entry's current tags untouched.
  Future<void> updateEntry(TimeEntry entry, {List<int>? tagIds}) async {
    assert(entry.id != null, 'Cannot update a time entry without an id');
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'time_entries',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      if (tagIds != null) {
        await _setEntryTags(txn, entry.id!, tagIds);
      }
    });
  }

  /// Re-inserts a previously-deleted time entry exactly as it was
  /// (same start/end time and note), with [tagIds] restored alongside
  /// it — used to power an "Undo" after a session deletion.
  Future<void> restoreEntry(TimeEntry entry, {List<int> tagIds = const []}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final id = await txn.insert('time_entries', entry.toMap()..remove('id'));
      await _setEntryTags(txn, id, tagIds);
    });
  }

  /// Ends & records [entryId] — whether it was running or paused, its
  /// final duration is fixed and it stops being the active session.
  ///
  /// By default the final duration is just "however long it's been
  /// since it started" (minus any time already spent paused), same as
  /// before. Pass [duration] to override that with an edited value
  /// instead — e.g. the session was accidentally left running and the
  /// real working time was much shorter — by folding the difference
  /// into `paused_seconds` rather than rewriting `started_at`, so the
  /// entry's true start time is preserved. [note] and [tagIds] are
  /// always applied (pass nothing/empty to leave them blank).
  Future<void> endSession(
    int entryId, {
    Duration? duration,
    String? title,
    String? note,
    List<int> tagIds = const [],
  }) async {
    final db = await _db;
    final now = DateTime.now();
    await db.transaction((txn) async {
      final updates = <String, Object?>{
        'ended_at': now.toIso8601String(),
        'title': title,
        'note': note,
        'paused_at': null,
      };
      if (duration != null) {
        final rows = await txn.query('time_entries',
            columns: ['started_at'], where: 'id = ?', whereArgs: [entryId], limit: 1);
        if (rows.isNotEmpty) {
          final startedAt = DateTime.parse(rows.first['started_at'] as String);
          final elapsedSeconds = now.difference(startedAt).inSeconds;
          updates['paused_seconds'] =
              (elapsedSeconds - duration.inSeconds).clamp(0, elapsedSeconds);
        }
      }
      await txn.update('time_entries', updates, where: 'id = ?', whereArgs: [entryId]);
      await _setEntryTags(txn, entryId, tagIds);
    });
  }

  Future<void> deleteEntry(int entryId) async {
    final db = await _db;
    await db.delete('time_entries', where: 'id = ?', whereArgs: [entryId]);
  }

  /// Every tag currently on every session, grouped by time entry id —
  /// the same one-query-instead-of-N pattern [fetchAllEntries] uses.
  Future<Map<int, List<int>>> fetchAllEntryTags() async {
    final db = await _db;
    final rows = await db.query('time_entry_tags');
    final grouped = <int, List<int>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent(row['time_entry_id'] as int, () => [])
          .add(row['tag_id'] as int);
    }
    return grouped;
  }

  /// Replaces every tag on [entryId] with exactly [tagIds].
  Future<void> _setEntryTags(
    DatabaseExecutor txn,
    int entryId,
    List<int> tagIds,
  ) async {
    await txn.delete('time_entry_tags',
        where: 'time_entry_id = ?', whereArgs: [entryId]);
    for (final tagId in tagIds) {
      await txn.insert('time_entry_tags', {'time_entry_id': entryId, 'tag_id': tagId});
    }
  }

  // ---- Session tags (user-managed session journal labels) -------------

  Future<List<SessionTag>> fetchTags() async {
    final db = await _db;
    final rows = await db.query('session_tags', orderBy: 'sort_order ASC');
    return rows.map(SessionTag.fromMap).toList();
  }

  Future<int> createTag(String name) async {
    final db = await _db;
    final nextOrder = await _nextSortOrder(db, 'session_tags');
    return db.insert('session_tags', {'name': name, 'sort_order': nextOrder});
  }

  Future<void> renameTag(int id, String name) async {
    final db = await _db;
    await db.update('session_tags', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes a tag outright. Any session tagged with it just loses
  /// that tag (the `time_entry_tags` join row is removed by the FK's
  /// `ON DELETE CASCADE`) — nothing else about those sessions changes.
  Future<void> deleteTag(int id) async {
    final db = await _db;
    await db.delete('session_tags', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Project categories (user-managed types) --------------------------

  Future<List<ProjectCategory>> fetchCategories() async {
    final db = await _db;
    final rows = await db.query('project_categories', orderBy: 'sort_order ASC');
    return rows.map(ProjectCategory.fromMap).toList();
  }

  Future<int> createCategory(String name, IconData icon) async {
    final db = await _db;
    final nextOrder = await _nextSortOrder(db, 'project_categories');
    return db.insert('project_categories', {
      'name': name,
      'sort_order': nextOrder,
      'icon_code_point': icon.codePoint,
    });
  }

  Future<void> updateCategory(int id,
      {required String name, required IconData icon}) async {
    final db = await _db;
    await db.update(
      'project_categories',
      {'name': name, 'icon_code_point': icon.codePoint},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a category outright. Any project tagged with it just
  /// loses the tag (`category_id` is set null by the FK's
  /// `ON DELETE SET NULL`) — nothing else about those projects changes.
  Future<void> deleteCategory(int id) async {
    final db = await _db;
    await db.delete('project_categories', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Tasks (project checklist item, or a standalone to-do) ----------

  Future<List<Task>> fetchTasks(int projectId) async {
    final db = await _db;
    final rows = await db.query(
      'tasks',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  /// All project-scoped tasks at once, grouped by project id — same
  /// one-query-instead-of-N pattern [fetchAllEntries] uses. Standalone
  /// tasks (no project) are fetched separately via
  /// [fetchStandaloneTasks].
  Future<Map<int, List<Task>>> fetchAllProjectTasks() async {
    final db = await _db;
    final rows = await db.query(
      'tasks',
      where: 'project_id IS NOT NULL',
      orderBy: 'sort_order ASC',
    );
    final grouped = <int, List<Task>>{};
    for (final row in rows) {
      final task = Task.fromMap(row);
      grouped.putIfAbsent(task.projectId!, () => []).add(task);
    }
    return grouped;
  }

  /// The general "To-dos" list — tasks with no project.
  Future<List<Task>> fetchStandaloneTasks() async {
    final db = await _db;
    final rows = await db.query(
      'tasks',
      where: 'project_id IS NULL',
      orderBy: 'sort_order ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<int> createTask(Task task) async {
    final db = await _db;
    final nextOrder = await _nextTaskSortOrder(db, task.projectId);
    final map = task.toMap()
      ..remove('id')
      ..['sort_order'] = nextOrder;
    return db.insert('tasks', map);
  }

  Future<int> _nextTaskSortOrder(Database db, int? projectId) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM tasks '
      'WHERE project_id ${projectId == null ? 'IS NULL' : '= ?'}',
      projectId == null ? [] : [projectId],
    );
    return rows.first['next'] as int;
  }

  Future<void> updateTask(Task task) async {
    assert(task.id != null, 'Cannot update a task without an id');
    final db = await _db;
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(int taskId) async {
    final db = await _db;
    await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  }
}
