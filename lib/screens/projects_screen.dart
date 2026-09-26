import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/project.dart';
import '../models/time_entry.dart';
import '../utils/duration_format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/end_session_dialog.dart';
import '../widgets/project_card.dart';
import '../widgets/start_session_dialog.dart';
import '../widgets/undo_snackbar.dart';
import 'add_edit_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  ProjectStatus? _filter;

  /// Ids of top-level projects whose children are currently collapsed
  /// out of view — a lightweight, session-only UI state (not
  /// persisted), separate from the family grouping itself.
  final Set<int> _collapsedRoots = {};

  Future<void> _startSession(
    BuildContext context,
    ProjectProvider provider, {
    Project? initialProject,
  }) async {
    final choice = await showStartSessionDialog(
      context,
      projects: provider.projects,
      initialProject: initialProject,
    );
    if (choice != null) {
      await provider.beginSession(choice.project, targetMinutes: choice.targetMinutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.projectsTitle)),
      body: Column(
        children: [
          if (!provider.isLoading && provider.projects.isNotEmpty) ...[
            if (provider.activeEntry != null)
              _ActiveSessionBanner(provider: provider)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _startSession(context, provider),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(context.l10n.startASession),
                  ),
                ),
              ),
            _StatusFilterBar(
              selected: _filter,
              onChanged: (status) => setState(() => _filter = status),
            ),
          ],
          Expanded(child: _buildBody(context, provider)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditProjectScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProjectProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.projects.isEmpty) {
      return _EmptyState(
        onAdd: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditProjectScreen()),
        ),
      );
    }

    // Reordering only makes sense against the unfiltered list — its
    // persisted sort_order spans every project, so dragging within a
    // filtered subset would otherwise scramble the full order.
    if (_filter != null) {
      final filtered =
          provider.projects.where((p) => p.status == _filter).toList();
      if (filtered.isEmpty) {
        return Center(
          child: Text(
            _filter!.emptyFilterMessage(context.l10n),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }
      // A parent may itself be filtered out (different status than its
      // child) — orderProjectsWithDepth treats a project whose parent
      // isn't in this filtered subset as top-level, so grouping only
      // ever happens between projects that are both actually shown.
      final ordered = orderProjectsWithDepth(filtered);
      final families = _familyInfo(ordered);
      return RefreshIndicator(
        onRefresh: provider.load,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: ordered.length,
          itemBuilder: (context, index) {
            final (project, depth) = ordered[index];
            return _buildItem(
                context, provider, project, depth, families[index]);
          },
        ),
      );
    }

    final ordered = orderProjectsWithDepth(provider.projects);
    final families = _familyInfo(ordered);
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: ordered.length,
        onReorder: (oldIndex, newIndex) {
          if (oldIndex < newIndex) newIndex -= 1;
          final newOrder = [for (final (p, _) in ordered) p];
          final moved = newOrder.removeAt(oldIndex);
          newOrder.insert(newIndex, moved);
          provider.reorderProjectsList(newOrder);
        },
        itemBuilder: (context, index) {
          final (project, depth) = ordered[index];
          return _buildItem(
              context, provider, project, depth, families[index]);
        },
      ),
    );
  }

  /// For each position in [ordered], describes where it sits within
  /// its "family" — a top-level project plus all of its descendants,
  /// which [orderProjectsWithDepth] always keeps contiguous. Powers
  /// the grouped-card look: a family with more than one member is
  /// drawn as one shared rounded container instead of separate cards.
  List<_FamilySlot> _familyInfo(List<(Project, int)> ordered) {
    final familyStart = List<int>.filled(ordered.length, 0);
    var start = 0;
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].$2 == 0) start = i;
      familyStart[i] = start;
    }
    final familySize = <int, int>{};
    for (final s in familyStart) {
      familySize[s] = (familySize[s] ?? 0) + 1;
    }
    return [
      for (var i = 0; i < ordered.length; i++)
        _FamilySlot(
          grouped: familySize[familyStart[i]]! > 1,
          isFirst: i == familyStart[i],
          isLast: i == ordered.length - 1 ||
              familyStart[i + 1] != familyStart[i],
          familyColor: ordered[familyStart[i]].$1.color,
          rootId: ordered[familyStart[i]].$1.id!,
        ),
    ];
  }

  int _descendantsCount(ProjectProvider provider, Project project) {
    var count = 0;
    for (final child in provider.childrenOf(project)) {
      count += 1 + _descendantsCount(provider, child);
    }
    return count;
  }

  Widget _buildItem(
    BuildContext context,
    ProjectProvider provider,
    Project project,
    int depth,
    _FamilySlot slot,
  ) {
    final familyCollapsed =
        slot.grouped && _collapsedRoots.contains(slot.rootId);

    // A collapsed family's children are hidden entirely — a zero-size
    // placeholder keeps the reorderable list's item count/keys stable
    // without needing to remap drag indices against a filtered list.
    if (familyCollapsed && depth > 0) {
      return SizedBox.shrink(key: ValueKey(project.id));
    }

    final isFamilyRoot = slot.grouped && depth == 0;
    // While collapsed, the root is the only visible row in its family
    // — it should look like the full (top-and-bottom-rounded, no
    // trailing divider) bottom of the group, regardless of where it'd
    // normally sit when every row is showing.
    final effectiveIsLast = slot.isLast || familyCollapsed;

    final card = ProjectCard(
      project: project,
      totalDuration: provider.totalDurationFor(project),
      isActive: provider.isActive(project),
      categoryName: provider.categoryFor(project)?.name,
      categoryIcon: provider.categoryFor(project)?.icon,
      showCard: !slot.grouped,
      collapsedSummary: (isFamilyRoot && familyCollapsed)
          ? context.l10n.subProjectsCollapsedSummary(
              _descendantsCount(provider, project),
            )
          : null,
      trailing: isFamilyRoot
          ? IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: familyCollapsed ? context.l10n.expand : context.l10n.collapse,
              icon: Icon(
                  familyCollapsed ? Icons.expand_more : Icons.expand_less),
              onPressed: () => setState(() {
                if (familyCollapsed) {
                  _collapsedRoots.remove(slot.rootId);
                } else {
                  _collapsedRoots.add(slot.rootId);
                }
              }),
            )
          : null,
      onMove: () => _showMoveToParentPicker(context, provider, project),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(project: project),
        ),
      ),
    );

    if (!slot.grouped) {
      return Padding(
        key: ValueKey(project.id),
        padding: EdgeInsets.only(left: 24.0 * depth),
        child: card,
      );
    }

    // A parent and all its children, grouped into one shared rounded
    // container (tinted with the top-level project's own color) so
    // the family reads as one unit — rounded only at the top of the
    // first row and the bottom of the last, with a thin divider
    // between rows instead of separate cards.
    return Container(
      key: ValueKey(project.id),
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: slot.isFirst ? 6 : 0,
        bottom: effectiveIsLast ? 6 : 0,
      ),
      decoration: BoxDecoration(
        color: slot.familyColor.withOpacity(0.06),
        border: Border.all(color: slot.familyColor.withOpacity(0.25)),
        borderRadius: BorderRadius.vertical(
          top: slot.isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: effectiveIsLast ? const Radius.circular(16) : Radius.zero,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(left: 24.0 * depth),
            child: card,
          ),
          if (!effectiveIsLast)
            Divider(
              height: 1,
              indent: 16 + 24.0 * depth,
              endIndent: 16,
              color: slot.familyColor.withOpacity(0.2),
            ),
        ],
      ),
    );
  }

  /// A quick re-parenting picker for [project] — the "Move to parent"
  /// shortcut on each card. Long-press-drag-to-reparent was considered
  /// (per the request that prompted this), but the projects list
  /// already uses long-press-drag for its own drag-to-reorder, and
  /// layering a second "drop onto another project" gesture on the same
  /// long-press-drag on the same rows would fight that existing,
  /// working interaction rather than complementing it. This bottom
  /// sheet gets to the same outcome — one tap to pick a new parent —
  /// without touching (or risking) the reordering gesture at all.
  Future<void> _showMoveToParentPicker(
    BuildContext context,
    ProjectProvider provider,
    Project project,
  ) async {
    final t = context.l10n;
    final eligible = provider.eligibleParents(project);
    final chosen = await showModalBottomSheet<Object?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                t.moveToParentTitle(project.name),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.horizontal_rule),
              title: Text(t.topLevelProjectOption),
              enabled: project.parentId != null,
              onTap: () => Navigator.of(context).pop(_noParent),
            ),
            for (final p in eligible)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(p.name),
                enabled: p.id != project.parentId,
                onTap: () => Navigator.of(context).pop(p),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await provider.setParent(
      project,
      chosen == _noParent ? null : chosen as Project,
    );
  }
}

