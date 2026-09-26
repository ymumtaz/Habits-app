import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../data/project_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/habit.dart';
import '../utils/duration_format.dart';
import '../utils/habit_stats.dart';
import '../widgets/daily_bar_strip.dart';
import '../widgets/monthly_bubble_chart.dart';
import 'habit_detail_screen.dart';
import 'project_detail_screen.dart';

/// Cross-habit and cross-project dashboards — the "archive" payoff:
/// at-a-glance stats built entirely from data already being tracked.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.insightsTabTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: context.l10n.habitsTab),
              Tab(text: context.l10n.projectsTab),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_HabitsInsights(), _ProjectsInsights()],
        ),
      ),
    );
  }
}

/// A one-habit-at-a-time view — the same stats shown on that habit's
/// own detail page, gathered in one place with a switcher up top so
/// you can flip through every habit without leaving Insights.
class _HabitsInsights extends StatefulWidget {
  const _HabitsInsights();

  @override
  State<_HabitsInsights> createState() => _HabitsInsightsState();
}

class _HabitsInsightsState extends State<_HabitsInsights> {
  int? _selectedHabitId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();

    if (provider.habits.isEmpty) {
      return Center(child: Text(context.l10n.addHabitToSeeStats));
    }

    final selected = provider.habits.firstWhere(
      (h) => h.id == _selectedHabitId,
      orElse: () => provider.habits.first,
    );
    final streak = provider.streakFor(selected);
    final isBoolean = selected.type == HabitType.boolean;
    final last7Days = habitLast7DaysValuesFor(provider, selected);

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    final daysSoFar = today.difference(monthStart).inDays + 1;
    final doneDays = provider
        .doneDatesFor(selected)
        .where((d) => !d.isBefore(monthStart) && !d.isAfter(today))
        .length;
    final monthRate = daysSoFar == 0 ? 0.0 : doneDays / daysSoFar;
    final t = context.l10n;
    final habitIndex = provider.habits.indexOf(selected);
    final (monthGridStart, monthGridEnd) = MonthlyBubbleChart.gridRange(now);
    final monthlyValues = <DateTime, double>{
      for (var d = monthGridStart; d.isBefore(monthGridEnd); d = d.add(const Duration(days: 1)))
        d: isBoolean
            ? (provider.doneDatesFor(selected).contains(d) ? 1.0 : 0.0)
            : (provider.amountOn(selected, d) ?? 0).toDouble(),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ItemSwitcher(
          label: selected.name,
          onPrevious: provider.habits.length > 1
              ? () => setState(() => _selectedHabitId = provider
                  .habits[(habitIndex - 1 + provider.habits.length) %
                          provider.habits.length]
                  .id)
              : null,
          onNext: provider.habits.length > 1
              ? () => setState(() => _selectedHabitId = provider
                  .habits[(habitIndex + 1) % provider.habits.length]
                  .id)
              : null,
          items: [
            for (final h in provider.habits)
              if (h.id != null) MapEntry(h.id!, h.name),
          ],
          onSelect: (id) => setState(() => _selectedHabitId = id),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _Stat(label: t.currentStreak, value: '${streak.currentStreak}'),
            _Stat(label: t.bestStreak, value: '${streak.bestStreak}'),
            _Stat(label: t.consistencyScoreLabel, value: '${streak.consistencyScore}'),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.thisMonth, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  t.monthCompletion((monthRate * 100).round(), doneDays, daysSoFar),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(t.last7Days, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        DailyBarStrip(
          days: [for (final r in last7Days) r.day],
          values: [for (final r in last7Days) r.rate],
          color: selected.color,
          maxValue: isBoolean
              ? 1.0
              : [
                  if (selected.dailyTarget != null) selected.dailyTarget!.toDouble(),
                  for (final r in last7Days) r.rate,
                ].reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity).toDouble(),
          valueLabelBuilder: (v) =>
              isBoolean ? (v > 0 ? '✓' : '') : (v > 0 ? '${v.round()}' : ''),
        ),
        const SizedBox(height: 24),
        MonthlyBubbleChart(
          month: now,
          valuesByDay: monthlyValues,
          color: selected.color,
          valueLabelBuilder: (v) => isBoolean
              ? (v > 0 ? t.doneLabel : '')
              : '${v.round()} ${selected.unitLabel(t)}',
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HabitDetailScreen(habit: selected),
            ),
          ),
          icon: const Icon(Icons.open_in_new),
          label: Text(t.openFullHabitPage),
        ),
      ],
    );
  }
}

/// A "< name >" switcher for flipping between habits/projects on the
/// Insights tabs: the current item's name in the middle, prev/next
/// chevrons on either side. Arrows disable themselves (rather than
/// being hidden) when there's nothing to flip to, e.g. only one
/// habit/project exists.
///
/// Also doubles as a dropdown: passing [items] (id -> display name)
/// and [onSelect] adds a small chevron next to the name — tapping the
/// name opens a menu of every item so you can jump straight to one
/// without stepping through the arrows, without changing the switcher's
/// normal look otherwise.
class _ItemSwitcher extends StatelessWidget {
  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final List<MapEntry<int, String>>? items;
  final ValueChanged<int>? onSelect;

