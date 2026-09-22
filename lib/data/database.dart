import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the single sqflite connection for the app and holds schema
/// migrations. Everything else (repositories) goes through this.
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  static const _dbName = 'habits_app.db';
  static const _dbVersion = 5;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
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
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT,
        goal_minutes_per_week INTEGER,
        color INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE time_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        note TEXT,
        paused_at TEXT,
        paused_seconds INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');

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
        'CREATE INDEX idx_habit_logs_habit_id ON habit_logs (habit_id)');
    await db.execute(
        'CREATE INDEX idx_time_entries_project_id ON time_entries (project_id)');
    await db.execute(
        'CREATE INDEX idx_project_tasks_project_id ON project_tasks (project_id)');
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
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
