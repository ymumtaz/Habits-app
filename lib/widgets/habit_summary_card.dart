import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/habit_stats.dart';

/// A compact card at the top of the home screen showing this month's
/// overall completion rate across every habit, with a link into the
/// fuller Insights dashboard.
class HabitSummaryCard extends StatelessWidget {
  final VoidCallback onTap;
  const HabitSummaryCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    if (provider.habits.isEmpty) return const SizedBox.shrink();

    final stats = habitMonthlyStats(provider);
    final rate = overallCompletionRate(stats);
    final percent = (rate * 100).round();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.percentThisMonth(percent),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.overallCompletionAcross(stats.length),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
