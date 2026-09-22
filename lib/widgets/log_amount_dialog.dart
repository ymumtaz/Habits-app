import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';

/// A dialog for logging (or clearing) a count/duration habit's amount
/// for a given day — e.g. "6 glasses" or "15 min". Returns the new
/// amount to save, `0` to explicitly clear the day, or null if
/// cancelled.
Future<int?> showLogAmountDialog(
  BuildContext context, {
  required Habit habit,
  required DateTime date,
  required int? currentAmount,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _LogAmountDialog(
      habit: habit,
      date: date,
      currentAmount: currentAmount,
    ),
  );
}

class _LogAmountDialog extends StatefulWidget {
  final Habit habit;
  final DateTime date;
  final int? currentAmount;

  const _LogAmountDialog({
    required this.habit,
    required this.date,
    required this.currentAmount,
  });

  @override
  State<_LogAmountDialog> createState() => _LogAmountDialogState();
}

class _LogAmountDialogState extends State<_LogAmountDialog> {
  late final _controller =
      TextEditingController(text: '${widget.currentAmount ?? 0}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _adjust(int delta) {
    final current = int.tryParse(_controller.text) ?? 0;
    final next = (current + delta).clamp(0, 100000);
    setState(() => _controller.text = '$next');
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final target = habit.dailyTarget;
    final isToday =
        HabitLog.dayOnly(widget.date) == HabitLog.dayOnly(DateTime.now());
    final dateLabel =
        isToday ? 'today' : DateFormat('EEE, MMM d').format(widget.date);

    return AlertDialog(
      title: Text('${habit.name} — $dateLabel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (target != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Target: $target ${habit.unitLabel}'),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _adjust(-1),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: InputDecoration(suffixText: habit.unitLabel),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _adjust(1),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(0),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(int.tryParse(_controller.text) ?? 0),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
