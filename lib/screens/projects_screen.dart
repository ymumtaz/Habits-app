import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../widgets/project_card.dart';
import 'add_edit_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: _buildBody(context, provider),
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

    return RefreshIndicator(
      onRefresh: provider.load,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: provider.projects.length,
        onReorder: provider.reorderProjects,
        itemBuilder: (context, index) {
          final project = provider.projects[index];
          return ProjectCard(
            key: ValueKey(project.id),
            project: project,
            totalDuration: provider.totalDurationFor(project),
            isRunning: provider.isRunning(project),
            isPaused: provider.isPaused(project),
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
          );
        },
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
