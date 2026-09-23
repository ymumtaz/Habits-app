import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database.dart';

/// Exports the whole local SQLite database as a single file the user
/// can save wherever they like (Google Drive, email, "Save to
/// device"...) via the platform share sheet, and restores from a
/// previously-exported file, replacing all current data.
///
/// This is the entire app's data in one file — every habit, every
/// log, every project, every tracked minute. There's no cloud sync,
/// so exporting one now and then is the only thing standing between
/// this phone's history and a lost or wiped device.
class BackupService {
  BackupService._();

  /// Copies the live database to a timestamped file in a temp
  /// directory and opens the platform share sheet for it. The
  /// database is briefly closed for the copy (it reopens
  /// automatically the next time anything reads from it, e.g. the
  /// next provider `load()`) so the file on disk can't be mid-write
  /// when it's copied.
  static Future<void> exportBackup() async {
    final dbPath = await AppDatabase.instance.databasePath;
    await AppDatabase.instance.close();
    final dbFile = File(dbPath);

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now();
    final name = 'habits_app_backup_'
        '${stamp.year}${_pad(stamp.month)}${_pad(stamp.day)}_'
        '${_pad(stamp.hour)}${_pad(stamp.minute)}.db';
    final backupFile = await dbFile.copy(p.join(tempDir.path, name));

    await Share.shareXFiles(
      [XFile(backupFile.path)],
      text: 'Habits app backup — $name',
    );
  }

  /// Whether [file] looks like a real backup of this app's database
  /// (has the tables this schema expects) rather than some unrelated
  /// file picked by mistake — a lightweight sanity check before
  /// overwriting live data with it. Opens the file read-only so it
  /// never touches the app's real database.
  static Future<bool> looksLikeValidBackup(File file) async {
    Database? check;
    try {
      check = await openDatabase(file.path, readOnly: true);
      final rows = await check.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN "
        "('habits', 'habit_logs', 'projects', 'time_entries')",
      );
      return rows.length == 4;
    } catch (_) {
      return false;
    } finally {
      await check?.close();
    }
  }

  /// Replaces the live database with [file]'s contents entirely.
  /// Destructive and irreversible — the caller must confirm with the
  /// user first, and must reload every provider (habits, projects)
  /// immediately after this returns so the UI reflects the restored
  /// data instead of stale in-memory state.
  static Future<void> restoreBackup(File file) async {
    final dbPath = await AppDatabase.instance.databasePath;
    await AppDatabase.instance.close();
    await file.copy(dbPath);
    // The next `AppDatabase.instance.database` access (from a
    // provider's `load()`) reopens it lazily — nothing further to do
    // here.
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
