import 'package:flutter/material.dart';

import '../services/streak_calculator.dart';

/// A row of milestone badges (7/30/100/365-day streaks) — filled and
/// colored once [bestStreak] has reached that threshold, outlined and
/// muted otherwise. A badge stays lit even if the current streak later
/// drops below its threshold, since it marks something already
/// achieved.
class MilestoneBadges extends StatelessWidget {
  final int bestStreak;
  final Color color;

  const MilestoneBadges({
    super.key,
    required this.bestStreak,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final threshold in milestoneThresholds)
          _MilestoneChip(
            threshold: threshold,
            earned: bestStreak >= threshold,
            color: color,
          ),
      ],
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  final int threshold;
  final bool earned;
  final Color color;

  const _MilestoneChip({
    required this.threshold,
    required this.earned,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: earned
          ? '$threshold-day streak reached'
          : '$threshold-day streak — not reached yet',
      child: Chip(
        avatar: Icon(
          Icons.emoji_events,
          size: 16,
          color: earned ? Colors.white : scheme.outline,
        ),
        label: Text('$threshold'),
        backgroundColor: earned ? color : scheme.surfaceContainerHighest,
        labelStyle: TextStyle(
          color: earned ? Colors.white : scheme.outline,
          fontWeight: earned ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide.none,
      ),
    );
  }
}
