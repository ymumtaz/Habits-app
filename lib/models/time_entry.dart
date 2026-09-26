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

  /// A short title for the session, like a post's headline — e.g. "Read
  /// chapter 4" or "Debugging the sync issue". Optional: null for older
  /// sessions logged before this existed, or for anyone who prefers to
  /// just use the note below.
  final String? title;
  final String? note;
  final DateTime? pausedAt;
  final int pausedSeconds;

  /// The countdown length this session was started with, in minutes —
  /// e.g. 25 for a Pomodoro-style countdown. Null means it was started
  /// as an open-ended (count-up) timer, or logged manually.
  final int? targetMinutes;

  const TimeEntry({
    this.id,
    required this.projectId,
    required this.startedAt,
    this.endedAt,
    this.title,
    this.note,
    this.pausedAt,
    this.pausedSeconds = 0,
    this.targetMinutes,
  });

  /// Remaining time toward [targetMinutes], or null if this session has
  /// no target. Goes negative once the countdown runs out — the caller
  /// decides how to present overtime rather than this clamping it.
  Duration? get remaining =>
      targetMinutes == null ? null : Duration(minutes: targetMinutes!) - duration;

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
    String? title,
    bool clearTitle = false,
    String? note,
    bool clearNote = false,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    int? pausedSeconds,
    int? targetMinutes,
    bool clearTargetMinutes = false,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      title: clearTitle ? null : (title ?? this.title),
      note: clearNote ? null : (note ?? this.note),
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      targetMinutes:
          clearTargetMinutes ? null : (targetMinutes ?? this.targetMinutes),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'title': title,
      'note': note,
      'paused_at': pausedAt?.toIso8601String(),
      'paused_seconds': pausedSeconds,
      'target_minutes': targetMinutes,
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
      title: map['title'] as String?,
      note: map['note'] as String?,
      pausedAt: paused == null ? null : DateTime.parse(paused),
      pausedSeconds: map['paused_seconds'] as int? ?? 0,
      targetMinutes: map['target_minutes'] as int?,
    );
  }
}
