import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../data/settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/project.dart';

/// What [showStartSessionDialog] returns: which project, and whether
/// to start as a countdown (with a target length) or an open-ended
/// count-up timer.
class StartSessionChoice {
  final Project project;

  /// Null means an open-ended (count-up) timer, like the app's
  /// original single-timer behavior.
  final int? targetMinutes;

  const StartSessionChoice({required this.project, this.targetMinutes});
}

/// The one place a session gets started, whichever screen it's opened
/// from — replaces separate play/pause/stop controls scattered across
/// every project card. Lets you pick the project (defaulting to
/// [initialProject] if given) and choose between a countdown (starts
/// at the "Default session length" set in Settings, adjustable per
/// session) or the old open-ended timer.
Future<StartSessionChoice?> showStartSessionDialog(
  BuildContext context, {
  required List<Project> projects,
  Project? initialProject,
}) {
  return showDialog<StartSessionChoice>(
    context: context,
    builder: (context) => _StartSessionDialog(
      projects: projects,
      initialProject: initialProject,
    ),
  );
}

class _StartSessionDialog extends StatefulWidget {
  final List<Project> projects;
  final Project? initialProject;

  const _StartSessionDialog({required this.projects, this.initialProject});

  @override
  State<_StartSessionDialog> createState() => _StartSessionDialogState();
}

class _StartSessionDialogState extends State<_StartSessionDialog> {
  Project? _project;
  bool _countdown = true;
  int _minutes = 25;

  @override
  void initState() {
    super.initState();
    _project = widget.initialProject ??
        (widget.projects.isNotEmpty ? widget.projects.first : null);
    _minutes = context.read<SettingsProvider>().defaultCountdownMinutes;
  }

  void _adjustMinutes(int delta) {
    setState(() => _minutes = (_minutes + delta).clamp(1, 480).toInt());
  }

  @override
  Widget build(BuildContext context) {
    final ordered = orderProjectsWithDepth(widget.projects);
    final t = context.l10n;

    return AlertDialog(
      title: Text(t.startASessionTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<Project>(
              value: _project,
              isExpanded: true,
              decoration: InputDecoration(labelText: t.projectDropdownLabel),
              items: [
                for (final (project, depth) in ordered)
                  DropdownMenuItem(
                    value: project,
                    child: Text(
                      '${'   ' * depth}${project.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (p) => setState(() => _project = p),
            ),
            const SizedBox(height: 20),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(t.countdownOption)),
                ButtonSegment(value: false, label: Text(t.openTimerOption)),
              ],
              selected: {_countdown},
              onSelectionChanged: (s) => setState(() => _countdown = s.first),
            ),
            if (_countdown) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => _adjustMinutes(-5),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      t.minutesValue(_minutes),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _adjustMinutes(5),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                t.openTimerExplainer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: _project == null
              ? null
              : () => Navigator.of(context).pop(
                    StartSessionChoice(
                      project: _project!,
                      targetMinutes: _countdown ? _minutes : null,
                    ),
                  ),
          child: Text(t.start),
        ),
      ],
    );
  }
}
