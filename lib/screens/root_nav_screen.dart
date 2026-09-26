import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/project.dart';
import '../services/recap_scheduler.dart';
import '../utils/duration_format.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'projects_screen.dart';

/// The app shell: bottom navigation between Habits, Projects, and
/// Insights. Uses IndexedStack so switching tabs doesn't rebuild/lose
/// the scroll position of the tab you're leaving.
///
/// Also owns two app-wide, lifecycle-driven behaviors that don't
/// belong to any single tab:
/// - Idle detection: if a project timer was left running while the
///   app sat in the background for a while, offers to trim that away
///   time off the recorded session on return.
/// - Recap notifications: (re)schedules the daily/weekly recap with
///   fresh text once habits have finished loading on startup.
class RootNavScreen extends StatefulWidget {
  const RootNavScreen({super.key});

  @override
  State<RootNavScreen> createState() => _RootNavScreenState();
}

class _RootNavScreenState extends State<RootNavScreen>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    ProjectsScreen(),
    InsightsScreen(),
  ];

  /// How long the app can sit in the background with a timer running
  /// before we ask whether that time should count.
  static const _idleThreshold = Duration(minutes: 15);

  DateTime? _pausedAt;
  bool _scheduledRecaps = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeScheduleRecaps());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _maybeScheduleRecaps() {
    if (_scheduledRecaps || !mounted) return;
    _scheduledRecaps = true;
    // Fire-and-forget: notification scheduling shouldn't block the UI,
    // and failures here (e.g. permission not yet granted) are harmless
    // — the user can re-trigger scheduling from Settings.
    rescheduleRecaps(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt == null) return;
      final away = DateTime.now().difference(pausedAt);
      if (away < _idleThreshold) return;

      final projects = context.read<ProjectProvider>();
      final active = projects.activeEntry;
      if (active == null || !active.isRunning) return;

      Project? project;
      for (final p in projects.projects) {
        if (p.id == active.projectId) {
          project = p;
          break;
        }
      }
      if (project == null) return;

      // Defer until the frame after resume so the app is fully back in
      // the foreground before showing a dialog.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showIdleDialog(away, projects, project!.name);
      });
    }
  }

  Future<void> _showIdleDialog(
    Duration away,
    ProjectProvider provider,
    String projectName,
  ) async {
    final t = context.l10n;
    final awayLabel = formatDurationCoarse(away, t);
    final trim = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.stillWorkingTitle),
        content: Text(t.idleDialogMessage(projectName, awayLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.keepIt),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.trimLabel(awayLabel)),
          ),
        ],
      ),
    );
    if (trim == true) {
      await provider.trimIdleTime(away);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.local_fire_department_outlined),
            selectedIcon: const Icon(Icons.local_fire_department),
            label: context.l10n.navHabits,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: context.l10n.navProjects,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: context.l10n.navInsights,
          ),
        ],
      ),
    );
  }
}
