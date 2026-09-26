import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../data/settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/project.dart';
import '../models/time_entry.dart';
import '../utils/duration_format.dart';
import '../widgets/add_manual_entry_dialog.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/daily_bar_strip.dart';
import '../widgets/end_session_dialog.dart';
import '../widgets/monthly_bubble_chart.dart';
import '../widgets/project_card.dart';
import '../widgets/start_session_dialog.dart';
import '../widgets/task_checklist.dart';
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
    final formatter = DateFormat(
      use24Hour ? 'EEE, MMM d · HH:mm' : 'EEE, MMM d · h:mm a',
      context.l10n.locale.languageCode,
    );
    final goal = current.goalMinutesPerWeek;
    final weeklyMinutes = provider.weeklyDurationFor(current).inMinutes;
    final monthly = provider.monthlyDurationFor(current);
    final categoryName = provider.categoryFor(current)?.name;
    final parent = provider.parentOf(current);
    final children = provider.childrenOf(current);
    final activeRemaining = isActive ? provider.activeEntry?.remaining : null;
    final now = DateTime.now();
    final (monthGridStart, monthGridEnd) = MonthlyBubbleChart.gridRange(now);
    final t = context.l10n;

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
                  title: t.deleteProjectTitle(current.name),
                  message: t.deleteProjectMessage,
                );
                if (!confirmed) return;
                await provider.deleteProject(current);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'archive', child: Text(t.archiveMenuItem)),
              PopupMenuItem(value: 'delete', child: Text(t.deleteMenuItem)),
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
                  formatDuration(total, t),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  !isActive
                      ? t.totalTimeTracked
                      : activeRemaining == null
                          ? (isRunning ? t.sessionRunning : t.sessionPaused)
                          : activeRemaining.isNegative
                              ? '${isRunning ? t.runningLabel : t.pausedLabel} · '
                                  '+${formatDurationClock(activeRemaining.abs())} ${t.timeOverSuffix}'
                              : '${isRunning ? t.runningLabel : t.pausedLabel} · '
                                  '${formatDurationClock(activeRemaining)} ${t.timeLeftSuffix}',
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
          if (categoryName != null || parent != null) ...[
            const SizedBox(height: 12),
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (categoryName != null)
                    Chip(
                      label: Text(categoryName),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (parent != null)
                    ActionChip(
                      avatar: const Icon(Icons.subdirectory_arrow_right, size: 16),
                      label: Text(t.partOf(parent.name)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProjectDetailScreen(project: parent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: SegmentedButton<ProjectStatus>(
              segments: [
                ButtonSegment(
                    value: ProjectStatus.ongoing, label: Text(t.statusOngoing)),
                ButtonSegment(
                    value: ProjectStatus.onHold, label: Text(t.statusOnHold)),
                ButtonSegment(
                    value: ProjectStatus.completed, label: Text(t.statusCompleted)),
              ],
              selected: {current.status},
              onSelectionChanged: (selected) =>
                  provider.setStatus(current, selected.first),
            ),
          ),
          const SizedBox(height: 24),
          if (!isActive)
            FilledButton.icon(
              onPressed: () async {
                final choice = await showStartSessionDialog(
                  context,
                  projects: provider.projects,
                  initialProject: current,
                );
                if (choice != null) {
                  await provider.beginSession(
                    choice.project,
                    targetMinutes: choice.targetMinutes,
                  );
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(t.beginSession),
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
                    label: Text(isRunning ? t.pauseTooltip : t.resumeTooltip),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final active = provider.activeEntry;
                      if (active == null) return;
                      final result = await showEndSessionDialog(
                        context,
                        activeEntry: active,
                      );
                      if (result != null) {
                        await provider.endActiveSession(
                          duration: result.duration,
                          title: result.title,
                          note: result.note,
                          tagIds: result.tagIds,
                        );
                      }
                    },
                    icon: const Icon(Icons.stop),
                    label: Text(t.endAndRecordTooltip),
                  ),
                ),
              ],
            ),
          if (isActive) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    _cancelActiveSessionWithConfirm(context, provider),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(t.sessionCancelTooltip),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
          if (!isActive && provider.isAnySessionActive) ...[
            const SizedBox(height: 8),
            Text(
              t.beginningEndsOtherSession,
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
                  title: result.title,
                  note: result.note,
                  tagIds: result.tagIds,
                );
              }
            },
            icon: const Icon(Icons.history_edu_outlined),
            label: Text(t.addAPastSession),
          ),
          const SizedBox(height: 28),
          Text(t.timeOverview, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _OverviewStat(
                  label: t.thisWeek,
                  value: formatDurationCoarse(Duration(minutes: weeklyMinutes), t),
                ),
              ),
              Expanded(
                child: _OverviewStat(
                  label: t.thisMonth,
                  value: formatDurationCoarse(monthly, t),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DailyBarStrip(
            days: [
              for (var i = 6; i >= 0; i--)
                DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
            ],
            values: [
              for (final d in provider.last7DaysDurationsFor(current))
                d.inMinutes.toDouble(),
            ],
            maxValue: provider
                .last7DaysDurationsFor(current)
                .fold<int>(0, (max, d) => d.inMinutes > max ? d.inMinutes : max)
                .clamp(1, 1 << 30)
                .toDouble(),
            color: current.color,
            valueLabelBuilder: (v) => formatDurationCoarse(Duration(minutes: v.round()), t),
          ),
          const SizedBox(height: 20),
          MonthlyBubbleChart(
            month: now,
            valuesByDay: {
              for (final e in provider
                  .dailyDurationsForRange(current, monthGridStart, monthGridEnd)
                  .entries)
                e.key: e.value.inMinutes.toDouble(),
            },
            color: current.color,
            valueLabelBuilder: (v) => formatDurationCoarse(Duration(minutes: v.round()), t),
          ),
          const SizedBox(height: 24),
          TaskChecklist(
            tasks: provider.tasksFor(current.id!),
            onAdd: (name) => provider.addTask(name, project: current),
            onToggle: provider.toggleTask,
            onDelete: provider.deleteTask,
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(t.subProjects, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final child in children)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: ProjectAvatar(
                  project: child,
                  categoryIcon: provider.categoryFor(child)?.icon,
                  isActive: provider.isActive(child),
                  radius: 16,
                ),
                title: Text(child.name),
                trailing: Text(formatDuration(provider.totalDurationFor(child), t)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(project: child),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
          Text(t.sessions, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(t.noSessionsLoggedYet),
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
                title: Text(
                  (entry.title != null && entry.title!.isNotEmpty)
                      ? entry.title!
                      : formatter.format(entry.startedAt),
                  style: (entry.title != null && entry.title!.isNotEmpty)
                      ? const TextStyle(fontWeight: FontWeight.w600)
                      : null,
                ),
                subtitle: _entrySubtitle(context, provider, entry, formatter),
                onTap: entry.isActive
                    ? null
                    : () => _editEntry(context, provider, entry),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatDuration(entry.duration, t)),
                    if (!entry.isActive)
                      IconButton(
                        iconSize: 18,
                        icon: const Icon(Icons.close),
                        tooltip: t.deleteSessionTooltip,
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

/// The note and tag chips shown under a session's start time — null
/// when there's neither, so the row stays single-line.
Widget? _entrySubtitle(
  BuildContext context,
  ProjectProvider provider,
  TimeEntry entry,
  DateFormat formatter,
) {
  final tags = entry.id == null ? const [] : provider.tagsForEntry(entry.id!);
  final hasNote = entry.note != null && entry.note!.isNotEmpty;
  final hasTitle = entry.title != null && entry.title!.isNotEmpty;
  if (!hasTitle && !hasNote && tags.isEmpty) return null;

  return Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The title already took over the primary line, so the
        // timestamp moves down here instead of disappearing.
        if (hasTitle)
          Text(
            formatter.format(entry.startedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (hasNote) Text(entry.note!),
        if (tags.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: hasNote ? 4 : 0),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final tag in tags)
                  Chip(
                    label: Text('#${tag.name}', style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Discards the currently-active session (running or paused) entirely
/// — nothing gets recorded, unlike "End & record". For the common
/// slip of starting the wrong project, or realizing right away this
/// shouldn't be timed at all. Confirmed first, and undoable via the
/// same snackbar pattern as deleting a past session, since it's just
/// as easy to tap by accident.
Future<void> _cancelActiveSessionWithConfirm(
  BuildContext context,
  ProjectProvider provider,
) async {
  final active = provider.activeEntry;
  if (active == null) return;
  final t = context.l10n;
  final confirmed = await confirmDelete(
    context,
    title: t.cancelSessionTitle,
    message: t.cancelSessionMessage(formatDuration(active.duration, t)),
  );
  if (!confirmed) return;
  await provider.deleteEntry(active);
  if (context.mounted) {
    showUndoSnackBar(
      context,
      message: t.sessionCancelled,
      onUndo: () => provider.restoreEntry(active),
    );
  }
}

Future<void> _deleteEntryWithConfirm(
  BuildContext context,
  ProjectProvider provider,
  TimeEntry entry,
) async {
  final t = context.l10n;
  final confirmed = await confirmDelete(
    context,
    title: t.deleteSessionTitle,
    message: t.deleteSessionMessage(
      formatDuration(entry.duration, t),
      DateFormat('EEE, MMM d', t.locale.languageCode).format(entry.startedAt),
    ),
  );
  if (!confirmed) return;
  // Captured before the delete — deleting the entry also drops its
  // tag links, so Undo needs to know what to restore them to.
  final tagIds =
      entry.id == null ? const <int>[] : provider.tagsForEntry(entry.id!).map((tag) => tag.id!).toList();
  await provider.deleteEntry(entry);
  if (context.mounted) {
    showUndoSnackBar(
      context,
      message: t.sessionRemoved,
      onUndo: () => provider.restoreEntry(entry, tagIds: tagIds),
    );
  }
}

/// Opens the manual-entry dialog pre-filled with [entry]'s current
/// start time, duration, note, and tags, and saves whatever comes back.
Future<void> _editEntry(
  BuildContext context,
  ProjectProvider provider,
  TimeEntry entry,
) async {
  final existingTagIds =
      entry.id == null ? const <int>[] : provider.tagsForEntry(entry.id!).map((t) => t.id!).toList();
  final result = await showAddManualEntryDialog(
    context,
    existing: entry,
    existingTagIds: existingTagIds,
  );
  if (result == null) return;
  await provider.updateEntry(
    entry.copyWith(
      startedAt: result.startedAt,
      endedAt: result.startedAt.add(result.duration),
      title: result.title,
      note: result.note,
      clearNote: result.note == null,
    ),
    tagIds: result.tagIds,
  );
}

/// One number in the "Time overview" row (this week / this month).
class _OverviewStat extends StatelessWidget {
  final String label;
  final String value;
  const _OverviewStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
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
    final doneLabel = formatDuration(Duration(minutes: minutesDone), context.l10n);
    final goalLabel = formatDuration(Duration(minutes: minutesGoal), context.l10n);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: color,
            backgroundColor: color.withOpacity(0.15),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.doneOfGoalThisWeek(doneLabel, goalLabel),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
