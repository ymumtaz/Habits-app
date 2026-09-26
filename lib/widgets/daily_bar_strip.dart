import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A compact single-color bar per day, oldest-to-newest left to right
/// — the "last 7 days" strip style used by step-counter and
/// screen-time apps. Generic over what the value means (habit
/// completion rate, minutes worked, …); the caller supplies
/// [valueLabelBuilder] to format each bar's number.
class DailyBarStrip extends StatelessWidget {
  /// Oldest first, newest (usually today) last.
  final List<DateTime> days;

  /// Same length as [days].
  final List<double> values;

  final Color color;
  final String Function(double value) valueLabelBuilder;

  /// Scales the bars — pass the true max across a wider context (e.g.
  /// 1.0 for a 0–1 rate) rather than always leaving it to the visible
  /// days, or a quiet day would look artificially "full".
  final double maxValue;

  const DailyBarStrip({
    super.key,
    required this.days,
    required this.values,
    required this.color,
    required this.valueLabelBuilder,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    return SizedBox(
      // 14 (value label) + 72 (chart) + 4 (spacing) + 20 (day circle) —
      // sized to match exactly, since a Column of fixed-height children
      // inside a shorter SizedBox overflows (that's the stray "2.0
      // pixels" overflow banner this height used to produce).
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _Bar(
                value: values[i],
                maxValue: maxValue,
                color: color,
                label: context.l10n.weekdayInitial(days[i].weekday - 1),
                valueLabel: valueLabelBuilder(values[i]),
                isToday: days[i] == todayOnly,
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
  final Color color;
  final String label;
  final String valueLabel;
  final bool isToday;

  const _Bar({
    required this.value,
    required this.maxValue,
    required this.color,
    required this.label,
    required this.valueLabel,
    required this.isToday,
  });

  static const _chartHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    final hasValue = value > 0;
    final barHeight = maxValue <= 0 ? 0.0 : (value / maxValue) * _chartHeight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 14,
          child: hasValue
              ? Text(valueLabel, style: Theme.of(context).textTheme.labelSmall)
              : null,
        ),
        SizedBox(
          height: _chartHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: hasValue && barHeight < 3 ? 3 : barHeight,
              decoration: BoxDecoration(
                color: hasValue ? color : color.withOpacity(0.12),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                )
              : null,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                  color: isToday ? color : null,
                ),
          ),
        ),
      ],
    );
  }
}
