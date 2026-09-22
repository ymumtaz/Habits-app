import 'package:flutter/material.dart';

/// A project you're tracking time against, e.g. "Master's thesis" or
/// "Side project X". This is the unit the time-tracking archive is
/// built around.
class Project {
  final int? id;
  final String name;
  final String? description;

  /// A free-text tag/category, e.g. "Coursework", "Research", "Personal"
  /// — lets you group and filter projects. Optional.
  final String? category;

  /// An optional weekly time goal, in minutes — e.g. 300 for "5 hours a
  /// week". Null means no goal is set for this project.
  final int? goalMinutesPerWeek;
  final Color color;
  final DateTime createdAt;
  final bool archived;

  const Project({
    this.id,
    required this.name,
    this.description,
    this.category,
    this.goalMinutesPerWeek,
    this.color = Colors.indigo,
    required this.createdAt,
    this.archived = false,
  });

  Project copyWith({
    int? id,
    String? name,
    String? description,
    bool clearDescription = false,
    String? category,
    bool clearCategory = false,
    int? goalMinutesPerWeek,
    bool clearGoal = false,
    Color? color,
    DateTime? createdAt,
    bool? archived,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description:
          clearDescription ? null : (description ?? this.description),
      category: clearCategory ? null : (category ?? this.category),
      goalMinutesPerWeek:
          clearGoal ? null : (goalMinutesPerWeek ?? this.goalMinutesPerWeek),
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      archived: archived ?? this.archived,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'goal_minutes_per_week': goalMinutesPerWeek,
      'color': color.toARGB32(),
      'created_at': createdAt.toIso8601String(),
      'archived': archived ? 1 : 0,
    };
  }

  factory Project.fromMap(Map<String, Object?> map) {
    return Project(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      category: map['category'] as String?,
      goalMinutesPerWeek: map['goal_minutes_per_week'] as int?,
      color: Color(map['color'] as int),
      createdAt: DateTime.parse(map['created_at'] as String),
      archived: (map['archived'] as int? ?? 0) == 1,
    );
  }
}
