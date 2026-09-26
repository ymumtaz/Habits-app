import 'package:flutter/material.dart';

/// The wide set of icons available when creating or editing a project
/// category. Deliberately larger and more varied than a habit's fixed
/// icon set, since a category's icon now also drives a project's own
/// avatar (see `ProjectAvatar` in `widgets/project_card.dart`) — a
/// project shows its category's icon, with a small status badge (▶/⏸/✓)
/// layered on top, instead of a generic folder for every project.
///
/// Kept as a single canonical list of literal `Icons.xxx` values
/// (never constructed from a raw code point) so every reference here
/// is recognized by Flutter's icon font tree-shaker in release
/// builds. See [categoryIconForCodePoint] for how a stored code point
/// maps back to one of these.
const List<IconData> categoryIconChoices = <IconData>[
  Icons.folder_outlined,
  Icons.school_outlined,
  Icons.science_outlined,
  Icons.work_outline,
  Icons.laptop_mac,
  Icons.code,
  Icons.terminal,
  Icons.palette_outlined,
  Icons.brush_outlined,
  Icons.camera_alt_outlined,
  Icons.music_note_outlined,
  Icons.sports_esports_outlined,
  Icons.fitness_center,
  Icons.menu_book_outlined,
  Icons.business_center_outlined,
  Icons.language,
  Icons.calculate_outlined,
  Icons.biotech_outlined,
  Icons.engineering_outlined,
  Icons.gavel_outlined,
  Icons.restaurant_outlined,
  Icons.flight_outlined,
  Icons.directions_car_outlined,
  Icons.pets_outlined,
  Icons.spa_outlined,
  Icons.child_care_outlined,
  Icons.volunteer_activism_outlined,
  Icons.handyman_outlined,
  Icons.construction_outlined,
  Icons.design_services_outlined,
  Icons.rocket_launch_outlined,
  Icons.lightbulb_outline,
  Icons.cloud_outlined,
  Icons.storage_outlined,
  Icons.theater_comedy_outlined,
  Icons.groups_outlined,
  Icons.savings_outlined,
  Icons.star_outline,
  Icons.favorite_outline,
];

/// The icon a category (or a project with none) falls back to.
const IconData defaultCategoryIcon = Icons.folder_outlined;

/// Maps a code point loaded from the database back to one of
/// [categoryIconChoices] — a linear search over a fixed set of
/// literal `Icons.xxx` values, rather than constructing `IconData`
/// from the runtime [codePoint] directly, so the icon font can still
/// be tree-shaken in release builds. Falls back to
/// [defaultCategoryIcon] for a null or unrecognized code point (e.g.
/// a category created before icons existed).
IconData categoryIconForCodePoint(int? codePoint) {
  if (codePoint != null) {
    for (final icon in categoryIconChoices) {
      if (icon.codePoint == codePoint) return icon;
    }
  }
  return defaultCategoryIcon;
}

/// A user-managed label for grouping projects — e.g. "Course",
/// "Research", "Side project". Unlike a habit's fixed icon set, these
/// are entirely yours: add, rename, or delete your own from
/// Settings > Project categories. Deleting one just clears it off any
/// project that had it (they don't lose anything else).
class ProjectCategory {
  final int? id;
  final String name;
  final int sortOrder;
  final IconData icon;

  const ProjectCategory({
    this.id,
    required this.name,
    this.sortOrder = 0,
    this.icon = defaultCategoryIcon,
  });

  ProjectCategory copyWith({
    int? id,
    String? name,
    int? sortOrder,
    IconData? icon,
  }) {
    return ProjectCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      icon: icon ?? this.icon,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'icon_code_point': icon.codePoint,
    };
  }

  factory ProjectCategory.fromMap(Map<String, Object?> map) {
    return ProjectCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      icon: categoryIconForCodePoint(map['icon_code_point'] as int?),
    );
  }
}
