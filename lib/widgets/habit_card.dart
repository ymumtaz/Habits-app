import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/streak_calculator.dart';
import 'streak_badge.dart';

/// One row on the home screen: habit icon/name, streak badge, and a
/// tap-to-complete checkbox for today.
class HabitCard extends StatelessWidget {
  final Habit habit;
  final StreakResult streak;

  /// Today's logged amount for a count/duration habit — null if
  /// nothing's logged yet today. Unused for boolean habits.
  final int? todayAmount;

  final VoidCallback onToggleToday;
  final VoidCallback onTap;

  const HabitCard({
    super.key,
    required this.habit,
    required this.streak,
    this.todayAmount,
    required this.onToggleToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final periodLabel = habit.frequency == HabitFrequency.daily
        ? '${streak.completionsThisPeriod}/7 this week'
        : '${streak.completionsThisPeriod}/${habit.targetPerWeek} this week';
    final frequencyLabel =
        habit.frequency == HabitFrequency.daily ? 'Daily' : 'Weekly';
    final subtitle = '$frequencyLabel · $periodLabel';
    final isBoolean = habit.type == HabitType.boolean;
    final target = habit.dailyTarget;
    final showProgress = !isBoolean && target != null && target > 0;
    final progress = showProgress ? (todayAmount ?? 0) / target : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        // Keyed so tests can target this InkWell specifically — Material 3's
        // IconButton below also renders its own InkWell internally, which
        // makes an unkeyed `find.byType(InkWell)` ambiguous.
        key: const Key('habitCardInkWell'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: habit.color.withOpacity(0.18),
                foregroundColor: habit.color,
                child: Icon(habit.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (showProgress) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 5,
                          color: habit.color,
                          backgroundColor: habit.color.withOpacity(0.15),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${todayAmount ?? 0}/$target ${habit.unitLabel} today',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: streak.completedToday
                                  ? habit.color
                                  : null,
                              fontWeight: streak.completedToday
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StreakBadge(streak: streak.currentStreak, highlight: true),
              const SizedBox(width: 8),
              IconButton(
                iconSize: 32,
                onPressed: onToggleToday,
                icon: Icon(
                  streak.completedToday
                      ? Icons.check_circle
                      : (isBoolean
                          ? Icons.radio_button_unchecked
                          : Icons.add_circle_outline),
                ),
                color: streak.completedToday
                    ? habit.color
                    : Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
