/// A single stretch of time spent on a project. [endedAt] is null
/// while the session is still active (running or paused).
///
/// Supports pause/resume: [pausedAt] is set while the session is
/// currently paused, and [pausedSeconds] accumulates the total time
/// spent paused across earlier pause/resume cycles (not counting an
/// in-progress pause). [duration] subtracts all paused time from the
/// start-to-end (or start-to-now) span, so time spent paused never
/// counts toward the recorded total.
class TimeEntry {
  final int? id;
  final int projectId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? note;
  final DateTime? pausedAt;
  final int pausedSeconds;

  const TimeEntry({
    this.id,
    required this.projectId,
    required this.startedAt,
    this.endedAt,
    this.note,
    this.pausedAt,
    this.pausedSeconds = 0,
  });

  /// The session is still open (not yet ended & recorded) — either
  /// actively running or currently paused.
  bool get isActive => endedAt == null;

  /// Actively ticking right now.
  bool get isRunning => endedAt == null && pausedAt == null;

  /// Open, but currently paused (not ticking).
  bool get isPaused => endedAt == null && pausedAt != null;

  /// Elapsed active duration, excluding any time spent paused. For an
  /// open entry this is "so far, as of now" — call again for a fresh
  /// value rather than caching it.
  Duration get duration {
    final end = endedAt ?? DateTime.now();
    var pausedTotal = pausedSeconds;
    if (pausedAt != null) {
      pausedTotal += end.difference(pausedAt!).inSeconds;
    }
    final result = end.difference(startedAt) - Duration(seconds: pausedTotal);
    return result.isNegative ? Duration.zero : result;
  }

  TimeEntry copyWith({
    int? id,
    int? projectId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? note,
    bool clearNote = false,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    int? pausedSeconds,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      note: clearNote ? null : (note ?? this.note),
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'note': note,
      'paused_at': pausedAt?.toIso8601String(),
      'paused_seconds': pausedSeconds,
    };
  }

  factory TimeEntry.fromMap(Map<String, Object?> map) {
    final ended = map['ended_at'] as String?;
    final paused = map['paused_at'] as String?;
    return TimeEntry(
      id: map['id'] as int?,
      projectId: map['project_id'] as int,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: ended == null ? null : DateTime.parse(ended),
      note: map['note'] as String?,
      pausedAt: paused == null ? null : DateTime.parse(paused),
      pausedSeconds: map['paused_seconds'] as int? ?? 0,
    );
  }
}
