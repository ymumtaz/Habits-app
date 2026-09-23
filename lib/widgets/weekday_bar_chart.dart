import 'package:flutter/material.dart';

import '../models/habit_log.dart';

/// A column chart of a count/duration habit's average logged amount
/// per day of the week (Mon..Sun) — reveals patterns a running streak
/// number alone can't, like "I always read more on weekends" or
/// "Fridays are where this slips." Averaged only over days that
/// actually have a log, so a habit you've tracked for just a few weeks
/// isn't flattened by zeros for weekdays you simply haven't hit yet.
class WeekdayBarChart extends StatelessWidget {
  final List<HabitLog> logs;
  final Color color;
  final String unitLabel;

  const WeekdayBarChart({
    super.key,
    required this.logs,
    required this.color,
    required this.unitLabel,
  });

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    // Index 1..7 matches DateTime.weekday (Mon=1..Sun=7); index 0 unused.
    final sums = List<int>.filled(8, 0);
    final counts = List<int>.filled(8, 0);
    for (final log in logs) {
      final amount = log.amount;
      if (amount == null) continue;
      sums[log.date.weekday] += amount;
      counts[log.date.weekday] += 1;
    }
    final averages = [
      for (var wd = 0; wd < 8; wd++) counts[wd] == 0 ? 0.0 : sums[wd] / counts[wd],
    ];
    final maxValue = averages.skip(1).fold<double>(0, (a, b) => a > b ? a : b);

    if (maxValue <= 0) {
      return Text(
        'Log a few days to see the pattern by day of the week.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var wd = 1; wd <= 7; wd++) ...[
            if (wd > 1) const SizedBox(width: 8),
            Expanded(
              child: _Bar(
                value: averages[wd],
                maxValue: maxValue,
                hasData: counts[wd] > 0,
                color: color,
                label: _labels[wd - 1],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final double maxValue;
  final bool hasData;
  final Color color;
  final String label;

  const _Bar({
    required this.value,
    required this.maxValue,
    required this.hasData,
    required this.color,
    required this.label,
  });

  static const _chartHeight = 96.0;

  String get _valueLabel =>
      value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final barHeight = hasData ? (value / maxValue) * _chartHeight : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 16,
          child: hasData
              ? Text(_valueLabel, style: Theme.of(context).textTheme.labelSmall)
              : null,
        ),
        SizedBox(
          height: _chartHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: barHeight < 3 && hasData ? 3 : barHeight,
              decoration: BoxDecoration(
                color: hasData ? color : color.withOpacity(0.12),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
