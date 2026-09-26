import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/habit_stats.dart';
import 'daily_bar_strip.dart';

/// The Insights "Habits" tab's last-7-days overview — a compact strip
/// showing overall habit completion per day, styled like a
/// step-counter or screen-time app's weekly view rather than the
/// calendar-month stats shown alongside it. Lives in Insights (and,
/// per-habit, on each habit's own detail page) rather than the main
/// Habits list, which is for quick daily action, not a dashboard.
class HabitWeekStrip extends StatelessWidget {
  final List<HabitDayRate> rates;

  const HabitWeekStrip({super.key, required this.rates});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.last7Days, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DailyBarStrip(
          days: [for (final r in rates) r.day],
          values: [for (final r in rates) r.rate],
          color: color,
          maxValue: 1.0,
          valueLabelBuilder: (v) => '${(v * 100).round()}%',
        ),
      ],
    );
  }
}
