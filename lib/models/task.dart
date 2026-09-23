/// A single to-do item.
///
/// When [projectId] is set, this is one entry in that project's
/// checklist (shown on its detail screen). When [projectId] is null,
/// it's a standalone item on the general "To-dos" list. Both cases
/// share this same model, storage, and UI — a task with no project is
/// simply the "no project" case, not a different kind of thing.
class Task {
  final int? id;
  final int? projectId;
  final String name;
  final bool completed;
  final int sortOrder;
  final DateTime createdAt;

  /// An optional date this task is due — date-only (time of day is
  /// ignored/stripped). Used to order the standalone "To-dos" section
  /// on the Habits page and to decide whether a task shows up front
  /// (due today, overdue, or undated) or gets tucked behind "Tasks for
  /// later" (due on a future date). Not used for time tracking.
  final DateTime? dueDate;

  const Task({
    this.id,
    this.projectId,
    required this.name,
    this.completed = false,
    this.sortOrder = 0,
    required this.createdAt,
    this.dueDate,
  });

  bool get isStandalone => projectId == null;

  Task copyWith({
    int? id,
    int? projectId,
    bool clearProjectId = false,
    String? name,
    bool? completed,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) {
    return Task(
      id: id ?? this.id,
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      name: name ?? this.name,
      completed: completed ?? this.completed,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'completed': completed ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, Object?> map) {
    final dueDateRaw = map['due_date'] as String?;
    return Task(
      id: map['id'] as int?,
      projectId: map['project_id'] as int?,
      name: map['name'] as String,
      completed: (map['completed'] as int? ?? 0) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      dueDate: dueDateRaw == null ? null : DateTime.parse(dueDateRaw),
    );
  }
}
