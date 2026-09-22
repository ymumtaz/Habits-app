import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/time_entry.dart';

/// Result of the manual-entry dialog: when the session started, how
/// long it lasted, and an optional note.
class ManualEntryResult {
  final DateTime startedAt;
  final Duration duration;
  final String? note;
  const ManualEntryResult({
    required this.startedAt,
    required this.duration,
    this.note,
  });
}

/// A dialog for logging a past project session by hand — a date/time,
/// a duration, and an optional note — instead of running the live
/// timer. Useful for backfilling work done before you started using
/// the app. Pass [existing] to edit an already-logged session instead
/// of creating a new one (its start time, duration, and note are
/// prefilled).
///
/// Returns a [ManualEntryResult], or null if cancelled.
Future<ManualEntryResult?> showAddManualEntryDialog(
  BuildContext context, {
  TimeEntry? existing,
}) {
  return showDialog<ManualEntryResult>(
    context: context,
    builder: (context) => _AddManualEntryDialog(existing: existing),
  );
}

class _AddManualEntryDialog extends StatefulWidget {
  final TimeEntry? existing;
  const _AddManualEntryDialog({this.existing});

  @override
  State<_AddManualEntryDialog> createState() => _AddManualEntryDialogState();
}

class _AddManualEntryDialogState extends State<_AddManualEntryDialog> {
  late DateTime _date;
  late TimeOfDay _time;
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _noteController;

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
    _noteController = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
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
        const SnackBar(content: Text('Duration has to be more than 0.')),
      );
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
      note: note.isEmpty ? null : note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, MMM d yyyy').format(_date);
    final timeLabel = _time.format(context);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit session' : 'Add a past session'),
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
              title: Text('Started at $timeLabel'),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hoursController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Hours'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutes'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'What did you work on?',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save changes' : 'Add'),
        ),
      ],
    );
  }
}
