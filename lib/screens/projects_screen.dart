import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../models/project.dart';
import '../widgets/project_card.dart';
import 'add_edit_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  ProjectStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: Column(
        children: [
          if (!provider.isLoading && provider.projects.isNotEmpty)
            _StatusFilterBar(
              selected: _filter,
              onChanged: (status) => setState(() => _filter = status),
            ),
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
            'No ${_filter!.label.toLowerCase()} projects.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }
      // A parent may itself be filtered out (different status than its
      // child) — orderProjectsWithDepth treats a project whose parent
      // isn't in this filtered subset as top-level, so grouping only
      // ever happens between projects that are both actually shown.
      final ordered = orderProjectsWithDepth(filtered);
      return RefreshIndicator(
        onRefresh: provider.load,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: ordered.length,
          itemBuilder: (context, index) {
            final (project, depth) = ordered[index];
            return _buildCard(context, provider, project, depth);
          },
        ),
      );
    }

    final ordered = orderProjectsWithDepth(provider.projects);
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
          return _buildCard(context, provider, project, depth);
        },
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    ProjectProvider provider,
    Project project,
    int depth,
  ) {
    return Padding(
      key: ValueKey(project.id),
      padding: EdgeInsets.only(left: 24.0 * depth),
      child: ProjectCard(
        project: project,
        totalDuration: provider.totalDurationFor(project),
        isRunning: provider.isRunning(project),
        isPaused: provider.isPaused(project),
        categoryName: provider.categoryFor(project)?.name,
        onToggleTimer: () {
          if (provider.isRunning(project)) {
            provider.pauseActiveSession();
          } else if (provider.isPaused(project)) {
            provider.resumeActiveSession();
          } else {
            provider.beginSession(project);
          }
        },
        onEndSession: () => provider.endActiveSession(),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(project: project),
          ),
        ),
      ),
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
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
            for (final status in ProjectStatus.values) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(status.label),
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
            Text('No projects yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add a project and begin a session whenever you work on it '
              '— this becomes your archive of time spent over the years.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add a project'),
            ),
          ],
        ),
      ),
    );
  }
}