/// Sentinel passed through [_ProjectsScreenState._showMoveToParentPicker]
/// to distinguish "explicitly chose top-level" from "dismissed the
/// sheet without choosing anything" (both of which would otherwise
/// look like a null result).
const _noParent = Object();

/// Where one project sits within its family group — see [_familyInfo].
class _FamilySlot {
  final bool grouped;
  final bool isFirst;
  final bool isLast;
  final Color familyColor;

  /// The top-level project's id this item's family is rooted at —
  /// what [_collapsedRoots] tracks collapse state by.
  final int rootId;

  const _FamilySlot({
    required this.grouped,
    required this.isFirst,
    required this.isLast,
    required this.familyColor,
    required this.rootId,
  });
}

/// A persistent banner replacing per-card timer buttons: shows the one
/// app-wide active session (running or paused), a countdown if it was
/// started with a target length, and pause/resume/end controls —
/// wherever it was started from, this is the one place to manage it
/// while browsing the Projects list.
class _ActiveSessionBanner extends StatelessWidget {
  final ProjectProvider provider;
  const _ActiveSessionBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    final entry = provider.activeEntry!;
    Project? project;
    for (final p in provider.projects) {
      if (p.id == entry.projectId) {
        project = p;
        break;
      }
    }
    if (project == null) return const SizedBox.shrink();

