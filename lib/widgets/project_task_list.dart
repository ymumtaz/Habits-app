import 'package:flutter/material.dart';

import '../data/project_provider.dart';
import '../models/project.dart';
import '../models/project_task.dart';

/// An optional checklist of sub-tasks for a project — e.g. "Literature
/// review", "First draft" for a thesis. Purely organizational
/// (done/not-done); doesn't track time of its own.
class ProjectTaskList extends StatefulWidget {
  final Project project;
  final List<ProjectTask> tasks;
  final ProjectProvider provider;

  const ProjectTaskList({
    super.key,
    required this.project,
    required this.tasks,
    required this.provider,
  });

  @override
  State<ProjectTaskList> createState() => _ProjectTaskListState();
}

class _ProjectTaskListState extends State<ProjectTaskList> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    _controller.clear();
    await widget.provider.addTask(widget.project, name);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final done = tasks.where((t) => t.completed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Tasks', style: Theme.of(context).textTheme.titleSmall),
            if (tasks.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '$done/${tasks.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        for (final task in tasks)
          Dismissible(
            key: ValueKey(task.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
            onDismissed: (_) => widget.provider.deleteTask(task),
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: task.completed,
              onChanged: (_) => widget.provider.toggleTask(task),
              title: Text(
                task.name,
                style: task.completed
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Add a task',
                  isDense: true,
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add task',
              onPressed: _add,
            ),
          ],
        ),
      ],
    );
  }
}
