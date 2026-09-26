import 'dart:async';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/project_category.dart';
import '../models/session_tag.dart';
import '../models/task.dart';
import '../models/time_entry.dart';
import '../services/notification_service.dart';
import '../utils/duration_format.dart';
import '../utils/locale_prefs.dart';
import '../utils/week_config.dart';
import 'project_repository.dart';

/// Orders [source] so every project appears directly after its parent
/// (recursively, for grandchildren and beyond), each paired with its
/// depth in that chain (0 for a top-level project). Only relationships
/// *within* [source] count — a project whose parent isn't in [source]
/// (e.g. filtered out, or archived) is treated as top-level here. Sort
/// order within each sibling group, and among top-level projects,
/// follows [source]'s own order.
List<(Project, int)> orderProjectsWithDepth(List<Project> source) {
  final ids = {for (final p in source) if (p.id != null) p.id!};
  final childrenOf = <int?, List<Project>>{};
  for (final p in source) {
    final key = (p.parentId != null && ids.contains(p.parentId))
        ? p.parentId
        : null;
    childrenOf.putIfAbsent(key, () => []).add(p);
  }

  final result = <(Project, int)>[];
  void emit(Project p, int depth) {
    result.add((p, depth));
    for (final child in childrenOf[p.id] ?? const <Project>[]) {
      emit(child, depth + 1);
    }
  }

  for (final p in childrenOf[null] ?? const <Project>[]) {
    emit(p, 0);
  }
  return result;
}

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
  List<ProjectCategory> _categories = [];
  Map<int, List<TimeEntry>> _entriesByProject = {};
  Map<int, List<Task>> _tasksByProject = {};
  List<Task> _standaloneTasks = [];
  List<SessionTag> _tags = [];
  Map<int, List<int>> _entryTagIds = {};
  TimeEntry? _activeEntry;
  bool _loading = true;
  Timer? _ticker;

  List<Project> get projects => List.unmodifiable(_projects);
  List<ProjectCategory> get categories => List.unmodifiable(_categories);
  List<Task> get standaloneTasks => List.unmodifiable(_standaloneTasks);
  List<SessionTag> get tags => List.unmodifiable(_tags);
  bool get isLoading => _loading;
  TimeEntry? get activeEntry => _activeEntry;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Standalone to-dos that belong on the main list right now: overdue,
  /// due today, or with no date at all. Dated ones sort earliest-first
  /// (most overdue at the top); undated ones follow, in the order they
  /// were added.
  List<Task> get dueTasks {
    final today = _dateOnly(DateTime.now());
    final tasks = _standaloneTasks
        .where((t) => t.dueDate == null || !_dateOnly(t.dueDate!).isAfter(today))
        .toList();
    tasks.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
    return List.unmodifiable(tasks);
  }

  /// Standalone to-dos due on a future date — tucked behind "Tasks for
  /// later" so the main list isn't cluttered with things due weeks out.
  /// Soonest first.
  List<Task> get laterTasks {
    final today = _dateOnly(DateTime.now());
    final tasks = _standaloneTasks
        .where((t) => t.dueDate != null && _dateOnly(t.dueDate!).isAfter(today))
        .toList();
    tasks.sort((a, b) {
      final cmp = a.dueDate!.compareTo(b.dueDate!);
      return cmp != 0 ? cmp : a.sortOrder.compareTo(b.sortOrder);
    });
    return List.unmodifiable(tasks);
  }

  /// How many standalone to-dos are still unchecked — drives the badge
  /// on the Habits page's to-dos shortcut so it's visible at a glance
  /// without opening the list.
  int get pendingTaskCount =>
      _standaloneTasks.where((t) => !t.completed).length;

  /// How many standalone to-dos are due *today specifically* and still
  /// unchecked. This — not [pendingTaskCount] — drives the Habits page
  /// badge: it's meant as a quick "what's on for today" count, not a
  /// running total of everything on the list (undated and future-dated
  /// to-dos don't belong in that number).
  int get todayTaskCount {
    final today = _dateOnly(DateTime.now());
    return _standaloneTasks
        .where((t) =>
            !t.completed &&
            t.dueDate != null &&
            _dateOnly(t.dueDate!) == today)
        .length;
  }

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

  List<Task> tasksFor(int projectId) =>
      List.unmodifiable(_tasksByProject[projectId] ?? const []);

  /// The category a project is tagged with, if any and if it still
  /// exists (it may have been deleted since).
  ProjectCategory? categoryFor(Project project) {
    if (project.categoryId == null) return null;
    for (final c in _categories) {
      if (c.id == project.categoryId) return c;
    }
    return null;
  }

  /// The tags currently on session [entryId] (only those that still
  /// exist — one may have been deleted since), in the app's normal
  /// tag order.
  List<SessionTag> tagsForEntry(int entryId) {
    final ids = _entryTagIds[entryId];
    if (ids == null || ids.isEmpty) return const [];
    return [for (final t in _tags) if (ids.contains(t.id)) t];
  }

  /// The project this one nests under, if any and if it's still an
  /// active (non-archived) project.
  Project? parentOf(Project project) {
    if (project.parentId == null) return null;
    for (final p in _projects) {
      if (p.id == project.parentId) return p;
    }
    return null;
  }

  /// Direct sub-projects of [project].
  List<Project> childrenOf(Project project) {
    if (project.id == null) return const [];
    return [for (final p in _projects) if (p.parentId == project.id) p];
  }

  /// Every project [project] could legally become the parent of
  /// itself under — i.e. every active project except itself and any
  /// of its own descendants, which would otherwise create a cycle.
  List<Project> eligibleParents(Project? project) {
    if (project?.id == null) return _projects;
    final excluded = <int>{project!.id!};
    var frontier = <int>{project.id!};
    while (frontier.isNotEmpty) {
      final next = <int>{};
      for (final p in _projects) {
        if (p.parentId != null &&
            frontier.contains(p.parentId) &&
            p.id != null &&
            !excluded.contains(p.id)) {
          excluded.add(p.id!);
          next.add(p.id!);
        }
      }
      frontier = next;
    }
    return [for (final p in _projects) if (!excluded.contains(p.id)) p];
  }

  /// [project] plus every descendant (children, grandchildren, ...) —
  /// a sub-project is, at the end of the day, just part of its
  /// parent's own work, so a parent's totals below fold all of this
  /// in rather than showing only what was logged directly on it.
  List<Project> _projectAndDescendants(Project project) {
    final result = <Project>[project];
    for (final child in childrenOf(project)) {
      result.addAll(_projectAndDescendants(child));
    }
    return result;
  }

  /// Total tracked time for a project, including the live elapsed
  /// time of its currently-running entry (if any), and rolled up to
  /// include every sub-project's time as well (see
  /// [_projectAndDescendants]) — a child's own [totalDurationFor] is
  /// still just its own tree, so this is safe to show side-by-side on
  /// a parent/child list without double-counting anything on screen.
  Duration totalDurationFor(Project project) {
    var total = Duration.zero;
    for (final p in _projectAndDescendants(project)) {
      for (final e in _entriesByProject[p.id] ?? const []) {
        total += e.duration;
      }
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
      _repo.fetchAllProjectTasks(),
      _repo.fetchStandaloneTasks(),
      _repo.fetchCategories(),
      _repo.fetchTags(),
      _repo.fetchAllEntryTags(),
    ]);
    _projects = results[0] as List<Project>;
    _entriesByProject = results[1] as Map<int, List<TimeEntry>>;
    _activeEntry = results[2] as TimeEntry?;
    _tasksByProject = results[3] as Map<int, List<Task>>;
    _standaloneTasks = results[4] as List<Task>;
    _categories = results[5] as List<ProjectCategory>;
    _tags = results[6] as List<SessionTag>;
    _entryTagIds = results[7] as Map<int, List<int>>;

    _syncTicker();
    _loading = false;
    notifyListeners();
    unawaited(_updateSessionNotification());
  }

  Future<void> addProject(Project project) async {
    await _repo.createProject(project);
    await load();
  }

  Future<void> updateProject(Project project) async {
    await _repo.updateProject(project);
    await load();
  }

  /// Convenience for a quick status change (e.g. tapping a status
  /// chip) without needing a full [Project.copyWith] at the call site.
  Future<void> setStatus(Project project, ProjectStatus status) async {
    await updateProject(project.copyWith(status: status));
  }

  /// Reparents [project] under [newParent] (or clears it back to
  /// top-level, passing null) — the same change available from the
  /// add/edit screen's "Parent project" field, exposed here for the
  /// Projects list's "Move to parent" shortcut so re-nesting an
  /// existing project doesn't require opening its edit screen.
  Future<void> setParent(Project project, Project? newParent) async {
    await updateProject(project.copyWith(
      parentId: newParent?.id,
      clearParentId: newParent == null,
    ));
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

  /// Archived projects — not part of the normal cached [projects] list
  /// (which only ever holds active ones), fetched fresh each time the
  /// Archived screen opens.
  Future<List<Project>> fetchArchivedProjects() => _repo.fetchArchivedProjects();

  /// Restores an archived project to active. Refreshes the normal
  /// (active-only) [projects] list; the caller is responsible for
  /// refreshing its own archived list afterward.
  Future<void> unarchiveProject(Project project) async {
    if (project.id == null) return;
    await _repo.archiveProject(project.id!, archived: false);
    await load();
  }

  // ---- Project categories (user-managed types) --------------------------

  Future<void> addCategory(String name, IconData icon) async {
    if (name.trim().isEmpty) return;
    await _repo.createCategory(name.trim(), icon);
    await _refreshCategories();
  }

  Future<void> updateCategory(
    ProjectCategory category, {
    required String name,
    required IconData icon,
  }) async {
    if (category.id == null || name.trim().isEmpty) return;
    await _repo.updateCategory(category.id!, name: name.trim(), icon: icon);
    await _refreshCategories();
  }

  Future<void> deleteCategory(ProjectCategory category) async {
    if (category.id == null) return;
    await _repo.deleteCategory(category.id!);
    // Deleting a category clears it off any project that had it, so
    // the projects list itself needs a refresh too, not just categories.
    await load();
  }

  Future<void> _refreshCategories() async {
    _categories = await _repo.fetchCategories();
    notifyListeners();
  }

  // ---- Session tags (user-managed session journal labels) -------------

  Future<void> addTag(String name) async {
    if (name.trim().isEmpty) return;
    await _repo.createTag(name.trim());
    await _refreshTags();
  }

  Future<void> renameTag(SessionTag tag, String newName) async {
    if (tag.id == null || newName.trim().isEmpty) return;
    await _repo.renameTag(tag.id!, newName.trim());
    await _refreshTags();
  }

  Future<void> deleteTag(SessionTag tag) async {
    if (tag.id == null) return;
    await _repo.deleteTag(tag.id!);
    // Deleting a tag clears it off any session that had it, so the
    // per-entry tag map needs a refresh too, not just the tag list.
    await _refreshTags();
    await _refreshEntriesAndActive();
  }

  Future<void> _refreshTags() async {
    _tags = await _repo.fetchTags();
    notifyListeners();
  }

  /// Begins a brand-new running session for [project]. Ends whatever
  /// other session (running or paused) was open, if any. [targetMinutes]
  /// starts it as a countdown (e.g. 25 for a Pomodoro-style session);
  /// omit it for an open-ended count-up timer.
  Future<void> beginSession(Project project, {int? targetMinutes}) async {
    if (project.id == null) return;
    await NotificationService.instance.requestPermission();
    await _repo.beginSession(project.id!, targetMinutes: targetMinutes);
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
  /// Pass [duration] to override the recorded length (e.g. the timer
  /// was accidentally left running and the real working time was much
  /// shorter) — see [ProjectRepository.endSession] for exactly how
  /// that's applied. [note] and [tagIds] become the session's journal
  /// entry: what happened, and what it was about.
  Future<void> endActiveSession({
    Duration? duration,
    String? title,
    String? note,
    List<int> tagIds = const [],
  }) async {
    final active = _activeEntry;
    if (active?.id == null) return;
    await _repo.endSession(
      active!.id!,
      duration: duration,
      title: title,
      note: note,
      tagIds: tagIds,
    );
    await _refreshEntriesAndActive();
  }

  /// Logs a past session manually — a chosen start time plus a
  /// duration — for testing or backfilling work you forgot to time.
  Future<void> addManualEntry(
    Project project, {
    required DateTime startedAt,
    required Duration duration,
    String? title,
    String? note,
    List<int> tagIds = const [],
  }) async {
    if (project.id == null) return;
    await _repo.addManualEntry(
      projectId: project.id!,
      startedAt: startedAt,
      duration: duration,
      title: title,
      note: note,
      tagIds: tagIds,
    );
    await _refreshEntriesAndActive();
  }

  Future<void> deleteEntry(TimeEntry entry) async {
    if (entry.id == null) return;
    await _repo.deleteEntry(entry.id!);
    await _refreshEntriesAndActive();
  }

  /// Re-inserts an entry that was just deleted — pairs with a delete
  /// confirmation's "Undo" snackbar action. Pass the tag ids it had
  /// (e.g. from [tagsForEntry], captured before the delete) to restore
  /// those too, since deleting the entry also drops its tag links.
  Future<void> restoreEntry(TimeEntry entry, {List<int> tagIds = const []}) async {
    await _repo.restoreEntry(entry, tagIds: tagIds);
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
    await reorderProjectsList(updated);
  }

  /// Persists an explicit new project order (e.g. computed from a drag
  /// within the parent/child-grouped list, where display order isn't a
  /// simple index shuffle of [projects]). [newOrder] must contain every
  /// project in [projects], in the desired order.
  Future<void> reorderProjectsList(List<Project> newOrder) async {
    _projects = newOrder;
    notifyListeners();

    final ids = [for (final p in newOrder) if (p.id != null) p.id!];
    await _repo.reorderProjects(ids);
  }

  /// Updates an existing entry's start time, duration, note, and/or
  /// tags — e.g. fixing a mistyped manual entry or a timer session
  /// that ran longer than intended. Pass [tagIds] to also replace its
  /// tags; omit it to leave them as they were.
  Future<void> updateEntry(TimeEntry entry, {List<int>? tagIds}) async {
    if (entry.id == null) return;
    await _repo.updateEntry(entry, tagIds: tagIds);
    await _refreshEntriesAndActive();
  }

  // ---- Tasks (project checklist item, or a standalone to-do) ----------

  /// Adds a task. Pass [project] to add it to that project's
  /// checklist, or omit it for a standalone to-do. [dueDate] is only
  /// meaningful for a standalone to-do (a project checklist doesn't
  /// use it).
  Future<void> addTask(String name, {Project? project, DateTime? dueDate}) async {
    if (name.trim().isEmpty) return;
    if (project != null && project.id == null) return;
    await _repo.createTask(Task(
      projectId: project?.id,
      name: name.trim(),
      createdAt: DateTime.now(),
      dueDate: dueDate == null ? null : _dateOnly(dueDate),
    ));
    await _refreshTasks();
  }

  Future<void> toggleTask(Task task) async {
    if (task.id == null) return;
    await _repo.updateTask(task.copyWith(completed: !task.completed));
    await _refreshTasks();
  }

  /// Sets or clears (pass null) a task's due date.
  Future<void> setTaskDueDate(Task task, DateTime? dueDate) async {
    if (task.id == null) return;
    await _repo.updateTask(task.copyWith(
      dueDate: dueDate == null ? null : _dateOnly(dueDate),
      clearDueDate: dueDate == null,
    ));
    await _refreshTasks();
  }

  Future<void> renameTask(Task task, String newName) async {
    if (task.id == null || newName.trim().isEmpty) return;
    await _repo.updateTask(task.copyWith(name: newName.trim()));
    await _refreshTasks();
  }

  Future<void> deleteTask(Task task) async {
    if (task.id == null) return;
    await _repo.deleteTask(task.id!);
    await _refreshTasks();
  }

  Future<void> _refreshTasks() async {
    final results = await Future.wait([
      _repo.fetchAllProjectTasks(),
      _repo.fetchStandaloneTasks(),
    ]);
    _tasksByProject = results[0] as Map<int, List<Task>>;
    _standaloneTasks = results[1] as List<Task>;
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
    return _durationForInclusive(project, start, end);
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

  /// Same as [_durationFor], but rolled up over [project] and every
  /// descendant — the per-project counterpart to [totalDurationFor]'s
  /// own rollup. Only ever call this per-project (as every method
  /// below does): summing it across a whole family would double-count
  /// a child's time once under itself and again under its parent. For
  /// an app-wide total that stays double-count-safe, use
  /// [totalDurationForRange] / [dailyTotalsForMonth] instead, which
  /// deliberately sum the *non-rolled-up* [_durationFor].
  Duration _durationForInclusive(
    Project project,
    DateTime start,
    DateTime endExclusive,
  ) {
    var total = Duration.zero;
    for (final p in _projectAndDescendants(project)) {
      total += _durationFor(p, start, endExclusive);
    }
    return total;
  }

  /// Per-project tracked time within [start, endExclusive), each
  /// figure rolled up to include that project's own sub-projects (see
  /// [_durationForInclusive]) — do not sum the values of this map for
  /// an app-wide total, since a child's time is counted again under
  /// every ancestor; use [totalDurationForRange] for that instead.
  Map<Project, Duration> durationsForRange(
    DateTime start,
    DateTime endExclusive,
  ) {
    return {
      for (final project in _projects)
        project: _durationForInclusive(project, start, endExclusive),
    };
  }

  /// Total tracked time across every project within [start,
  /// endExclusive) — a plain per-project sum (not rolled up by
  /// family), so nesting projects under a parent never changes this
  /// app-wide figure.
  Duration totalDurationForRange(DateTime start, DateTime endExclusive) {
    var total = Duration.zero;
    for (final project in _projects) {
      total += _durationFor(project, start, endExclusive);
    }
    return total;
  }

  /// Tracked time for [project] on each of the last 7 days (today
  /// inclusive, oldest first) — a rolling window, not the calendar
  /// week, matching the "last 7 days" style used elsewhere. Powers the
  /// small weekly bar strip on a project's own detail page.
  List<Duration> last7DaysDurationsFor(Project project) {
    final today = _dateOnly(DateTime.now());
    return [
      for (var i = 6; i >= 0; i--)
        _durationForInclusive(
          project,
          today.subtract(Duration(days: i)),
          today.subtract(Duration(days: i - 1)),
        ),
    ];
  }

  /// This calendar month's tracked time for [project] so far, mirroring
  /// [weeklyDurationFor].
  Duration monthlyDurationFor(Project project) {
    final start = monthStart(DateTime.now());
    final end = DateTime.now().add(const Duration(days: 1));
    return _durationForInclusive(project, start, end);
  }

  /// Tracked time on each day of [month] (any date within the target
  /// month) for [project] — the building block for a Google-Fit-style
  /// monthly bubble chart. Keyed by date-only day.
  Map<DateTime, Duration> dailyDurationsForMonth(Project project, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return {
      for (var d = 0; d < daysInMonth; d++)
        start.add(Duration(days: d)): _durationForInclusive(
          project,
          start.add(Duration(days: d)),
          start.add(Duration(days: d + 1)),
        ),
    };
  }

  /// Tracked time for [project] on each day of [start, endExclusive) —
  /// a generalization of [dailyDurationsForMonth] that can span past a
  /// single calendar month's own boundaries. Used to fetch data for a
  /// monthly bubble chart's full calendar-week grid (which pads out to
  /// whole Monday–Sunday, or configured first-day-of-week, weeks), so
  /// its "Weekly totals" list can total a real full week instead of
  /// just whichever few of those days happen to land in this month.
  Map<DateTime, Duration> dailyDurationsForRange(
    Project project,
    DateTime start,
    DateTime endExclusive,
  ) {
    final days = endExclusive.difference(start).inDays;
    return {
      for (var d = 0; d < days; d++)
        start.add(Duration(days: d)): _durationForInclusive(
          project,
          start.add(Duration(days: d)),
          start.add(Duration(days: d + 1)),
        ),
    };
  }

  /// Per-project tracked time on each of the last 7 days (today
  /// inclusive, oldest first) — the building block for the stacked
  /// weekly chart in Insights > Projects.
  Map<Project, List<Duration>> last7DaysDurationsByProject() {
    return {for (final project in _projects) project: last7DaysDurationsFor(project)};
  }

  /// Total tracked time across every project on each day of [month] —
  /// the aggregate counterpart to [dailyDurationsForMonth], used by the
  /// Insights > Projects monthly bubble chart.
  Map<DateTime, Duration> dailyTotalsForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return {
      for (var d = 0; d < daysInMonth; d++)
        start.add(Duration(days: d)): totalDurationForRange(
          start.add(Duration(days: d)),
          start.add(Duration(days: d + 1)),
        ),
    };
  }

  Future<void> _refreshEntriesAndActive() async {
    final results = await Future.wait([
      _repo.fetchAllEntries(),
      _repo.fetchActiveEntry(),
      _repo.fetchAllEntryTags(),
    ]);
    _entriesByProject = results[0] as Map<int, List<TimeEntry>>;
    _activeEntry = results[1] as TimeEntry?;
    _entryTagIds = results[2] as Map<int, List<int>>;
    _syncTicker();
    notifyListeners();
    unawaited(_updateSessionNotification());
  }

  /// Shows/updates/cancels the ongoing "session in progress" system
  /// notification to match [_activeEntry] — a live minutes:seconds
  /// clock (driven by Android's own notification chronometer, not by
  /// this app reposting every second) while running, a frozen elapsed
  /// time while paused, and cancelled once nothing is active. Called
  /// after every mutation that can change the active session, so it's
  /// naturally idempotent: reposting the same state is harmless.
  /// Best-effort — a notification-plugin hiccup should never take down
  /// the app itself, so failures are swallowed.
  Future<void> _updateSessionNotification() async {
    try {
      final active = _activeEntry;
      if (active == null) {
        await NotificationService.instance.cancelSessionNotification();
        return;
      }
      Project? project;
      for (final p in _projects) {
        if (p.id == active.projectId) {
          project = p;
          break;
        }
      }
      final projectName = project?.name ?? '';
      await NotificationService.instance.init();
      final t = await currentAppLocalizations();
      if (active.isPaused) {
        final label = projectName.isEmpty
            ? formatDurationClock(active.duration)
            : '$projectName · ${formatDurationClock(active.duration)}';
        await NotificationService.instance.showSessionPaused(
          title: t.sessionPausedNotifTitle,
          body: label,
          channelName: t.sessionInProgressNotifTitle,
          channelDescription: t.sessionProgressChannelDescription,
        );
      } else {
        // The chronometer should read 00:00 at start time plus any
        // time already spent paused across earlier pause/resume
        // cycles — matches [TimeEntry.duration]'s own math for a
        // currently-running (not paused) entry.
        final baseEpochMillis = active.startedAt
            .add(Duration(seconds: active.pausedSeconds))
            .millisecondsSinceEpoch;
        await NotificationService.instance.showSessionRunning(
          title: t.sessionInProgressNotifTitle,
          body: projectName,
          baseEpochMillis: baseEpochMillis,
          channelName: t.sessionInProgressNotifTitle,
          channelDescription: t.sessionProgressChannelDescription,
        );
      }
    } catch (_) {
      // Best-effort, as above.
    }
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
