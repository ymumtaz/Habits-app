import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/time_entry.dart';
import 'tag_picker.dart';

/// Result of the manual-entry dialog: when the session started, how
/// long it lasted, an optional journal note, and its tags.
class ManualEntryResult {
  final DateTime startedAt;
  final Duration duration;
  final String title;
  final String? note;
  final List<int> tagIds;
  const ManualEntryResult({
    required this.startedAt,
    required this.duration,
    required this.title,
    this.note,
    this.tagIds = const [],
  });
}

/// A dialog for logging a past project session by hand — a date/time,
/// a duration, a note, and tags — instead of running the live timer.
/// Useful for backfilling work done before you started using the app.
/// Pass [existing] to edit an already-logged session instead of
/// creating a new one (its start time, duration, and note are
/// prefilled); pass its current tags as [existingTagIds] to prefill
/// those too.
///
/// Returns a [ManualEntryResult], or null if cancelled.
Future<ManualEntryResult?> showAddManualEntryDialog(
  BuildContext context, {
  TimeEntry? existing,
  List<int> existingTagIds = const [],
}) {
  return showDialog<ManualEntryResult>(
    context: context,
    builder: (context) => _AddManualEntryDialog(
      existing: existing,
      existingTagIds: existingTagIds,
    ),
  );
}

class _AddManualEntryDialog extends StatefulWidget {
  final TimeEntry? existing;
  final List<int> existingTagIds;
  const _AddManualEntryDialog({this.existing, this.existingTagIds = const []});

  @override
  State<_AddManualEntryDialog> createState() => _AddManualEntryDialogState();
}

class _AddManualEntryDialogState extends State<_AddManualEntryDialog> {
  late DateTime _date;
  late TimeOfDay _time;
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late Set<int> _selectedTagIds;
  String? _titleError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final startedAt = existing?.startedAt ?? DateTime.now();
    _date = startedAt;
    _time = TimeOfDay.fromDateTime(startedAt);
    final duration = existing?.duration ?? const Duration(minutes: 30);
    _hoursController = TextEditingController(text: '${duration.inHours}');
    _minutesController =
        TextEditingController(text: '${duration.inMinutes % 60}');
    _titleController = TextEditingController(text: existing?.title ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _selectedTagIds = {...widget.existingTagIds};
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
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

    final startedAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final note = _noteController.text.trim();
    Navigator.of(context).pop(ManualEntryResult(
      startedAt: startedAt,
      duration: duration,
      title: title,
      note: note.isEmpty ? null : note,
      tagIds: _selectedTagIds.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final dateLabel = DateFormat('EEE, MMM d yyyy', t.locale.languageCode).format(_date);
    final timeLabel = _time.format(context);

    return AlertDialog(
      title: Text(_isEditing ? t.editSessionTitle : t.addAPastSessionTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(dateLabel),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(t.startedAtLabel(timeLabel)),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
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
            const SizedBox(height: 12),
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
          child: Text(_isEditing ? t.saveChanges : t.add),
        ),
      ],
    );
  }
}
