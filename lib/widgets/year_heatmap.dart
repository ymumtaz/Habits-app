import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A GitHub-contributions-style grid of the last [weeks] weeks, most
/// recent week first (left) so the interesting part is visible without
/// scrolling. Deliberately NOT anchored to Jan 1 — a calendar-year grid
/// would look mostly empty for months after you start using a habit.
/// A rolling window is always fully populated with real weeks, so it
/// reads as "full" from the day you start.
class YearHeatmap extends StatelessWidget {
  final Set<DateTime> completedDates;
  final Color color;
  final int weeks;

  const YearHeatmap({
    super.key,
    required this.completedDates,
    required this.color,
    this.weeks = 53,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mondayThisWeek =
        today.subtract(Duration(days: today.weekday - DateTime.monday));

    // Column 0 = this week (Mon..Sun), column 1 = last week, etc.
    final columns = List<List<DateTime>>.generate(weeks, (w) {
      final weekStart = mondayThisWeek.subtract(Duration(days: 7 * w));
      return List<DateTime>.generate(7, (d) => weekStart.add(Duration(days: d)));
    });

    final outline = Theme.of(context).colorScheme.outlineVariant;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var w = 0; w < columns.length; w++) ...[
              if (w > 0) const SizedBox(width: 3),
              _WeekColumn(
                days: columns[w],
                today: today,
                completedDates: completedDates,
                color: color,
                outline: outline,
                showMonthLabel: _isMonthStart(columns, w),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// True when this column is the first one (reading left-to-right,
  /// i.e. most-recent-first) that falls in a given calendar month —
  /// used to print a small month label above the grid.
  bool _isMonthStart(List<List<DateTime>> columns, int w) {
    final month = columns[w].first.month;
    final isLast = w == columns.length - 1;
    final nextMonth = isLast ? null : columns[w + 1].first.month;
    return nextMonth != null && nextMonth != month;
  }
}

class _WeekColumn extends StatelessWidget {
  final List<DateTime> days;
  final DateTime today;
  final Set<DateTime> completedDates;
  final Color color;
  final Color outline;
  final bool showMonthLabel;

  const _WeekColumn({
    required this.days,
    required this.today,
    required this.completedDates,
    required this.color,
    required this.outline,
    required this.showMonthLabel,
  });

  static const _cellSize = 12.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 14,
          child: showMonthLabel
              ? Text(
                  DateFormat('MMM').format(days.first),
                  style: Theme.of(context).textTheme.labelSmall,
                )
              : null,
        ),
        for (final day in days) ...[
          _Cell(
            filled: !day.isAfter(today) && completedDates.contains(day),
            isFuture: day.isAfter(today),
            color: color,
            outline: outline,
          ),
          const SizedBox(height: 3),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final bool filled;
  final bool isFuture;
  final Color color;
  final Color outline;

  const _Cell({
    required this.filled,
    required this.isFuture,
    required this.color,
    required this.outline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _WeekColumn._cellSize,
      height: _WeekColumn._cellSize,
      decoration: BoxDecoration(
        color: isFuture
            ? Colors.transparent
            : (filled ? color : color.withValues(alpha: 0.08)),
        border: isFuture ? null : Border.all(color: outline, width: 0.5),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
