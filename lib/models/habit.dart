import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// How often a habit is expected to be done.
enum HabitFrequency { daily, weekly }

HabitFrequency habitFrequencyFromString(String value) {
  return HabitFrequency.values.firstWhere(
    (f) => f.name == value,
    orElse: () => HabitFrequency.daily,
  );
}

/// What a single day's log for this habit means.
///
/// - [boolean]: a log on a day means "done" — no amount tracked.
/// - [count]: a log carries a whole-number amount (e.g. glasses of
///   water); the day counts as done once the amount reaches
///   [Habit.dailyTarget].
/// - [duration]: a log carries a number of minutes (e.g. meditated for
///   12 min); the day counts as done once it reaches [Habit.dailyTarget].
enum HabitType { boolean, count, duration }

HabitType habitTypeFromString(String value) {
  return HabitType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => HabitType.boolean,
  );
}

/// Which direction [Habit.dailyTarget] counts in, for a count/duration
/// habit. Most habits are [atLeast] (do at least this much, e.g. 8
/// glasses of water) — [atMost] flips that for a habit you're trying
/// to cap rather than hit, e.g. "under 60 minutes of screen time" or
/// "no more than 2 coffees."
enum TargetMode { atLeast, atMost }

TargetMode targetModeFromString(String value) {
  return TargetMode.values.firstWhere(
    (m) => m.name == value,
    orElse: () => TargetMode.atLeast,
  );
}

/// The fixed set of icons a habit can use. Kept as a single canonical
/// list (rather than constructing `IconData` from a stored code point
/// directly) so every reference to a habit's icon in source is a
/// literal `Icons.xxx` — required for Flutter's icon font tree-shaking
/// to know which glyphs to keep in a release build. See
/// [iconForCodePoint] for how a stored code point maps back to one of
/// these.
const List<IconData> habitIconChoices = <IconData>[
  Icons.check_circle_outline,
  Icons.fitness_center,
  Icons.local_drink,
  Icons.menu_book,
  Icons.phone_iphone,
  Icons.bedtime,
  Icons.self_improvement,
  Icons.directions_run,
  Icons.spa_outlined,
  Icons.restaurant_outlined,
  Icons.local_florist_outlined,
  Icons.music_note_outlined,
  Icons.brush_outlined,
  Icons.code,
  Icons.savings_outlined,
  Icons.cleaning_services_outlined,
  Icons.pets_outlined,
  Icons.wb_sunny_outlined,
  Icons.language,
  Icons.eco_outlined,
  Icons.psychology_outlined,
  Icons.no_drinks_outlined,
];

/// Maps a code point loaded from the database back to one of
/// [habitIconChoices] — a `switch` over a fixed set of literal
/// `Icons.xxx` values, rather than constructing `IconData` from the
/// runtime [codePoint] directly, so the icon font can still be
/// tree-shaken in release builds. Falls back to the default icon for
/// a code point that doesn't match any current choice (e.g. old data
/// from a since-removed option).
IconData iconForCodePoint(int codePoint) {
  for (final icon in habitIconChoices) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.check_circle_outline;
}

/// A single habit definition, e.g. "Go to the gym" or "Drink water".
///
/// For [HabitFrequency.daily] habits, the streak is counted in
/// consecutive days. For [HabitFrequency.weekly] habits, [targetPerWeek]
/// says how many completions are needed in a calendar week for that
/// week to "count" toward the streak.
///
/// [tolerancePerMonth] lets a habit survive a small number of missed
/// *days* each calendar month without breaking the streak — see
/// `StreakCalculator` for exactly how that's applied. It's always
/// counted in days: for a daily habit that's a literal missed day; for
/// a weekly habit, an under-target week spends its shortfall (target
/// minus what was actually done) out of the same monthly day budget.
class Habit {
  final int? id;
  final String name;
  final String? description;
  final HabitFrequency frequency;
  final int targetPerWeek;
  final HabitType type;
  final int? dailyTarget;

