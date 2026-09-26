import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../data/project_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/backup_service.dart';

/// Export the whole local database to a file you can save/share
/// anywhere, or restore from a previously-exported one.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String? _status;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    final t = context.l10n;
    try {
      await BackupService.exportBackup();
      if (!mounted) return;
      setState(() => _status = t.backupCreatedStatus);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = t.exportFailedStatus(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);

    setState(() {
      _busy = true;
      _status = null;
    });

    final t = context.l10n;
    final looksValid = await BackupService.looksLikeValidBackup(file);
    if (!looksValid) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = t.notAValidBackupStatus;
      });
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.restoreBackupTitle),
        content: Text(t.restoreBackupMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: Text(t.restore),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      setState(() => _busy = false);
      return;
    }

    try {
      await BackupService.restoreBackup(file);
      if (!mounted) return;
      await context.read<HabitProvider>().load();
      if (!mounted) return;
      await context.read<ProjectProvider>().load();
      if (!mounted) return;
      setState(() => _status = t.restoredStatus);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = t.restoreFailedStatus(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(t.backupRestore)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t.backupRestoreExplainer,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.upload_outlined),
            label: Text(t.exportBackup),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.download_outlined),
            label: Text(t.restoreFromBackup),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
