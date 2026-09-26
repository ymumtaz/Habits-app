import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/habit.dart';
import '../services/streak_calculator.dart';
import '../utils/habit_stats.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/daily_bar_strip.dart';
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
    final t = context.l10n;
    final dateStr = DateFormat('EEE, MMM d', t.locale.languageCode).format(day);
    final confirmed = await confirmDelete(
      context,
      title: t.removeLogTitle,
      message: t.removeLogMessage(habit.name, dateStr),
    );
    if (!confirmed) return;
    final removedLog = provider.logOn(habit, day);
    await provider.toggleForDate(habit, day);
    if (context.mounted) {
      showUndoSnackBar(
        context,
        message: t.removedOnDate(dateStr),
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
        final t = context.l10n;
        showUndoSnackBar(
          context,
          message: t.removedOnDate(DateFormat('EEE, MMM d', t.locale.languageCode).format(day)),
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
    final t = context.l10n;
    try {
      await shareStreakCard(_shareKey, current, streak, t);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.couldntShareStreak(e))),
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
    final last7Days = habitLast7DaysValuesFor(provider, current);
    final t = context.l10n;

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
            tooltip: t.shareStreakTooltip,
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
                  title: t.deleteHabitTitle(current.name),
                  message: t.deleteHabitMessage,
                );
                if (!confirmed) return;
                await provider.deleteHabit(current);
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
              _Stat(label: t.currentStreak, value: '${streak.currentStreak}'),
              _Stat(label: t.bestStreak, value: '${streak.bestStreak}'),
              _Stat(label: t.consistencyScoreLabel, value: '${streak.consistencyScore}'),
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
                t.toleratesMissedDays(current.tolerancePerMonth),
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
                streak.completedToday ? t.completedToday : t.markDoneToday,
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
                    ? context.l10n.logTodaysAmountLabel(current.unitLabel(context.l10n))
                    : context.l10n.loggedTodayAmount(
                        '$todayAmount',
                        current.unitLabel(context.l10n),
                        current.dailyTarget != null ? ' / ${current.dailyTarget}' : '',
                      ),
              ),
            ),
          const SizedBox(height: 24),
          Text(t.last7Days, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          DailyBarStrip(
            days: [for (final r in last7Days) r.day],
            values: [for (final r in last7Days) r.rate],
            color: current.color,
            maxValue: isBoolean
                ? 1.0
                : [
                    if (current.dailyTarget != null) current.dailyTarget!.toDouble(),
                    for (final r in last7Days) r.rate,
                  ].reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity).toDouble(),
            valueLabelBuilder: (v) => isBoolean
                ? (v > 0 ? '✓' : '')
                : (v > 0 ? '${v.round()}' : ''),
          ),
          const SizedBox(height: 24),
          if (!isBoolean) ...[
            Text(t.byDayOfWeek,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              t.averageLoggedPerWeekday(current.unitLabel(t)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            WeekdayBarChart(
              logs: provider.rawLogsFor(current.id!),
              color: current.color,
              unitLabel: current.unitLabel(t),
            ),
            const SizedBox(height: 24),
          ],
          Text(t.monthlyOverview,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            isBoolean ? t.tapPastDayBoolean : t.tapDayToLogAmount,
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
            label: Text(t.viewYearlyHeatmap),
          ),
          const SizedBox(height: 24),
          Text(t.recentHistory, style: Theme.of(context).textTheme.titleSmall),
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
    final t = context.l10n;

    if (logs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(t.noCompletionsLoggedYet),
      );
    }

    final formatter = DateFormat('EEE, MMM d', t.locale.languageCode);
    return Column(
      children: [
        for (final log in logs.take(30))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline),
            title: Text(formatter.format(log.date)),
            subtitle: log.amount != null
                ? Text('${log.amount} ${habit.unitLabel(t)}')
                : null,
            trailing: IconButton(
              iconSize: 18,
              icon: const Icon(Icons.close),
              tooltip: t.removeThisDayTooltip,
              onPressed: () async {
                final confirmed = await confirmDelete(
                  context,
                  title: t.removeLogTitle,
                  message: t.removeLogMessage(habit.name, formatter.format(log.date)),
                );
                if (!confirmed) return;
                await provider.removeLogForDate(habit, log.date);
                if (context.mounted) {
                  showUndoSnackBar(
                    context,
                    message: t.removedOnDate(formatter.format(log.date)),
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
