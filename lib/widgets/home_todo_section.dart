import 'package:flutter/material.dart';

import '../data/project_provider.dart';
import '../l10n/app_localizations.dart';
import 'task_checklist.dart';

/// The Habits page's to-do section: small things that don't belong to
/// any project (renaming a project checklist item is [TaskChecklist]
/// on the project's own detail screen instead). Tasks due today,
/// overdue, or with no date show directly; anything due on a future
/// date is tucked behind "Tasks for later" so the list isn't cluttered
/// with things weeks out.
class HomeTodoSection extends StatelessWidget {
  final ProjectProvider provider;

  const HomeTodoSection({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final due = provider.dueTasks;
    final later = provider.laterTasks;
    final t = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskChecklist(
          title: t.tasksTooltip,
          tasks: due,
          addHint: t.addATask,
          onAdd: (name) => provider.addTask(name),
          onToggle: provider.toggleTask,
          onDelete: provider.deleteTask,
          onSetDueDate: provider.setTaskDueDate,
        ),
        if (later.isNotEmpty)
          Theme(
            // Compact the ExpansionTile's default padding so it sits
            // flush with the list above it.
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                t.tasksForLater(later.length),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              children: [
                TaskChecklist(
                  title: '',
                  tasks: later,
                  showAddRow: false,
                  onAdd: (_) {},
                  onToggle: provider.toggleTask,
                  onDelete: provider.deleteTask,
                  onSetDueDate: provider.setTaskDueDate,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
