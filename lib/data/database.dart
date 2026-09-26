import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the single sqflite connection for the app and holds schema
/// migrations. Everything else (repositories) goes through this.
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  static const _dbName = 'habits_app.db';
  static const _dbVersion = 12;

  /// The icon each seeded default category starts with — used both by
  /// a fresh install's [_seedDefaultCategories] and to backfill an
  /// icon onto these same five categories for anyone upgrading from
  /// before categories had icons at all (see the `oldVersion < 9`
  /// migration). Literal `Icons.xxx` values, same tree-shaking
  /// reasoning as `categoryIconChoices` in `models/project_category.dart`.
  static const _defaultCategoryIcons = <String, IconData>{
    'Course': Icons.school_outlined,
    'Research': Icons.science_outlined,
    'Side project': Icons.rocket_launch_outlined,
    'Personal': Icons.favorite_outline,
    'Work': Icons.work_outline,
  };

  /// The starting set of session tags — a plain list (unlike project
  /// categories, no icon) seeded on both a fresh install and for
  /// anyone upgrading, from Settings > Session tags. Add, rename, or
  /// delete your own freely afterward.
  static const _defaultSessionTags = <String>[
    'Physics',
    'Majorana',
    'Coding',
    'Studying',
    'Reading',
    'Literature review',
  ];

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  /// The database file's path on disk — used by [BackupService] to
  /// locate the live file for export/restore without duplicating this
  /// path logic.
  Future<String> get databasePath async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  Future<Database> _open() async {
    final path = await databasePath;
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        frequency TEXT NOT NULL DEFAULT 'daily',
        target_per_week INTEGER NOT NULL DEFAULT 7,
        type TEXT NOT NULL DEFAULT 'boolean',
        daily_target INTEGER,
        target_mode TEXT NOT NULL DEFAULT 'atLeast',
        unit TEXT,
        tolerance_per_month INTEGER NOT NULL DEFAULT 0,
        color INTEGER NOT NULL,
        icon_code_point INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        amount INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE,
        UNIQUE (habit_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE project_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        icon_code_point INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        category_id INTEGER,
        status TEXT NOT NULL DEFAULT 'ongoing',
        parent_id INTEGER,
        goal_minutes_per_week INTEGER,
        color INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES project_categories (id) ON DELETE SET NULL,
        FOREIGN KEY (parent_id) REFERENCES projects (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE time_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        title TEXT,
        note TEXT,
        paused_at TEXT,
        paused_seconds INTEGER NOT NULL DEFAULT 0,
        target_minutes INTEGER,
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');

    // A single task can either belong to a project (its checklist) or
    // stand alone as a general to-do (project_id null) — see
    // lib/models/task.dart.
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER,
        name TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        due_date TEXT,
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');

    // Session journal: a user-managed tag vocabulary (e.g. "Physics",
    // "Coding") and a many-to-many join onto time_entries, since a
    // single session can carry more than one tag at once.
    await db.execute('''
      CREATE TABLE session_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE time_entry_tags (
        time_entry_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (time_entry_id, tag_id),
        FOREIGN KEY (time_entry_id) REFERENCES time_entries (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES session_tags (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_habit_logs_habit_id ON habit_logs (habit_id)');
    await db.execute(
        'CREATE INDEX idx_time_entries_project_id ON time_entries (project_id)');
    await db.execute('CREATE INDEX idx_tasks_project_id ON tasks (project_id)');
    await db.execute(
        'CREATE INDEX idx_projects_category_id ON projects (category_id)');
    await db.execute(
        'CREATE INDEX idx_projects_parent_id ON projects (parent_id)');
    await db.execute(
        'CREATE INDEX idx_time_entry_tags_tag_id ON time_entry_tags (tag_id)');

    await _seedDefaultCategories(db);
    await _seedDefaultSessionTags(db);
  }

  /// The starting set of project types — the user can rename, add to,
  /// or delete these freely from Settings; this just saves them typing
  /// the obvious ones on a fresh install.
  Future<void> _seedDefaultCategories(Database db) async {
    var i = 0;
    for (final entry in _defaultCategoryIcons.entries) {
      await db.insert('project_categories', {
        'name': entry.key,
        'sort_order': i,
        'icon_code_point': entry.value.codePoint,
      });
      i++;
    }
  }

  /// The starting set of session tags — see [_defaultSessionTags].
  Future<void> _seedDefaultSessionTags(Database db) async {
    for (var i = 0; i < _defaultSessionTags.length; i++) {
      await db.insert('session_tags',
          {'name': _defaultSessionTags[i], 'sort_order': i});
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Habit types (count/duration, not just boolean done/not-done)
      // and a monthly tolerance ("allow N missed days") on top of the
      // original boolean-only schema.
      await db.execute(
          "ALTER TABLE habits ADD COLUMN type TEXT NOT NULL DEFAULT 'boolean'");
      await db.execute('ALTER TABLE habits ADD COLUMN daily_target INTEGER');
      await db.execute(
          'ALTER TABLE habits ADD COLUMN tolerance_per_month INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE habit_logs ADD COLUMN amount INTEGER');

      // Project categories and an optional weekly time goal.
      await db.execute('ALTER TABLE projects ADD COLUMN category TEXT');
      await db.execute(
          'ALTER TABLE projects ADD COLUMN goal_minutes_per_week INTEGER');
    }

    if (oldVersion < 3) {
      // Manual drag-to-reorder for habits and projects. New rows all
      // land with sort_order 0 from the ALTER's default, so backfill
      // increasing values in the order they were created, preserving
      // the order the user already saw.
      await db.execute(
          'ALTER TABLE habits ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE projects ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');

      final habitRows =
          await db.query('habits', columns: ['id'], orderBy: 'created_at ASC');
      for (var i = 0; i < habitRows.length; i++) {
        await db.update('habits', {'sort_order': i},
            where: 'id = ?', whereArgs: [habitRows[i]['id']]);
      }

      final projectRows = await db
          .query('projects', columns: ['id'], orderBy: 'created_at ASC');
      for (var i = 0; i < projectRows.length; i++) {
        await db.update('projects', {'sort_order': i},
            where: 'id = ?', whereArgs: [projectRows[i]['id']]);
      }
    }

    if (oldVersion < 4) {
      // Pause/resume for the project timer. `paused_seconds` defaults
      // to 0 for every existing row, and `duration` (see TimeEntry)
      // treats that as "never paused" — so past entries' recorded
      // durations are unaffected by this migration.
      await db.execute('ALTER TABLE time_entries ADD COLUMN paused_at TEXT');
      await db.execute(
          'ALTER TABLE time_entries ADD COLUMN paused_seconds INTEGER NOT NULL DEFAULT 0');
    }

    if (oldVersion < 5) {
      // Optional checklist-style sub-tasks within a project.
      await db.execute('''
        CREATE TABLE project_tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          completed INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
          'CREATE INDEX idx_project_tasks_project_id ON project_tasks (project_id)');
    }

    if (oldVersion < 6) {
      // Project types become a user-managed table (add/rename/delete
      // your own) instead of a free-text field; a status independent
      // of archiving (ongoing/on hold/completed); a project can
      // optionally nest under a parent project; and the per-project
      // checklist becomes a general task that can also stand alone
      // with no project (the new "To-dos" tab).
      await db.execute('''
        CREATE TABLE project_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await _seedDefaultCategories(db);

      await db.execute('ALTER TABLE projects ADD COLUMN category_id INTEGER '
          'REFERENCES project_categories (id) ON DELETE SET NULL');
      await db.execute(
          "ALTER TABLE projects ADD COLUMN status TEXT NOT NULL DEFAULT 'ongoing'");
      await db.execute('ALTER TABLE projects ADD COLUMN parent_id INTEGER '
          'REFERENCES projects (id) ON DELETE SET NULL');
      await db.execute(
          'CREATE INDEX idx_projects_category_id ON projects (category_id)');
      await db.execute(
          'CREATE INDEX idx_projects_parent_id ON projects (parent_id)');

      // Fold each existing free-text `category` value into the new
      // table (deduped, case-sensitive exact match) and point each
      // project at its matching row. The old `category` column is left
      // in place afterward, unused — sqflite's bundled SQLite version
      // isn't guaranteed new enough for DROP COLUMN, and an unused
      // nullable column is harmless.
      final distinctCategories = await db.rawQuery(
        "SELECT DISTINCT category FROM projects "
        "WHERE category IS NOT NULL AND TRIM(category) != ''",
      );
      for (final row in distinctCategories) {
        final name = (row['category'] as String).trim();
        final existing = await db.query('project_categories',
            where: 'name = ?', whereArgs: [name], limit: 1);
        final categoryId = existing.isNotEmpty
            ? existing.first['id'] as int
            : await db.insert('project_categories', {
                'name': name,
                'sort_order':
                    Sqflite.firstIntValue(await db.rawQuery(
                            'SELECT COALESCE(MAX(sort_order), -1) + 1 AS n '
                            'FROM project_categories')) ??
                        0,
              });
        await db.update('projects', {'category_id': categoryId},
            where: 'category = ?', whereArgs: [name]);
      }

      // project_tasks -> tasks: same shape, but project_id becomes
      // nullable so a task can stand alone. SQLite can't relax a NOT
      // NULL constraint in place, so recreate the table and copy over.
      await db.execute('''
        CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id INTEGER,
          name TEXT NOT NULL,
          completed INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
          'INSERT INTO tasks (id, project_id, name, completed, sort_order, created_at) '
          'SELECT id, project_id, name, completed, sort_order, created_at FROM project_tasks');
      await db.execute('DROP TABLE project_tasks');
      await db.execute('CREATE INDEX idx_tasks_project_id ON tasks (project_id)');
    }

    if (oldVersion < 7) {
      // A custom unit word for count habits (e.g. "pages" instead of
      // the generic "x"), and an optional due date on a task so the
      // standalone to-do list can order itself and tuck future items
      // behind "Tasks for later".
      await db.execute('ALTER TABLE habits ADD COLUMN unit TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN due_date TEXT');
    }

    if (oldVersion < 8) {
      // A session can now be started with a countdown length (default
      // 25 min) instead of only an open-ended count-up timer — see the
      // single "Start session" flow that replaced per-project timer
      // buttons on the Projects list.
      await db.execute('ALTER TABLE time_entries ADD COLUMN target_minutes INTEGER');
    }

    if (oldVersion < 9) {
      // Each category now carries its own icon, picked from a wide
      // set when creating (or editing) one — and a project's avatar
      // is derived from its category's icon instead of a generic
      // folder or a status-swapped icon (see `ProjectAvatar`).
      //
      // `oldVersion < 6`'s CREATE TABLE already includes this column
      // for anyone jumping straight from an even older version, so
      // only ALTER it in when the table exists but predates it.
      if (oldVersion >= 6) {
        await db.execute(
            'ALTER TABLE project_categories ADD COLUMN icon_code_point INTEGER');
      }
      // Give the five seeded defaults a matching icon even for
      // existing installs, so upgrading users see something better
      // than the generic fallback folder immediately. Any other,
      // user-created category is left with no icon (falls back to
      // the default folder glyph) — there's no way to guess what
      // they'd want.
      for (final entry in _defaultCategoryIcons.entries) {
        await db.update(
          'project_categories',
          {'icon_code_point': entry.value.codePoint},
          where: 'name = ? AND icon_code_point IS NULL',
          whereArgs: [entry.key],
        );
      }
    }

    if (oldVersion < 10) {
      // A session can now carry a short journal note (already had a
      // `note` column, just under-used) plus one or more tags (e.g.
      // "Physics", "Coding") from a user-managed vocabulary, entered
      // when ending a session or logging/editing a past one — see the
      // new "End session" flow that replaced instantly stopping the
      // timer with no confirmation at all.
      await db.execute('''
        CREATE TABLE session_tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE time_entry_tags (
          time_entry_id INTEGER NOT NULL,
          tag_id INTEGER NOT NULL,
          PRIMARY KEY (time_entry_id, tag_id),
          FOREIGN KEY (time_entry_id) REFERENCES time_entries (id) ON DELETE CASCADE,
          FOREIGN KEY (tag_id) REFERENCES session_tags (id) ON DELETE CASCADE
        )
      ''');
      await db.execute(
          'CREATE INDEX idx_time_entry_tags_tag_id ON time_entry_tags (tag_id)');
      await _seedDefaultSessionTags(db);
    }

    if (oldVersion < 11) {
      // A session can now carry a short title of its own — like a
      // post's headline — separate from the longer freeform note, so a
      // session reads at a glance instead of only by its timestamp.
      await db.execute('ALTER TABLE time_entries ADD COLUMN title TEXT');
    }

    if (oldVersion < 12) {
      // A count/duration habit's daily target can now be a ceiling to
      // stay under (e.g. "under 60 min of screen time") instead of
      // only a floor to reach — see Habit.targetMode. Existing habits
      // all default to the original at-least-this-much behavior.
      await db.execute(
          "ALTER TABLE habits ADD COLUMN target_mode TEXT NOT NULL DEFAULT 'atLeast'");
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
