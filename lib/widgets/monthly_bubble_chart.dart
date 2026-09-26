import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../utils/week_config.dart';

/// A Google-Fit-style monthly calendar: every day always shows its
/// number, and days with logged time get a filled, size-scaled circle
/// behind that number (bigger circle = more that day); days with
/// nothing logged are just a plain muted number, no circle at all.
/// A weekly-totals list below the grid breaks the month down further,
/// the way Google Fit's monthly step view does.
class MonthlyBubbleChart extends StatelessWidget {
  /// Any date within the month to display.
  final DateTime month;

  /// Keyed by date-only day; days not present are treated as zero.
  final Map<DateTime, double> valuesByDay;

  final Color color;
  final String Function(double value) valueLabelBuilder;

  const MonthlyBubbleChart({
    super.key,
    required this.month,
    required this.valuesByDay,
    required this.color,
    required this.valueLabelBuilder,
  });

  /// The date-only range (inclusive [start], exclusive end) of the
  /// full calendar-week grid this widget renders for [month] — from
  /// the Monday/Sunday (per [WeekConfig.firstWeekday]) on or before
  /// the 1st, through the end of the final displayed week, which may
  /// reach a few days into the next month. Callers should fetch
  /// [valuesByDay] across this whole range, not just [month]'s own
  /// days, so the "Weekly totals" list below the grid can total a
  /// real Monday–Sunday week instead of only the days that happen to
  /// fall inside this month.
  static (DateTime start, DateTime endExclusive) gridRange(DateTime month) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = (firstOfMonth.weekday - WeekConfig.firstWeekday) % 7;
    final rowCount = ((leadingBlanks + daysInMonth) / 7).ceil();
    final start = firstOfMonth.subtract(Duration(days: leadingBlanks));
    return (start, start.add(Duration(days: rowCount * 7)));
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = (firstOfMonth.weekday - WeekConfig.firstWeekday) % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: leadingBlanks));
    final maxValue = valuesByDay.values.fold<double>(0, (a, b) => a > b ? a : b);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();
    final t = context.l10n;

    // Weekday initials, starting from [WeekConfig.firstWeekday] — the
    // 0-based index into [AppLocalizations.weekdayInitial] is
    // (weekday - 1), so this just walks 7 consecutive weekdays from
    // whichever one the week starts on.
    final weekdayLabels = [
      for (var i = 0; i < 7; i++)
        t.weekdayInitial((WeekConfig.firstWeekday - 1 + i) % 7),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMMM yyyy', t.locale.languageCode).format(month),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(label, style: Theme.of(context).textTheme.labelSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < rowCount; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _buildCell(
                      context,
                      row * 7 + col,
                      leadingBlanks,
                      daysInMonth,
                      firstOfMonth,
                      maxValue,
                      todayOnly,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Text(t.weeklyTotals, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (var row = 0; row < rowCount; row++)
          _weeklyTotalRow(context, gridStart, row),
      ],
    );
  }

  static const _cellSize = 40.0;

  Widget _buildCell(
    BuildContext context,
    int index,
    int leadingBlanks,
    int daysInMonth,
    DateTime firstOfMonth,
    double maxValue,
    DateTime todayOnly,
  ) {
    final dayNum = index - leadingBlanks + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: _cellSize);
    }

    final day = DateTime(firstOfMonth.year, firstOfMonth.month, dayNum);
    final value = valuesByDay[day] ?? 0;
    final isToday = day == todayOnly;
    final hasValue = value > 0;
    final fraction = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    // Smallest filled circle still reads as "logged something"; scale
    // up from there so even a modest day doesn't look like a rounding
    // error next to the month's best day, while always leaving room
    // for the day number inside it.
    final circleSize = hasValue ? 26.0 + fraction * 14.0 : 0.0;

    return Tooltip(
      message: '${DateFormat('MMM d', context.l10n.locale.languageCode).format(day)}'
          '${hasValue ? ' · ${valueLabelBuilder(value)}' : ''}',
      child: SizedBox(
        height: _cellSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (hasValue)
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            if (isToday && !hasValue)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
              ),
            Text(
              '$dayNum',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: hasValue
                        ? Colors.white
                        : (isToday
                            ? color
                            : Theme.of(context).colorScheme.onSurfaceVariant),
                    fontWeight: hasValue || isToday ? FontWeight.w700 : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// One "MMM d – MMM d: total" row for a calendar row of the grid —
  /// a real full week (per [WeekConfig.firstWeekday]), not clipped to
  /// this month's own days, so a week straddling the month boundary
  /// (e.g. the last row of September reaching into October) shows its
  /// actual Monday–Sunday range and total rather than a partial one
  /// like "Sep 28 – 30". Relies on the caller having fetched
  /// [valuesByDay] across [gridRange], not just [month] — see there.
  Widget _weeklyTotalRow(BuildContext context, DateTime gridStart, int row) {
    final weekStart = gridStart.add(Duration(days: row * 7));
    final weekEnd = weekStart.add(const Duration(days: 6));
    double total = 0;
    for (var i = 0; i < 7; i++) {
      total += valuesByDay[weekStart.add(Duration(days: i))] ?? 0;
    }

    final formatter = DateFormat('MMM d', context.l10n.locale.languageCode);
    final rangeLabel = '${formatter.format(weekStart)} – ${formatter.format(weekEnd)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rangeLabel, style: Theme.of(context).textTheme.bodySmall),
          Text(
            total > 0 ? valueLabelBuilder(total) : '—',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: total > 0 ? null : Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
