import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../data/settings_provider.dart';
import '../models/habit.dart';

const _iconChoices = <IconData>[
  Icons.fitness_center,
  Icons.local_drink,
  Icons.menu_book,
  Icons.phone_iphone,
  Icons.bedtime,
  Icons.self_improvement,
  Icons.directions_run,
  Icons.check_circle_outline,
];

const _colorChoices = <Color>[
  Colors.teal,
  Colors.indigo,
  Colors.orange,
  Colors.pink,
  Colors.purple,
  Colors.green,
  Colors.blue,
  Colors.brown,
];

/// Create or edit a habit. Pass [existing] to edit; omit to create new.
class AddEditHabitScreen extends StatefulWidget {
  final Habit? existing;
  const AddEditHabitScreen({super.key, this.existing});

  @override
  State<AddEditHabitScreen> createState() => _AddEditHabitScreenState();
}

class _AddEditHabitScreenState extends State<AddEditHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _dailyTargetController;
  late HabitFrequency _frequency;
  late int _targetPerWeek;
  late HabitType _type;
  late int _tolerancePerMonth;
  late Color _color;
  late IconData _icon;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final h = widget.existing;
    _nameController = TextEditingController(text: h?.name ?? '');
    _descriptionController =
        TextEditingController(text: h?.description ?? '');
    _dailyTargetController =
        TextEditingController(text: '${h?.dailyTarget ?? 8}');
    _frequency = h?.frequency ??
        context.read<SettingsProvider>().defaultHabitFrequency;
    _targetPerWeek = h?.targetPerWeek ?? 3;
    _type = h?.type ?? HabitType.boolean;
    _tolerancePerMonth = h?.tolerancePerMonth ?? 0;
    _color = h?.color ?? _colorChoices.first;
    _icon = h?.icon ?? _iconChoices.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dailyTargetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<HabitProvider>();
    final needsTarget = _type != HabitType.boolean;
    final habit = (widget.existing ??
            Habit(name: '', createdAt: DateTime.now()))
        .copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      frequency: _frequency,
      targetPerWeek: _frequency == HabitFrequency.daily ? 7 : _targetPerWeek,
      type: _type,
      dailyTarget:
          needsTarget ? (int.tryParse(_dailyTargetController.text) ?? 1) : null,
      clearDailyTarget: !needsTarget,
      tolerancePerMonth: _tolerancePerMonth,
      color: _color,
      icon: _icon,
    );

    if (_isEditing) {
      await provider.updateHabit(habit);
    } else {
      await provider.addHabit(habit);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit habit' : 'New habit')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Go to the gym',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Text('Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<HabitType>(
              segments: const [
                ButtonSegment(value: HabitType.boolean, label: Text('Done/not')),
                ButtonSegment(value: HabitType.count, label: Text('Count')),
                ButtonSegment(value: HabitType.duration, label: Text('Duration')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            if (_type != HabitType.boolean) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _dailyTargetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _type == HabitType.count
                      ? 'Daily target (e.g. glasses)'
                      : 'Daily target (minutes)',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n <= 0) ? 'Enter a number > 0' : null;
                },
              ),
            ],
            const SizedBox(height: 24),
            Text('Frequency', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<HabitFrequency>(
              segments: const [
                ButtonSegment(
                  value: HabitFrequency.daily,
                  label: Text('Daily'),
                ),
                ButtonSegment(
                  value: HabitFrequency.weekly,
                  label: Text('X times / week'),
                ),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) =>
                  setState(() => _frequency = s.first),
            ),
            if (_frequency == HabitFrequency.weekly) ...[
              const SizedBox(height: 16),
              Text('Target per week',
                  style: Theme.of(context).textTheme.titleSmall),
              Slider(
                value: _targetPerWeek.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                label: '$_targetPerWeek',
                onChanged: (v) =>
                    setState(() => _targetPerWeek = v.round()),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Tolerance: allow $_tolerancePerMonth missed '
              'day${_tolerancePerMonth == 1 ? '' : 's'}/month',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              _frequency == HabitFrequency.daily
                  ? 'A tolerated miss doesn\'t break your streak — like a '
                      'built-in streak freeze that resets each calendar '
                      'month.'
                  : 'If a week falls short of target, the shortfall '
                      '(days short of target) is covered by this budget '
                      'instead of breaking your streak — resets each '
                      'calendar month.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Slider(
              value: _tolerancePerMonth.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              label: '$_tolerancePerMonth',
              onChanged: (v) =>
                  setState(() => _tolerancePerMonth = v.round()),
            ),
            const SizedBox(height: 24),
            Text('Icon', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final icon in _iconChoices)
                  _PickerChip(
                    selected: icon == _icon,
                    color: _color,
                    child: Icon(icon),
                    onTap: () => setState(() => _icon = icon),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in _colorChoices)
                  _PickerChip(
                    selected: color.toARGB32() == _color.toARGB32(),
                    color: color,
                    child: CircleAvatar(backgroundColor: color, radius: 12),
                    onTap: () => setState(() => _color = color),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Create habit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  final bool selected;
  final Color color;
  final Widget child;
  final VoidCallback onTap;

  const _PickerChip({
    required this.selected,
    required this.color,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }
}
