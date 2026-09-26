import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../utils/duration_format.dart';

/// One series (a project) in a [StackedDailyBarChart].
class DailySeries {
  final String name;
  final Color color;

  /// Tracked time per day, same length/order as the chart's `days`.
  final List<Duration> values;

  const DailySeries({required this.name, required this.color, required this.values});
}

/// A column per day, each column stacked with one colored segment per
/// series (project) — "how was this week split across projects,"
/// day by day. Days with nothing tracked render as an empty outline
/// so the strip never looks broken, just quiet.
class StackedDailyBarChart extends StatelessWidget {
  final List<DateTime> days;
  final List<DailySeries> series;

  const StackedDailyBarChart({super.key, required this.days, required this.series});

  @override
  Widget build(BuildContext context) {
    final dayTotals = [
      for (var i = 0; i < days.length; i++)
        series.fold<Duration>(Duration.zero, (sum, s) => sum + s.values[i]),
    ];
    final maxTotal = dayTotals.fold<Duration>(
        Duration.zero, (a, b) => a > b ? a : b);
    final activeSeries = series.where(
      (s) => s.values.fold<Duration>(Duration.zero, (a, b) => a + b) > Duration.zero,
    );

    if (maxTotal == Duration.zero) {
      return Text(
        'No time tracked in the last 7 days.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 132,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _StackedColumn(
                    day: days[i],
                    total: dayTotals[i],
                    maxTotal: maxTotal,
                    segments: [
                      for (final s in series)
                        if (s.values[i] > Duration.zero)
                          (color: s.color, value: s.values[i]),
                    ],
                    isToday: days[i] == todayOnly,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (activeSeries.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final s in activeSeries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(s.name, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StackedColumn extends StatelessWidget {
  final DateTime day;
  final Duration total;
  final Duration maxTotal;
  final List<({Color color, Duration value})> segments;
  final bool isToday;

  const _StackedColumn({
    required this.day,
    required this.total,
    required this.maxTotal,
    required this.segments,
    required this.isToday,
  });

  static const _chartHeight = 88.0;

  @override
  Widget build(BuildContext context) {
    final columnHeight =
        maxTotal.inSeconds == 0 ? 0.0 : (total.inSeconds / maxTotal.inSeconds) * _chartHeight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 14,
          child: total > Duration.zero
              ? Text(formatDurationCoarse(total, context.l10n), style: Theme.of(context).textTheme.labelSmall)
              : null,
        ),
        SizedBox(
          height: _chartHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: SizedBox(
                height: columnHeight < 3 && total > Duration.zero ? 3 : columnHeight,
                child: total == Duration.zero
                    ? null
                    : Column(
                        children: [
                          for (final seg in segments)
                            Expanded(
                              flex: seg.value.inSeconds.clamp(1, 1 << 30).toInt(),
                              child: Container(color: seg.color),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: isToday
              ? BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                )
              : null,
          child: Text(
            DateFormat('E').format(day).substring(0, 1),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                  color: isToday ? Theme.of(context).colorScheme.primary : null,
                ),
          ),
        ),
      ],
    );
  }
}
