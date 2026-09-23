import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../models/habit.dart';
import '../services/streak_calculator.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/log_amount_dialog.dart';
import '../widgets/milestone_badges.dart';
import '../widgets/monthly_habit_calendar.dart';
import '../widgets/streak_badge.dart';
import '../widgets/streak_share_card.dart';
import '../widgets/undo_snackbar.dart';
import '../widgets/weekday_bar_chart.dart';
import 'add_edit_habit_screen.dart';
import 'year_heatmap_screen.dart';

/// Toggles [day] for a **boolean** [habit], confirming first when the
/// tap would *remove* an existing log — adding a new day never needs
/// confirming, since that's not destructive. A removal also offers a
/// quick "Undo" afterward, on top of the confirm dialog.
Future<void> _toggleDayWithConfirm(
  BuildContext context,
  HabitProvider provider,
  Habit habit,
  DateTime day,
) async {
  final isLogged = provider.doneDatesFor(habit).contains(
      DateTime(day.year, day.month, day.day));
  if (isLogged) {
    final confirmed = await confirmDelete(
      context,
      title: 'Remove this log?',
      message: 'This removes ${habit.name}\'s completion for '
          '${DateFormat('EEE, MMM d').format(day)}. This can\'t be undone.',
    );
    if (!confirmed) return;
    final removedLog = provider.logOn(habit, day);
    await provider.toggleForDate(habit, day);
    if (context.mounted) {
      showUndoSnackBar(
        context,
        message: 'Removed ${DateFormat('EEE, MMM d').format(day)}',
        onUndo: () {
          if (removedLog != null) {
            provider.restoreLog(habit, removedLog);
          } else {
            provider.toggleForDate(habit, day);
          }
        },
      );
    }
    return;
  }
  provider.toggleForDate(habit, day);
}

/// Opens the amount dialog for a **count/duration** [habit] on [day]
/// and saves whatever comes back (or clears the day if the result is
/// 0 and something was already logged, offering a quick "Undo").
Future<void> _logAmountFor(
  BuildContext context,
  HabitProvider provider,
  Habit habit,
  DateTime day,
) async {
  final current = provider.amountOn(habit, day);
  final result = await showLogAmountDialog(
    context,
    habit: habit,
    date: day,
    currentAmount: current,
  );
  if (result == null) return;
  if (result <= 0) {
    if (current != null) {
      final removedLog = provider.logOn(habit, day);
      await provider.removeLogForDate(habit, day);
      if (context.mounted && removedLog != null) {
        showUndoSnackBar(
          context,
          message: 'Removed ${DateFormat('EEE, MMM d').format(day)}',
          onUndo: () => provider.restoreLog(habit, removedLog),
        );
      }
    }
  } else {
    await provider.logAmountForDate(habit, day, result);
  }
}