  /// For a count/duration habit, whether [dailyTarget] is a floor to
  /// reach ([TargetMode.atLeast], the default) or a ceiling to stay
  /// under ([TargetMode.atMost]). Ignored for boolean habits.
  final TargetMode targetMode;

  /// A custom unit word for a [HabitType.count] habit, e.g. "pages" or
  /// "glasses" — shown instead of the generic "x" wherever a count is
  /// displayed (the habit card's daily progress, the log dialog, ...).
  /// Null or blank falls back to "x". Not used for [HabitType.duration]
  /// habits, which always show "min".
  final String? unit;

  final int tolerancePerMonth;
  final Color color;
  final IconData icon;
  final DateTime createdAt;
  final bool archived;

  const Habit({
    this.id,
    required this.name,
    this.description,
    this.frequency = HabitFrequency.daily,
    this.targetPerWeek = 7,
    this.type = HabitType.boolean,
    this.dailyTarget,
    this.targetMode = TargetMode.atLeast,
    this.unit,
    this.tolerancePerMonth = 0,
    this.color = Colors.teal,
    this.icon = Icons.check_circle_outline,
    required this.createdAt,
    this.archived = false,
  });

  /// The unit label shown next to amounts for count/duration habits,
  /// e.g. "pages" or "min". Empty for boolean habits. A custom count
  /// unit is shown exactly as the user typed it (not translated); the
  /// generic fallback and the duration unit come from [t].
  String unitLabel(AppLocalizations t) => switch (type) {
        HabitType.boolean => '',
        HabitType.count => (unit != null && unit!.trim().isNotEmpty)
            ? unit!.trim()
            : t.countUnitFallback,
        HabitType.duration => t.minutesAbbrev,
      };

  Habit copyWith({
    int? id,
    String? name,
    String? description,
    HabitFrequency? frequency,
    int? targetPerWeek,
    HabitType? type,
    int? dailyTarget,
    bool clearDailyTarget = false,
    TargetMode? targetMode,
    String? unit,
    bool clearUnit = false,
    int? tolerancePerMonth,
    Color? color,
    IconData? icon,
    DateTime? createdAt,
    bool? archived,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      targetPerWeek: targetPerWeek ?? this.targetPerWeek,
      type: type ?? this.type,
      dailyTarget:
          clearDailyTarget ? null : (dailyTarget ?? this.dailyTarget),
      targetMode: targetMode ?? this.targetMode,
      unit: clearUnit ? null : (unit ?? this.unit),
      tolerancePerMonth: tolerancePerMonth ?? this.tolerancePerMonth,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      archived: archived ?? this.archived,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'frequency': frequency.name,
      'target_per_week': targetPerWeek,
      'type': type.name,
      'daily_target': dailyTarget,
      'target_mode': targetMode.name,
      'unit': unit,
      'tolerance_per_month': tolerancePerMonth,
      'color': color.value,
      'icon_code_point': icon.codePoint,
      'created_at': createdAt.toIso8601String(),
      'archived': archived ? 1 : 0,
    };
  }

  factory Habit.fromMap(Map<String, Object?> map) {
    return Habit(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      frequency: habitFrequencyFromString(map['frequency'] as String),
      targetPerWeek: map['target_per_week'] as int? ?? 7,
      type: habitTypeFromString(map['type'] as String? ?? 'boolean'),
      dailyTarget: map['daily_target'] as int?,
      targetMode: targetModeFromString(map['target_mode'] as String? ?? 'atLeast'),
      unit: map['unit'] as String?,
      tolerancePerMonth: map['tolerance_per_month'] as int? ?? 0,
      color: Color(map['color'] as int),
      icon: iconForCodePoint(map['icon_code_point'] as int),
      createdAt: DateTime.parse(map['created_at'] as String),
      archived: (map['archived'] as int? ?? 0) == 1,
    );
  }
}
