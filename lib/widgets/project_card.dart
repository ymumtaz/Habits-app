import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/project.dart';
import '../models/project_category.dart';
import '../utils/duration_format.dart';

/// A project's avatar: its category's icon (falling back to a generic
/// folder when it has none), with a small badge overlaid in the
/// corner hinting at status — a play triangle for ongoing, a pause
/// for on hold, a check for completed — rather than swapping the
/// whole icon out. Shared between the main project row ([ProjectCard])
/// and the "Sub-projects" list on a project's own detail page, so both
/// draw the exact same glyph.
///
/// A running/paused session is a more urgent, momentary state than
/// the project's own (slower-moving) status, so it gets its own
/// highlight — a colored ring around the avatar — layered on top
/// rather than replacing the status badge.
class ProjectAvatar extends StatelessWidget {
  final Project project;

  /// The project's category's icon — resolved by the caller (via
  /// `ProjectProvider.categoryFor(project)?.icon`) since [Project]
  /// itself only stores the category id.
  final IconData? categoryIcon;

  final bool isActive;
  final double radius;

  const ProjectAvatar({
    super.key,
    required this.project,
    this.categoryIcon,
    this.isActive = false,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: project.color.withOpacity(0.18),
      foregroundColor: project.color,
      child: Icon(categoryIcon ?? defaultCategoryIcon),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        isActive
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: project.color, width: 2),
                ),
                padding: const EdgeInsets.all(2),
                child: avatar,
              )
            : avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: _StatusBadge(status: project.status, color: project.color),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ProjectStatus status;
  final Color color;

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      ProjectStatus.ongoing => Icons.play_arrow,
      ProjectStatus.onHold => Icons.pause,
      ProjectStatus.completed => Icons.check,
    };
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 1.5,
        ),
      ),
      child: Icon(icon, size: 10, color: Colors.white),
    );
  }
}

/// One row on the projects screen: name, total tracked time, and
/// tags. Purely a summary — starting/pausing/ending a session happens
/// through the single "Start session" flow (see
/// `widgets/start_session_dialog.dart`) or on the project's own detail
/// screen, not from buttons on every row here.
class ProjectCard extends StatelessWidget {
  final Project project;
  final Duration totalDuration;

  /// Whether this project has the app-wide active session right now
  /// (running or paused) — just highlights the row, no controls here.
  final bool isActive;

  /// The name of [Project.categoryId]'s category, if any — resolved by
  /// the caller since [Project] itself only stores the id.
  final String? categoryName;

  /// The icon of [Project.categoryId]'s category, if any — resolved by
  /// the caller, same as [categoryName]. Drives the avatar shown via
  /// [ProjectAvatar].
  final IconData? categoryIcon;

  /// False when the caller is drawing its own surrounding
  /// background/border (e.g. a parent+children family grouped into
  /// one shared container) — skips this card's own [Card] wrapper
  /// (elevation, margin, background) so it sits flush inside
  /// whatever the caller provides instead of doubling up.
  final bool showCard;

  /// Replaces the default trailing chevron — used for a family-root
  /// row's expand/collapse button instead of the usual "tap to open"
  /// hint.
  final Widget? trailing;

  /// Extra text appended after the normal time label, e.g. "2
  /// sub-projects · 3h 20m more" while a parent's children are
  /// collapsed out of view.
  final String? collapsedSummary;

  /// Shows a small "move" icon button next to [trailing] when set —
  /// the quickest way to re-nest this project under a different
  /// parent (or back to top-level) without opening its edit screen.
  final VoidCallback? onMove;

  final VoidCallback onTap;

  const ProjectCard({
    super.key,
    required this.project,
    required this.totalDuration,
    required this.isActive,
    this.categoryName,
    this.categoryIcon,
    this.showCard = true,
    this.trailing,
    this.collapsedSummary,
    this.onMove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final timeLabel = (isActive
            ? t.sessionActiveTimeLabel(formatDuration(totalDuration, t))
            : t.totalTimeLabel(formatDuration(totalDuration, t))) +
        (collapsedSummary != null ? ' · $collapsedSummary' : '');

    final content = InkWell(
      key: const Key('projectCardInkWell'),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ProjectAvatar(
              project: project,
              categoryIcon: categoryIcon,
              isActive: isActive,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category and status used to also show as text chips
                  // here, but both are now already conveyed by the
                  // avatar (its icon for category, the small overlay
                  // badge for status — see [ProjectAvatar]), so
                  // spelling them out again in words was redundant.
                  Text(
                    project.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isActive ? project.color : null,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                  ),
                ],
              ),
            ),
            if (onMove != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: t.moveToParentTooltip,
                icon: const Icon(Icons.drive_file_move_outline, size: 20),
                onPressed: onMove,
              ),
            trailing ?? const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );

    if (!showCard) return content;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: content,
    );
  }
}
