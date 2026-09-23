import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';

/// A checklist of [Task]s — purely organizational (done/not-done);
/// doesn't track time of its own. Callback-based rather than coupled
/// to [ProjectProvider] directly, so the same widget powers both a
/// project's own checklist (on its detail screen) and the standalone
/// "To-dos" list (tasks with no project).
class TaskChecklist extends StatefulWidget {
  final String title;
  final List<Task> tasks;
  final ValueChanged<String> onAdd;
  final ValueChanged<Task> onToggle;
  final ValueChanged<Task> onDelete;

  /// Called when a task's due-date chip is tapped/cleared. Omit to
  /// hide due-date UI entirely (e.g. a project's own checklist, which
  /// doesn't use due dates).
  final void Function(Task task, DateTime? dueDate)? onSetDueDate;

  final String addHint;

  /// Whether to show the add-a-task row at the bottom. Set false for
  /// a read-only list, e.g. the collapsed "Tasks for later" section,
  /// where adding happens through the main list instead.
  final bool showAddRow;

  const TaskChecklist({
    super.key,
    this.title = 'Tasks',
    required this.tasks,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
    this.onSetDueDate,
    this.addHint = 'Add a task',
    this.showAddRow = true,
  });

  @override
  State<TaskChecklist> createState() => _TaskChecklistState();
}

class _TaskChecklistState extends State<TaskChecklist> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    _controller.clear();
    widget.onAdd(name);
  }

  Future<void> _pickDueDate(Task task) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) widget.onSetDueDate?.call(task, picked);
  }

  String _dueLabel(DateTime due) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dueOnly = DateTime(due.year, due.month, due.day);
    final diff = dueOnly.difference(todayOnly).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < 0) return 'Overdue · ${DateFormat('MMM d').format(due)}';
    return DateFormat('MMM d').format(due);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final done = tasks.where((t) => t.completed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty) ...[
          Row(
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
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
        ],
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
            onDismissed: (_) => widget.onDelete(task),
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: task.completed,
              onChanged: (_) => widget.onToggle(task),
              title: Text(
                task.name,
                style: task.completed
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              subtitle: task.dueDate != null
                  ? Builder(builder: (context) {
                      final label = _dueLabel(task.dueDate!);
                      final isOverdue =
                          !task.completed && label.startsWith('Overdue');
                      return Text(
                        label,
                        style: isOverdue
                            ? TextStyle(color: Theme.of(context).colorScheme.error)
                            : null,
                      );
                    })
                  : null,
              secondary: widget.onSetDueDate == null
                  ? null
                  : Tooltip(
                      message: task.dueDate != null
                          ? 'Change date (long-press to clear)'
                          : 'Set a date',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _pickDueDate(task),
                        onLongPress: task.dueDate == null
                            ? null
                            : () => widget.onSetDueDate?.call(task, null),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            task.dueDate != null
                                ? Icons.event
                                : Icons.event_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        if (widget.showAddRow)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: widget.addHint,
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
