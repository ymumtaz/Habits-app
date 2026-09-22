import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/project.dart';
import '../models/project_task.dart';
import '../models/time_entry.dart';
import '../utils/week_config.dart';
import 'project_repository.dart';

/// Observable app state for projects and time tracking. Mirrors the
/// shape of [HabitProvider]: loads from [ProjectRepository], caches
/// entries per project, and notifies listeners after mutations.
///
/// While a timer is running, a periodic tick keeps listeners
/// refreshing so the live elapsed time on screen stays current.
class ProjectProvider extends ChangeNotifier {
  ProjectProvider({ProjectRepository? repository})
      : _repo = repository ?? ProjectRepository();

  final ProjectRepository _repo;

  List<Project> _projects = [];
  Map<int, List<TimeEntry>> _entriesByProject = {};
  Map<int, List<ProjectTask>> _tasksByProject = {};
  TimeEntry? _activeEntry;
  bool _loading = true;
  Timer? _ticker;

  List<Project> get projects => List.unmodifiable(_projects);
  bool get isLoading => _loading;
  TimeEntry? get activeEntry => _activeEntry;

  /// Whether any project has an open session at all (running or
  /// paused) — used to warn that beginning a new one will end it.
  bool get isAnySessionActive => _activeEntry != null;

  bool isRunning(Project project) =>
      _activeEntry?.projectId == project.id && _activeEntry!.isRunning;

  bool isPaused(Project project) =>
      _activeEntry?.projectId == project.id && _activeEntry!.isPaused;

  /// True if [project] has the currently-open session, whether
  /// running or paused.
  bool isActive(Project project) => _activeEntry?.projectId == project.id;

  List<TimeEntry> entriesFor(int projectId) =>
      List.unmodifiable(_entriesByProject[projectId] ?? const []);

  List<ProjectTask> tasksFor(int projectId) =>
      List.unmodifiable(_tasksByProject[projectId] ?? const []);

  /// Total tracked time for a project, including the live elapsed
  /// time of its currently-running entry (if any).
  Duration totalDurationFor(Project project) {
    final entries = _entriesByProject[project.id] ?? const [];
    var total = Duration.zero;
    for (final e in entries) {
      total += e.duration;
    }
    return total;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    final results = await Future.wait([
      _repo.fetchProjects(),
      _repo.fetchAllEntries(),
      _repo.fetchActiveEntry(),
      _repo.fetchAllTasks(),
    ]);
    _projects = results[0] as List<Project>;
    _entriesByProject = results[1] as Map<int, List<TimeEntry>>;
    _activeEntry = results[2] as TimeEntry?;
    _tasksByProject = results[3] as Map<int, List<ProjectTask>>;

    _syncTicker();
    _loading = false;
    notifyListeners();
  }

  Future<void> addProject(Project project) async {
    await _repo.createProject(project);
    await load();
  }

  Future<void> updateProject(Project project) async {
    await _repo.updateProject(project);
    await load();
  }

  Future<void> archiveProject(Project project) async {
    if (project.id == null) return;
    await _repo.archiveProject(project.id!);
    await load();
  }

  Future<void> deleteProject(Project project) async {
    if (project.id == null) return;
    await _repo.deleteProject(project.id!);
    await load();
  }

  /// Begins a brand-new running session for [project]. Ends whatever
  /// other session (running or paused) was open, if any.
  Future<void> beginSession(Project project) async {
    if (project.id == null) return;
    await _repo.beginSession(project.id!);
    await _refreshEntriesAndActive();
  }

  /// Pauses the currently-running session, if there is one.
  Future<void> pauseActiveSession() async {
    final active = _activeEntry;
    if (active?.id == null || !active!.isRunning) return;
    await _repo.pauseSession(active.id!);
    await _refreshEntriesAndActive();
  }

  /// Resumes the currently-paused session, if there is one.
  Future<void> resumeActiveSession() async {
    final active = _activeEntry;
    if (active?.id == null || !active!.isPaused) return;
    await _repo.resumeSession(active.id!);
    await _refreshEntriesAndActive();
  }

  /// Idle detection: deducts [awayDuration] from the currently-running
  /// session's recorded time — used when the app was in the background
  /// for a while with a timer still running and the user confirms that
  /// stretch shouldn't count.
  Future<void> trimIdleTime(Duration awayDuration) async {
    final active = _activeEntry;
    if (active?.id == null || !active!.isRunning) return;
    await _repo.addPausedSeconds(active.id!, awayDuration.inSeconds);
    await _refreshEntriesAndActive();
  }

  /// Ends & records the currently-open session (running or paused).
  Future<void> endActiveSession() async {
    final active = _activeEntry;
    if (active?.id == null) return;
    await _repo.endSession(active!.id!);
    await _refreshEntriesAndActive();
  }

  /// Logs a past session manually — a chosen start time plus a
  /// duration — for testing or backfilling work you forgot to time.
  Future<void> addManualEntry(
    Project project, {
    required DateTime startedAt,
    required Duration duration,
    String? note,
  }) async {
    if (project.id == null) return;
    await _repo.addManualEntry(
      projectId: project.id!,
      startedAt: startedAt,
      duration: duration,
      note: note,
    );
    await _refreshEntriesAndActive();
  }

