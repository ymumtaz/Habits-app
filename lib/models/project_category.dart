/// A user-managed label for grouping projects — e.g. "Course",
/// "Research", "Side project". Unlike a habit's fixed icon set, these
/// are entirely yours: add, rename, or delete your own from
/// Settings > Project categories. Deleting one just clears it off any
/// project that had it (they don't lose anything else).
class ProjectCategory {
  final int? id;
  final String name;
  final int sortOrder;

  const ProjectCategory({
    this.id,
    required this.name,
    this.sortOrder = 0,
  });

  ProjectCategory copyWith({
    int? id,
    String? name,
    int? sortOrder,
  }) {
    return ProjectCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
    };
  }

  factory ProjectCategory.fromMap(Map<String, Object?> map) {
    return ProjectCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}
