import 'package:flutter/material.dart';

import '../models/project.dart';
import '../utils/duration_format.dart';

/// One row on the projects screen: name, running/paused/total time,
/// and controls for the session (begin/pause/resume, plus end when
/// active).
class ProjectCard extends StatelessWidget {
  final Project project;
  final Duration totalDuration;
  final bool isRunning;
  final bool isPaused;

  /// The name of [Project.categoryId]'s category, if any — resolved by
  /// the caller since [Project] itself only stores the id.
  final String? categoryName;

  /// Cycles the session: begins one if idle, pauses if running,
  /// resumes if paused.
  final VoidCallback onToggleTimer;

  /// Ends & records the currently-open session. Only shown while
  /// [isRunning] or [isPaused] is true.
  final VoidCallback onEndSession;
  final VoidCallback onTap;

  const ProjectCard({
    super.key,
    required this.project,
    required this.totalDuration,
    required this.isRunning,
    required this.isPaused,
    this.categoryName,
    required this.onToggleTimer,
    required this.onEndSession,
    required this.onTap,
  });

  bool get _isActive => isRunning || isPaused;

  @override
  Widget build(BuildContext context) {
    final timeLabel = isRunning
        ? 'Running · ${formatDuration(totalDuration)} total'
        : (isPaused
            ? 'Paused · ${formatDuration(totalDuration)} total'
            : '${formatDuration(totalDuration)} total');
    final statusLabel = switch (project.status) {
      ProjectStatus.ongoing => null,
      ProjectStatus.onHold => 'On hold',
      ProjectStatus.completed => 'Completed',
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        key: const Key('projectCardInkWell'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: project.color.withOpacity(0.18),
                foregroundColor: project.color,
                child: const Icon(Icons.folder_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            project.name,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (categoryName != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: project.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                categoryName!,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: project.color),
                              ),
                            ),
                          ),
                        ],
                        if (statusLabel != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                statusLabel,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _isActive ? project.color : null,
                            fontWeight:
                                _isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                iconSize: 26,
                tooltip: isRunning ? 'Pause' : (isPaused ? 'Resume' : 'Begin'),
                onPressed: onToggleTimer,
                icon: Icon(
                  isRunning
                      ? Icons.pause
                      : (isPaused ? Icons.play_arrow : Icons.play_arrow),
                ),
                style: IconButton.styleFrom(
                  backgroundColor:
                      _isActive ? project.color.withOpacity(0.18) : null,
                  foregroundColor: _isActive ? project.color : null,
                ),
              ),
              if (_isActive)
                IconButton(
                  iconSize: 22,
                  tooltip: 'End & record',
                  onPressed: onEndSession,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
