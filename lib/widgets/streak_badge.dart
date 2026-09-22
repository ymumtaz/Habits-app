import 'package:flutter/material.dart';

/// Small pill showing a streak count, e.g. "🔥 12".
class StreakBadge extends StatelessWidget {
  final int streak;
  final bool highlight;

  const StreakBadge({
    super.key,
    required this.streak,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = highlight && streak > 0
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final fg = highlight && streak > 0
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            streak > 0 ? Icons.local_fire_department : Icons.circle_outlined,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