  const _ItemSwitcher({
    required this.label,
    this.onPrevious,
    this.onNext,
    this.items,
    this.onSelect,
  });

  Future<void> _showPicker(BuildContext context) async {
    final entries = items;
    final select = onSelect;
    if (entries == null || select == null || entries.length <= 1) return;
    final box = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy + box.size.height,
      topLeft.dx + box.size.width,
      topLeft.dy,
    );
    final chosen = await showMenu<int>(
      context: context,
      position: position,
      items: [
        for (final e in entries)
          PopupMenuItem(value: e.key, child: Text(e.value)),
      ],
    );
    if (chosen != null) select(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final canPick = (items?.length ?? 0) > 1 && onSelect != null;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: canPick ? () => _showPicker(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (canPick) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
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

enum _Period { week, month, year }

/// A one-project-at-a-time view, mirroring [_HabitsInsights]: the same
/// stats shown on that project's own detail page, with a switcher up
/// top. The week/month/year toggle scopes the "Total tracked" figure
/// to whichever project is currently selected.
class _ProjectsInsights extends StatefulWidget {
  const _ProjectsInsights();

  @override
  State<_ProjectsInsights> createState() => _ProjectsInsightsState();
}

class _ProjectsInsightsState extends State<_ProjectsInsights> {
  _Period _period = _Period.week;
  int? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    if (provider.projects.isEmpty) {
      return Center(child: Text(context.l10n.addProjectToSeeStats));
    }

    final selected = provider.projects.firstWhere(
      (p) => p.id == _selectedProjectId,
      orElse: () => provider.projects.first,
    );

    final now = DateTime.now();
    final DateTime start;
    switch (_period) {
      case _Period.week:
        start = ProjectProvider.weekStart(now);
        break;
      case _Period.month:
        start = ProjectProvider.monthStart(now);
        break;
      case _Period.year:
        start = ProjectProvider.yearStart(now);
        break;
    }
    final end = now.add(const Duration(days: 1));
    final periodTotal = provider.durationsForRange(start, end)[selected] ?? Duration.zero;
    final weeklyMinutes = provider.weeklyDurationFor(selected).inMinutes;
    final monthly = provider.monthlyDurationFor(selected);
    final last7 = provider.last7DaysDurationsFor(selected);
    final (monthGridStart, monthGridEnd) = MonthlyBubbleChart.gridRange(now);
    final t = context.l10n;
    final projectIndex = provider.projects.indexOf(selected);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ItemSwitcher(
          label: selected.name,
          onPrevious: provider.projects.length > 1
              ? () => setState(() => _selectedProjectId = provider
                  .projects[(projectIndex - 1 + provider.projects.length) %
                          provider.projects.length]
                  .id)
              : null,
          onNext: provider.projects.length > 1
              ? () => setState(() => _selectedProjectId = provider
                  .projects[(projectIndex + 1) % provider.projects.length]
                  .id)
              : null,
          items: [
            for (final p in provider.projects)
              if (p.id != null) MapEntry(p.id!, p.name),
          ],
          onSelect: (id) => setState(() => _selectedProjectId = id),
        ),
        const SizedBox(height: 16),
        SegmentedButton<_Period>(
          segments: [
            ButtonSegment(value: _Period.week, label: Text(t.periodWeek)),
            ButtonSegment(value: _Period.month, label: Text(t.periodMonth)),
            ButtonSegment(value: _Period.year, label: Text(t.periodYear)),
          ],
          selected: {_period},
          onSelectionChanged: (s) => setState(() => _period = s.first),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.totalTracked, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  formatDurationCoarse(periodTotal, t),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: t.thisWeek,
                value: formatDurationCoarse(Duration(minutes: weeklyMinutes), t),
              ),
            ),
            Expanded(
              child: _Stat(
                label: t.thisMonth,
                value: formatDurationCoarse(monthly, t),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(t.last7Days, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        DailyBarStrip(
          days: [
            for (var i = 6; i >= 0; i--)
              DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
          ],
          values: [for (final d in last7) d.inMinutes.toDouble()],
          maxValue: last7
              .fold<int>(0, (max, d) => d.inMinutes > max ? d.inMinutes : max)
              .clamp(1, 1 << 30)
              .toDouble(),
          color: selected.color,
          valueLabelBuilder: (v) => formatDurationCoarse(Duration(minutes: v.round()), t),
        ),
        const SizedBox(height: 24),
        MonthlyBubbleChart(
          month: now,
          valuesByDay: {
            for (final e in provider
                .dailyDurationsForRange(selected, monthGridStart, monthGridEnd)
                .entries)
              e.key: e.value.inMinutes.toDouble(),
          },
          color: selected.color,
          valueLabelBuilder: (v) => formatDurationCoarse(Duration(minutes: v.round()), t),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProjectDetailScreen(project: selected),
            ),
          ),
          icon: const Icon(Icons.open_in_new),
          label: Text(t.openFullProjectPage),
        ),
      ],
    );
  }
}
