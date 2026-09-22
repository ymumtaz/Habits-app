import 'package:flutter/material.dart';

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
    this.tolerancePerMonth = 0,
    this.color = Colors.teal,
    this.icon = Icons.check_circle_outline,
    required this.createdAt,
    this.archived = false,
  });

  /// The unit label shown next to amounts for count/duration habits,
  /// e.g. "glasses" or "min". Empty for boolean habits.
  String get unitLabel => switch (type) {
        HabitType.boolean => '',
        HabitType.count => 'x',
        HabitType.duration => 'min',
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
      'tolerance_per_month': tolerancePerMonth,
      'color': color.toARGB32(),
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
      tolerancePerMonth: map['tolerance_per_month'] as int? ?? 0,
      color: Color(map['color'] as int),
      icon: IconData(map['icon_code_point'] as int,
          fontFamily: 'MaterialIcons'),
      createdAt: DateTime.parse(map['created_at'] as String),
      archived: (map['archived'] as int? ?? 0) == 1,
    );
  }
}
