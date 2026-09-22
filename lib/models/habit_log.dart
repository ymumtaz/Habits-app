/// A single completion record for a habit on a given calendar day.
///
/// [date] is stored/compared at day resolution (time component zeroed
/// out) so "did the habit happen on this day" is unambiguous.
///
/// [amount] is null for boolean habits (the row's mere existence means
/// "done"). For count/duration habits it holds the logged quantity for
/// that day (e.g. glasses drunk, minutes spent) — see [Habit.type].
class HabitLog {
  final int? id;
  final int habitId;
  final DateTime date;
  final int? amount;
  final DateTime createdAt;

  const HabitLog({
    this.id,
    required this.habitId,
    required this.date,
    this.amount,
    required this.createdAt,
  });

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'date': dayOnly(date).toIso8601String(),
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HabitLog.fromMap(Map<String, Object?> map) {
    return HabitLog(
      id: map['id'] as int?,
      habitId: map['habit_id'] as int,
      date: DateTime.parse(map['date'] as String),
      amount: map['amount'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
