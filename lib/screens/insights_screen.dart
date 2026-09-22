import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../data/project_provider.dart';
import '../models/project.dart';
import '../utils/duration_format.dart';
import '../utils/habit_stats.dart';

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
          title: const Text('Insights'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Habits'),
              Tab(text: 'Projects'),
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

class _HabitsInsights extends StatelessWidget {
  const _HabitsInsights();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();

    if (provider.habits.isEmpty) {
      return const Center(child: Text('Add a habit to see stats here.'));
    }

    final stats = habitMonthlyStats(provider)
      ..sort((a, b) => b.rate.compareTo(a.rate));
    final overall = overallCompletionRate(stats);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This month',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '${(overall * 100).round()}% overall completion',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Best to worst this month',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final stat in stats)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stat.habit.name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${stat.doneDays}/${stat.totalDays}'
                      ' · ${(stat.rate * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: stat.rate.clamp(0.0, 1.0),
                    minHeight: 6,
                    color: stat.habit.color,
                    backgroundColor: stat.habit.color.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _Period { week, month, year }

class _ProjectsInsights extends StatefulWidget {
  const _ProjectsInsights();

  @override
  State<_ProjectsInsights> createState() => _ProjectsInsightsState();
}

class _ProjectsInsightsState extends State<_ProjectsInsights> {
  _Period _period = _Period.week;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    if (provider.projects.isEmpty) {
      return const Center(child: Text('Add a project to see stats here.'));
    }

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

    final byProject = provider.durationsForRange(start, end);
    final total = provider.totalDurationForRange(start, end);
    final entries = byProject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxDuration = entries.isEmpty
        ? Duration.zero
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<_Period>(
          segments: const [
            ButtonSegment(value: _Period.week, label: Text('Week')),
            ButtonSegment(value: _Period.month, label: Text('Month')),
            ButtonSegment(value: _Period.year, label: Text('Year')),
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
                Text('Total tracked', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  formatDurationCoarse(total),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('By project', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (total == Duration.zero)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No time tracked in this period yet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final entry in entries)
            if (entry.value > Duration.zero)
              _ProjectBar(
                project: entry.key,
                duration: entry.value,
                maxDuration: maxDuration,
              ),
      ],
    );
  }
}

class _ProjectBar extends StatelessWidget {
  final Project project;
  final Duration duration;
  final Duration maxDuration;

  const _ProjectBar({
    required this.project,
    required this.duration,
    required this.maxDuration,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxDuration.inSeconds == 0
        ? 0.0
        : duration.inSeconds / maxDuration.inSeconds;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                formatDurationCoarse(duration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              color: project.color,
              backgroundColor: project.color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
