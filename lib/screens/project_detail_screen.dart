import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../data/settings_provider.dart';
import '../models/project.dart';
import '../models/time_entry.dart';
import '../utils/duration_format.dart';
import '../widgets/add_manual_entry_dialog.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/project_task_list.dart';
import '../widgets/undo_snackbar.dart';
import 'add_edit_project_screen.dart';

class ProjectDetailScreen extends StatelessWidget {
  final Project project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final current = provider.projects.firstWhere(
      (p) => p.id == project.id,
      orElse: () => project,
    );
    final isRunning = provider.isRunning(current);
    final isPaused = provider.isPaused(current);
    final isActive = provider.isActive(current);
    final total = provider.totalDurationFor(current);
    final entries = provider.entriesFor(current.id!);
    final use24Hour = context.watch<SettingsProvider>().use24HourTime;
    final formatter =
        DateFormat(use24Hour ? 'EEE, MMM d · HH:mm' : 'EEE, MMM d · h:mm a');
    final goal = current.goalMinutesPerWeek;
    final weeklyMinutes = provider.weeklyDurationFor(current).inMinutes;

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddEditProjectScreen(existing: current),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'archive') {
                await provider.archiveProject(current);
                if (context.mounted) Navigator.of(context).pop();
              } else if (value == 'delete') {
                final confirmed = await confirmDelete(
                  context,
                  title: 'Delete "${current.name}"?',
                  message: 'This permanently deletes the project and all of '
                      'its tracked time sessions. This can\'t be undone.',
                );
                if (!confirmed) return;
                await provider.deleteProject(current);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'archive', child: Text('Archive')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  formatDuration(total),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  isRunning
                      ? 'Session running'
                      : (isPaused ? 'Session paused' : 'Total time tracked'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isActive ? current.color : null,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
              ],
            ),
          ),
          if (goal != null && goal > 0) ...[
            const SizedBox(height: 16),
            _WeeklyGoalProgress(
              minutesDone: weeklyMinutes,
              minutesGoal: goal,
              color: current.color,
            ),
          ],
          if (current.category != null && current.category!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Center(
              child: Chip(
                label: Text(current.category!),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (!isActive)
            FilledButton.icon(
              onPressed: () => provider.beginSession(current),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Begin session'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => isRunning
                        ? provider.pauseActiveSession()
                        : provider.resumeActiveSession(),
                    icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(isRunning ? 'Pause' : 'Resume'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => provider.endActiveSession(),
                    icon: const Icon(Icons.stop),
                    label: const Text('End & record'),
                  ),
                ),
              ],
            ),
          if (!isActive && provider.isAnySessionActive) ...[
            const SizedBox(height: 8),
            Text(
              'Beginning this will end the session running on another '
              'project.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await showAddManualEntryDialog(context);
              if (result != null) {
                await provider.addManualEntry(
                  current,
                  startedAt: result.startedAt,
                  duration: result.duration,
                  note: result.note,
                );
              }
            },
            icon: const Icon(Icons.history_edu_outlined),
            label: const Text('Add a past session'),
          ),
          const SizedBox(height: 24),
          ProjectTaskList(
            project: current,
            tasks: provider.tasksFor(current.id!),
            provider: provider,
          ),
          const SizedBox(height: 24),
          Text('Sessions', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No sessions logged yet.'),
            )
          else
            for (final entry in entries.take(50))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  entry.isRunning
                      ? Icons.radio_button_checked
                      : (entry.isPaused
                          ? Icons.pause_circle_outline
                          : Icons.check_circle_outline),
                  color: entry.isActive ? current.color : null,
                ),
                title: Text(formatter.format(entry.startedAt)),
                subtitle: entry.note != null && entry.note!.isNotEmpty
                    ? Text(entry.note!)
                    : null,
                onTap: entry.isActive
                    ? null
                    : () => _editEntry(context, provider, entry),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatDuration(entry.duration)),
                    if (!entry.isActive)
                      IconButton(
                        iconSize: 18,
                        icon: const Icon(Icons.close),
                        tooltip: 'Delete session',
                        onPressed: () =>
                            _deleteEntryWithConfirm(context, provider, entry),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

Future<void> _deleteEntryWithConfirm(
  BuildContext context,
  ProjectProvider provider,
  TimeEntry entry,
) async {
  final confirmed = await confirmDelete(
    context,
    title: 'Delete this session?',
    message: 'This removes the ${formatDuration(entry.duration)} session '
        'logged on ${DateFormat('EEE, MMM d').format(entry.startedAt)}. '
        'This can\'t be undone.',
  );
  if (!confirmed) return;
  await provider.deleteEntry(entry);
  if (context.mounted) {
    showUndoSnackBar(
      context,
      message: 'Session removed',
      onUndo: () => provider.restoreEntry(entry),
    );
  }
}

/// Opens the manual-entry dialog pre-filled with [entry]'s current
/// start time, duration, and note, and saves whatever comes back.
Future<void> _editEntry(
  BuildContext context,
  ProjectProvider provider,
  TimeEntry entry,
) async {
  final result = await showAddManualEntryDialog(context, existing: entry);
  if (result == null) return;
  await provider.updateEntry(entry.copyWith(
    startedAt: result.startedAt,
    endedAt: result.startedAt.add(result.duration),
    note: result.note,
    clearNote: result.note == null,
  ));
}

/// A small progress bar + label showing this week's tracked time
/// against a project's optional weekly goal.
class _WeeklyGoalProgress extends StatelessWidget {
  final int minutesDone;
  final int minutesGoal;
  final Color color;

  const _WeeklyGoalProgress({
    required this.minutesDone,
    required this.minutesGoal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (minutesDone / minutesGoal).clamp(0.0, 1.0);
    final doneLabel = formatDuration(Duration(minutes: minutesDone));
    final goalLabel = formatDuration(Duration(minutes: minutesGoal));

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$doneLabel of $goalLabel this week',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
