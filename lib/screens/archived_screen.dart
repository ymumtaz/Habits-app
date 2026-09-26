import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../data/project_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/habit.dart';
import '../models/project.dart';
import '../widgets/confirm_dialog.dart';

/// Lists archived habits and projects — the one place they're still
/// visible, since neither the Habits nor Projects screen shows them.
/// Each one can be brought back (unarchive) or deleted permanently.
class ArchivedScreen extends StatefulWidget {
  const ArchivedScreen({super.key});

  @override
  State<ArchivedScreen> createState() => _ArchivedScreenState();
}

class _ArchivedScreenState extends State<ArchivedScreen> {
  late Future<List<Habit>> _archivedHabits;
  late Future<List<Project>> _archivedProjects;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _archivedHabits = context.read<HabitProvider>().fetchArchivedHabits();
    _archivedProjects = context.read<ProjectProvider>().fetchArchivedProjects();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(t.archivedTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(t.homeTitle),
          FutureBuilder<List<Habit>>(
            future: _archivedHabits,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final habits = snapshot.data!;
              if (habits.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(t.noArchivedHabits),
                );
              }
              return Column(
                children: [
                  for (final habit in habits)
                    ListTile(
                      leading: Icon(habit.icon, color: habit.color),
                      title: Text(habit.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await context
                                  .read<HabitProvider>()
                                  .unarchiveHabit(habit);
                              setState(_reload);
                            },
                            child: Text(t.unarchive),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: t.deletePermanentlyTooltip,
                            onPressed: () async {
                              final confirmed = await confirmDelete(
                                context,
                                title: t.deleteHabitForeverTitle(habit.name),
                                message: t.deleteHabitForeverMessage,
                              );
                              if (!confirmed) return;
                              if (!context.mounted) return;
                              await context
                                  .read<HabitProvider>()
                                  .deleteHabit(habit);
                              setState(_reload);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const Divider(height: 32),
          _SectionHeader(t.projectsTitle),
          FutureBuilder<List<Project>>(
            future: _archivedProjects,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final projects = snapshot.data!;
              if (projects.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(t.noArchivedProjects),
                );
              }
              return Column(
                children: [
                  for (final project in projects)
                    ListTile(
                      leading: Icon(Icons.folder, color: project.color),
                      title: Text(project.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () async {
                              await context
                                  .read<ProjectProvider>()
                                  .unarchiveProject(project);
                              setState(_reload);
                            },
                            child: Text(t.unarchive),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: t.deletePermanentlyTooltip,
                            onPressed: () async {
                              final confirmed = await confirmDelete(
                                context,
                                title: t.deleteProjectForeverTitle(project.name),
                                message: t.deleteProjectForeverMessage,
                              );
                              if (!confirmed) return;
                              if (!context.mounted) return;
                              await context
                                  .read<ProjectProvider>()
                                  .deleteProject(project);
                              setState(_reload);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