class HabitDetailScreen extends StatefulWidget {
  final Habit habit;
  const HabitDetailScreen({super.key, required this.habit});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  // Created once (not per build) so the RepaintBoundary it's attached
  // to keeps a stable identity across rebuilds — recreating the key
  // every build would force Flutter to tear down and rebuild the
  // render object each time, which is wasteful and risks capturing
  // mid-rebuild.
  final _shareKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share(Habit current, StreakResult streak) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await shareStreakCard(_shareKey, current, streak);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't share streak: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final provider = context.watch<HabitProvider>();
    // The habit list may have refreshed (e.g. after an edit); find the
    // freshest copy so edits show immediately, falling back to the
    // one we were opened with.
    final current = provider.habits.firstWhere(
      (h) => h.id == habit.id,
      orElse: () => habit,
    );
    final streak = provider.streakFor(current);
    final isBoolean = current.type == HabitType.boolean;
    final todayAmount = provider.amountOn(current, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            tooltip: 'Share streak',
            onPressed: _sharing ? null : () => _share(current, streak),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddEditHabitScreen(existing: current),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'archive') {
                await provider.archiveHabit(current);
                if (context.mounted) Navigator.of(context).pop();
              } else if (value == 'delete') {
                final confirmed = await confirmDelete(
                  context,
                  title: 'Delete "${current.name}"?',
                  message: 'This permanently deletes the habit and its '
                      'entire completion history. This can\'t be undone.',
                );
                if (!confirmed) return;
                await provider.deleteHabit(current);
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
      body: Stack(
        // Positioned children land outside the Stack's own bounds by
        // default clip, which is exactly what we want for the
        // off-screen share-card render target below: still laid out
        // and painted (unlike Offstage, which skips painting
        // entirely and would leave the RepaintBoundary's layer empty,
        // making capture fail silently), just never visible.
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
          Row(
            children: [
              _Stat(label: 'Current streak', value: '${streak.currentStreak}'),
              _Stat(label: 'Best streak', value: '${streak.bestStreak}'),
              _Stat(label: 'Streak score', value: '${streak.score}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [StreakBadge(streak: streak.currentStreak, highlight: true)],
          ),
          const SizedBox(height: 12),
          MilestoneBadges(bestStreak: streak.bestStreak, color: current.color),
          if (current.tolerancePerMonth > 0) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Tolerates ${current.tolerancePerMonth} missed '
                'day${current.tolerancePerMonth == 1 ? '' : 's'}/month',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (isBoolean)
            FilledButton.icon(
              onPressed: () => provider.toggleToday(current),
              icon: Icon(
                streak.completedToday ? Icons.check_circle : Icons.add_task,
              ),
              label: Text(
                streak.completedToday ? 'Completed today' : 'Mark done today',
              ),
            )
          else
            FilledButton.icon(
              onPressed: () =>
                  _logAmountFor(context, provider, current, DateTime.now()),
              icon: Icon(
                streak.completedToday ? Icons.check_circle : Icons.add_task,
              ),
              label: Text(
                todayAmount == null
                    ? 'Log today\'s ${current.unitLabel}'
                    : '$todayAmount ${current.unitLabel} logged today'
                        '${current.dailyTarget != null ? ' / ${current.dailyTarget}' : ''}',
              ),
            ),
          const SizedBox(height: 24),
          if (!isBoolean) ...[
            Text('By day of the week',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Average ${current.unitLabel} logged on each weekday.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            WeekdayBarChart(
              logs: provider.rawLogsFor(current.id!),
              color: current.color,
              unitLabel: current.unitLabel,
            ),
            const SizedBox(height: 24),
          ],
          Text('Monthly overview',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            isBoolean
                ? 'Tap any past day to log or undo it — handy for '
                    'backfilling or testing the streak without waiting for '
                    'real days to pass.'
                : 'Tap any day to log or edit its amount.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          MonthlyHabitCalendar(
            completedDates: provider.doneDatesFor(current),
            color: current.color,
            onDayTap: (day) => isBoolean
                ? _toggleDayWithConfirm(context, provider, current, day)
                : _logAmountFor(context, provider, current, day),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => YearHeatmapScreen(habit: current),
              ),
            ),
            icon: const Icon(Icons.grid_view_outlined),
            label: const Text('View yearly heatmap'),
          ),
          const SizedBox(height: 24),
          Text('Recent history', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
              _HistoryList(habit: current),
            ],
          ),
          // Off-screen render target for the "Share streak" button —
          // positioned far outside the viewport (not hidden with
          // Offstage) so it's actually laid out *and painted*, which
          // is required for RepaintBoundary.toImage() to capture
          // anything. IgnorePointer keeps it from ever intercepting
          // taps.
          Positioned(
            left: -9999,
            top: 0,
            child: IgnorePointer(
              child: RepaintBoundary(
                key: _shareKey,
                child: StreakShareCard(habit: current, streak: streak),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Reads logs straight from the provider's cache via a rebuild trigger
/// so the history list stays in sync after any change.
class _HistoryList extends StatelessWidget {
  final Habit habit;
  const _HistoryList({required this.habit});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final logs = provider.rawLogsFor(habit.id!);

    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No completions logged yet.'),
      );
    }

    final formatter = DateFormat('EEE, MMM d');
    return Column(
      children: [
        for (final log in logs.take(30))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline),
            title: Text(formatter.format(log.date)),
            subtitle: log.amount != null
                ? Text('${log.amount} ${habit.unitLabel}')
                : null,
            trailing: IconButton(
              iconSize: 18,
              icon: const Icon(Icons.close),
              tooltip: 'Remove this day',
              onPressed: () async {
                final confirmed = await confirmDelete(
                  context,
                  title: 'Remove this log?',
                  message: 'This removes ${habit.name}\'s completion for '
                      '${formatter.format(log.date)}. This can\'t be undone.',
                );
                if (!confirmed) return;
                await provider.removeLogForDate(habit, log.date);
                if (context.mounted) {
                  showUndoSnackBar(
                    context,
                    message: 'Removed ${formatter.format(log.date)}',
                    onUndo: () => provider.restoreLog(habit, log),
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}