  Future<void> deleteEntry(TimeEntry entry) async {
    if (entry.id == null) return;
    await _repo.deleteEntry(entry.id!);
    await _refreshEntriesAndActive();
  }

  /// Re-inserts an entry that was just deleted — pairs with a delete
  /// confirmation's "Undo" snackbar action.
  Future<void> restoreEntry(TimeEntry entry) async {
    await _repo.restoreEntry(entry);
    await _refreshEntriesAndActive();
  }

  /// Applies a drag-to-reorder move on the projects screen and
  /// persists the new order, updating local state immediately so the
  /// drag feels instant.
  Future<void> reorderProjects(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final updated = List<Project>.from(_projects);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    _projects = updated;
    notifyListeners();

    final ids = [for (final p in updated) if (p.id != null) p.id!];
    await _repo.reorderProjects(ids);
  }

  /// Updates an existing entry's start time, duration, and/or note —
  /// e.g. fixing a mistyped manual entry or a timer session that ran
  /// longer than intended.
  Future<void> updateEntry(TimeEntry entry) async {
    if (entry.id == null) return;
    await _repo.updateEntry(entry);
    await _refreshEntriesAndActive();
  }

  // ---- Project tasks (optional checklist) ------------------------------

  Future<void> addTask(Project project, String name) async {
    if (project.id == null || name.trim().isEmpty) return;
    await _repo.createTask(ProjectTask(
      projectId: project.id!,
      name: name.trim(),
      createdAt: DateTime.now(),
    ));
    await _refreshTasksFor(project.id!);
  }

  Future<void> toggleTask(ProjectTask task) async {
    if (task.id == null) return;
    await _repo.updateTask(task.copyWith(completed: !task.completed));
    await _refreshTasksFor(task.projectId);
  }

  Future<void> renameTask(ProjectTask task, String newName) async {
    if (task.id == null || newName.trim().isEmpty) return;
    await _repo.updateTask(task.copyWith(name: newName.trim()));
    await _refreshTasksFor(task.projectId);
  }

  Future<void> deleteTask(ProjectTask task) async {
    if (task.id == null) return;
    await _repo.deleteTask(task.id!);
    await _refreshTasksFor(task.projectId);
  }

  Future<void> _refreshTasksFor(int projectId) async {
    final tasks = await _repo.fetchTasks(projectId);
    _tasksByProject[projectId] = tasks;
    notifyListeners();
  }

  /// The start of [day]'s week, honoring [WeekConfig.firstWeekday].
  static DateTime _weekStart(DateTime day) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    final offset = (dayOnly.weekday - WeekConfig.firstWeekday) % 7;
    return dayOnly.subtract(Duration(days: offset));
  }

  static DateTime weekStart(DateTime day) => _weekStart(day);
  static DateTime monthStart(DateTime day) => DateTime(day.year, day.month, 1);
  static DateTime yearStart(DateTime day) => DateTime(day.year, 1, 1);

  /// Total tracked time for [project] within the current calendar week
  /// (Monday–Sunday), including the live elapsed time of a running
  /// entry. Used to show progress against [Project.goalMinutesPerWeek].
  Duration weeklyDurationFor(Project project) {
    final start = _weekStart(DateTime.now());
    final end = start.add(const Duration(days: 7));
    return _durationFor(project, start, end);
  }

  Duration _durationFor(Project project, DateTime start, DateTime endExclusive) {
    final entries = _entriesByProject[project.id] ?? const [];
    var total = Duration.zero;
    for (final e in entries) {
      if (!e.startedAt.isBefore(start) && e.startedAt.isBefore(endExclusive)) {
        total += e.duration;
      }
    }
    return total;
  }

  /// Per-project tracked time within [start, endExclusive) — the
  /// building block for the cross-project time dashboard.
  Map<Project, Duration> durationsForRange(
    DateTime start,
    DateTime endExclusive,
  ) {
    return {
      for (final project in _projects)
        project: _durationFor(project, start, endExclusive),
    };
  }

  /// Total tracked time across every project within [start,
  /// endExclusive).
  Duration totalDurationForRange(DateTime start, DateTime endExclusive) {
    var total = Duration.zero;
    for (final project in _projects) {
      total += _durationFor(project, start, endExclusive);
    }
    return total;
  }

  Future<void> _refreshEntriesAndActive() async {
    final results = await Future.wait([
      _repo.fetchAllEntries(),
      _repo.fetchActiveEntry(),
    ]);
    _entriesByProject = results[0] as Map<int, List<TimeEntry>>;
    _activeEntry = results[1] as TimeEntry?;
    _syncTicker();
    notifyListeners();
  }

  /// Starts/stops a once-a-second tick so the UI's live "elapsed"
  /// display updates while a session is actively running, without a
  /// full reload. No need to tick while paused — the duration is
  /// frozen until resumed.
  void _syncTicker() {
    final shouldTick = _activeEntry?.isRunning ?? false;
    if (shouldTick && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
      });
    } else if (!shouldTick && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
