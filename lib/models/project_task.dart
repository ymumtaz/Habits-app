/// An optional checklist item within a project — e.g. "Literature
/// review", "First draft", "Run experiments" for a thesis project.
/// Purely organizational (done/not-done); it doesn't carry its own
/// tracked time — time tracking stays at the project level.
class ProjectTask {
  final int? id;
  final int projectId;
  final String name;
  final bool completed;
  final int sortOrder;
  final DateTime createdAt;

  const ProjectTask({
    this.id,
    required this.projectId,
    required this.name,
    this.completed = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  ProjectTask copyWith({
    int? id,
    int? projectId,
    String? name,
    bool? completed,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return ProjectTask(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      completed: completed ?? this.completed,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
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
    };
  }

  factory ProjectTask.fromMap(Map<String, Object?> map) {
    return ProjectTask(
      id: map['id'] as int?,
      projectId: map['project_id'] as int,
      name: map['name'] as String,
      completed: (map['completed'] as int? ?? 0) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
