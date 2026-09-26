/// A user-managed label for what a tracked session was actually about
/// — e.g. "Physics", "Coding", "Literature review" — independent of
/// which project it was logged against. A session can carry several
/// at once. Add, rename, or delete your own from Settings > Session
/// tags; deleting one just clears it off any session that had it.
class SessionTag {
  final int? id;
  final String name;
  final int sortOrder;

  const SessionTag({
    this.id,
    required this.name,
    this.sortOrder = 0,
  });

  SessionTag copyWith({
    int? id,
    String? name,
    int? sortOrder,
  }) {
    return SessionTag(
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

  factory SessionTag.fromMap(Map<String, Object?> map) {
    return SessionTag(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}
