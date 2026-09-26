import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Where a project currently stands. Independent of [Project.archived]
/// — archiving hides a project from the main list entirely, while
/// status is just a visible label on an otherwise-active project (a
/// finished thesis can stay [completed] and visible for a while before
/// you decide to archive it).
enum ProjectStatus { ongoing, onHold, completed }

ProjectStatus projectStatusFromString(String value) {
  return ProjectStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ProjectStatus.ongoing,
  );
}

extension ProjectStatusLabel on ProjectStatus {
  String label(AppLocalizations t) => switch (this) {
        ProjectStatus.ongoing => t.statusOngoing,
        ProjectStatus.onHold => t.statusOnHold,
        ProjectStatus.completed => t.statusCompleted,
      };

  /// "No ongoing projects." style message for an empty filtered list —
  /// a full localized sentence per status rather than composing one
  /// from [label], since "no X projects" doesn't translate by simply
  /// lowercasing and concatenating in every language.
  String emptyFilterMessage(AppLocalizations t) => switch (this) {
        ProjectStatus.ongoing => t.noOngoingProjects,
        ProjectStatus.onHold => t.noOnHoldProjects,
        ProjectStatus.completed => t.noCompletedProjects,
      };
}

/// A project you're tracking time against, e.g. "Master's thesis" or
/// "Side project X". This is the unit the time-tracking archive is
/// built around.
class Project {
  final int? id;
  final String name;
  final String? description;

  /// Which [ProjectCategory] this project is tagged with, if any —
  /// see `data/project_provider.dart`'s `categoryFor`.
  final int? categoryId;

  final ProjectStatus status;

  /// Another project this one nests under, e.g. "Chapter 1" under
  /// "Master's thesis". Null for a top-level project. A project can
  /// have at most one parent (a tree, not a graph).
  final int? parentId;

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
    this.categoryId,
    this.status = ProjectStatus.ongoing,
    this.parentId,
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
    int? categoryId,
    bool clearCategoryId = false,
    ProjectStatus? status,
    int? parentId,
    bool clearParentId = false,
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
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      status: status ?? this.status,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
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
      'category_id': categoryId,
      'status': status.name,
      'parent_id': parentId,
      'goal_minutes_per_week': goalMinutesPerWeek,
      'color': color.value,
      'created_at': createdAt.toIso8601String(),
      'archived': archived ? 1 : 0,
    };
  }

  factory Project.fromMap(Map<String, Object?> map) {
    return Project(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      categoryId: map['category_id'] as int?,
      status: projectStatusFromString(map['status'] as String? ?? 'ongoing'),
      parentId: map['parent_id'] as int?,
      goalMinutesPerWeek: map['goal_minutes_per_week'] as int?,
      color: Color(map['color'] as int),
      createdAt: DateTime.parse(map['created_at'] as String),
      archived: (map['archived'] as int? ?? 0) == 1,
    );
  }
}