    final t = context.l10n;
    final remaining = entry.remaining;
    final timeLabel = remaining != null
        ? (remaining.isNegative
            ? '+${formatDurationClock(remaining.abs())} ${t.timeOverSuffix}'
            : '${formatDurationClock(remaining)} ${t.timeLeftSuffix}')
        : formatDurationClock(entry.duration);

    return Card(
      color: project.color.withOpacity(0.1),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${entry.isPaused ? t.pausedLabel : t.runningLabel} · $timeLabel',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: project.color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: entry.isRunning ? t.pauseTooltip : t.resumeTooltip,
              onPressed: () => entry.isRunning
                  ? provider.pauseActiveSession()
                  : provider.resumeActiveSession(),
              icon: Icon(entry.isRunning ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: t.endAndRecordTooltip,
              onPressed: () async {
                final result =
                    await showEndSessionDialog(context, activeEntry: entry);
                if (result != null) {
                  await provider.endActiveSession(
                    duration: result.duration,
                    title: result.title,
                    note: result.note,
                    tagIds: result.tagIds,
                  );
                }
              },
              icon: const Icon(Icons.stop_circle_outlined),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: context.l10n.cancelSessionTooltip,
              onPressed: () =>
                  _cancelActiveSessionWithConfirm(context, provider, entry),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// Discards the currently-active session entirely — nothing gets
/// recorded, unlike "End & record". See the matching helper on the
/// project detail screen for the full rationale; undoable the same
/// way a past session's delete is.
Future<void> _cancelActiveSessionWithConfirm(
  BuildContext context,
  ProjectProvider provider,
  TimeEntry entry,
) async {
  final t = context.l10n;
  final confirmed = await confirmDelete(
    context,
    title: t.cancelSessionTitle,
    message: t.cancelSessionMessage(formatDuration(entry.duration, t)),
  );
  if (!confirmed) return;
  await provider.deleteEntry(entry);
  if (context.mounted) {
    showUndoSnackBar(
      context,
      message: t.sessionCancelled,
      onUndo: () => provider.restoreEntry(entry),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final ProjectStatus? selected;
  final ValueChanged<ProjectStatus?> onChanged;

  const _StatusFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: Text(context.l10n.all),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
            for (final status in ProjectStatus.values) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(status.label(context.l10n)),
                selected: selected == status,
                onSelected: (_) => onChanged(status),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(context.l10n.noProjectsYet,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              context.l10n.noProjectsYetSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.addAProject),
            ),
          ],
        ),
      ),
    );
  }
}
