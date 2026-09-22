import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../models/habit.dart';
import '../widgets/year_heatmap.dart';

/// A full-screen, rolling 53-week contribution-style heatmap for a
/// single habit — always fully populated (not anchored to Jan 1), so
/// it looks "full" from the day you start using the habit.
class YearHeatmapScreen extends StatelessWidget {
  final Habit habit;
  const YearHeatmapScreen({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final current = provider.habits.firstWhere(
      (h) => h.id == habit.id,
      orElse: () => habit,
    );
    final completedDates = provider.doneDatesFor(current);
    final total = completedDates.length;

    return Scaffold(
      appBar: AppBar(title: Text('${current.name} — yearly overview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Last 53 weeks',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '$total day${total == 1 ? '' : 's'} completed in this window',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          YearHeatmap(
            completedDates: completedDates,
            color: current.color,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendSwatch(color: current.color.withValues(alpha: 0.08)),
              const SizedBox(width: 4),
              const Text('Not done', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 16),
              _LegendSwatch(color: current.color),
              const SizedBox(width: 4),
              const Text('Done', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;
  const _LegendSwatch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
