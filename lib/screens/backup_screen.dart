import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../data/project_provider.dart';
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
    try {
      await BackupService.exportBackup();
      if (!mounted) return;
      setState(() => _status = 'Backup created — choose where to save it.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Export failed: $e');
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

    final looksValid = await BackupService.looksLikeValidBackup(file);
    if (!looksValid) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = "That file doesn't look like a habits app backup — "
            'nothing was changed.';
      });
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
          'This replaces ALL current habits, logs, projects, and tracked '
          "time with what's in this backup file. Anything you've done "
          "since that backup was made will be lost. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Restore'),
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
      setState(() => _status =
          "Restored. Your habits and projects are back to that backup's "
          'state.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Everything lives only on this phone — habits, logs, projects, '
            'and every tracked minute. Export a backup now and then so a '
            "lost or wiped phone can't take years of history with it.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.upload_outlined),
            label: const Text('Export backup'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Restore from backup'),
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
