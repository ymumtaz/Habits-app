import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/time_entry.dart';
import 'tag_picker.dart';

/// What [showEndSessionDialog] returns: the session's final duration
/// (editable — see the dialog itself), a journal note, and its tags.
class EndSessionResult {
  final Duration duration;
  final String title;
  final String? note;
  final List<int> tagIds;

  const EndSessionResult({
    required this.duration,
    required this.title,
    this.note,
    required this.tagIds,
  });
}

/// The one place a session gets ended, whichever screen it's started
/// from. Replaces a single instant "stop" tap — which made it too easy
/// to end (and permanently record) a session seconds after starting it
/// by accident — with a short confirmation step: review and, if
/// needed, correct the duration (e.g. you forgot to end it earlier and
/// the real working time was much shorter than the elapsed wall-clock
/// time), then jot down how it went and tag what it was about, the way
/// you'd log a gym session.
///
/// Returns null if cancelled, leaving the session running/paused as it
/// was.
Future<EndSessionResult?> showEndSessionDialog(
  BuildContext context, {
  required TimeEntry activeEntry,
}) {
  return showDialog<EndSessionResult>(
    context: context,
    builder: (context) => _EndSessionDialog(activeEntry: activeEntry),
  );
}

class _EndSessionDialog extends StatefulWidget {
  final TimeEntry activeEntry;
  const _EndSessionDialog({required this.activeEntry});

  @override
  State<_EndSessionDialog> createState() => _EndSessionDialogState();
}

class _EndSessionDialogState extends State<_EndSessionDialog> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late Set<int> _selectedTagIds;
  String? _titleError;

  /// Captured once, when the dialog opens — a short elapsed time at
  /// that moment is worth flagging, but shouldn't keep flagging (or
  /// stop flagging) as the user edits the duration fields below.
  late final bool _wasVeryShort;

  @override
  void initState() {
    super.initState();
    final duration = widget.activeEntry.duration;
    _wasVeryShort = duration.inSeconds < 60;
    _hoursController = TextEditingController(text: '${duration.inHours}');
    _minutesController =
        TextEditingController(text: '${duration.inMinutes % 60}');
    _titleController = TextEditingController(text: widget.activeEntry.title ?? '');
    _noteController = TextEditingController(text: widget.activeEntry.note ?? '');
    _selectedTagIds = {};
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final duration = Duration(hours: hours, minutes: minutes);

    if (duration <= Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.durationMustBeMoreThanZero)),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = context.l10n.giveItAName);
      return;
    }

    final note = _noteController.text.trim();
    Navigator.of(context).pop(EndSessionResult(
      duration: duration,
      title: title,
      note: note.isEmpty ? null : note,
      tagIds: _selectedTagIds.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return AlertDialog(
      title: Text(t.endSessionTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: t.sessionTitleLabel,
                hintText: t.sessionTitleHint,
                errorText: _titleError,
              ),
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hoursController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: t.hoursLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: t.minutesLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _wasVeryShort ? t.wasVeryShortWarning : t.forgotToEndWarning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _wasVeryShort
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: t.notesOptionalLabel,
                hintText: t.sessionNoteHint,
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            TagPicker(
              selectedTagIds: _selectedTagIds,
              onChanged: (ids) => setState(() => _selectedTagIds = ids),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(t.record),
        ),
      ],
    );
  }
}
