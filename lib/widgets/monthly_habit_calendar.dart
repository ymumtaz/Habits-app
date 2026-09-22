import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A compact month grid showing which days a habit was completed.
/// Tapping a day toggles it — this is the "log to the past" entry
/// point, and doubles as a monthly overview of the habit.
///
/// Manages its own currently-viewed month (with prev/next arrows);
/// the completed-days data and the tap handler are owned by the
/// caller, same pattern as the rest of the app's stateless-ish screens.
class MonthlyHabitCalendar extends StatefulWidget {
  final Set<DateTime> completedDates;
  final Color color;
  final ValueChanged<DateTime> onDayTap;

  const MonthlyHabitCalendar({
    super.key,
    required this.completedDates,
    required this.color,
    required this.onDayTap,
  });

  @override
  State<MonthlyHabitCalendar> createState() => _MonthlyHabitCalendarState();
}

class _MonthlyHabitCalendarState extends State<MonthlyHabitCalendar> {
  late DateTime _visibleMonth = _firstOfMonth(DateTime.now());

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month);
  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _visibleMonth.year == now.year && _visibleMonth.month == now.month;
  }

  int get _completedThisMonth => widget.completedDates
      .where((d) =>
          d.year == _visibleMonth.year && d.month == _visibleMonth.month)
      .length;

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final firstWeekday = _visibleMonth.weekday; // 1 = Monday
    final today = _dayOnly(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                _visibleMonth =
                    DateTime(_visibleMonth.year, _visibleMonth.month - 1);
              }),
            ),
            Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_visibleMonth),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '$_completedThisMonth day${_completedThisMonth == 1 ? '' : 's'} completed',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _isCurrentMonth
                  ? null
                  : () => setState(() {
                        _visibleMonth = DateTime(
                            _visibleMonth.year, _visibleMonth.month + 1);
                      }),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: daysInMonth + (firstWeekday - 1),
          itemBuilder: (context, index) {
            final dayNumber = index - (firstWeekday - 1) + 1;
            if (dayNumber < 1) return const SizedBox.shrink();

            final day =
                DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
            final isFuture = day.isAfter(today);
            final isToday = day == today;
            final isDone = widget.completedDates.contains(day);

            return Padding(
              padding: const EdgeInsets.all(2),
              child: Material(
                color: isDone ? widget.color : Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: isFuture ? null : () => widget.onDayTap(day),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: isToday && !isDone
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: widget.color, width: 1.5),
                          )
                        : null,
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        color: isDone
                            ? Colors.white
                            : isFuture
                                ? Theme.of(context).colorScheme.outline
                                : null,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
