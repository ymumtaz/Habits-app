import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/habit_provider.dart';
import '../data/settings_provider.dart';
import '../models/habit.dart';

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

/// The daily target pre-filled when a brand-new habit switches to this
/// type — a reasonable starting point, not a hard rule. Only applied
/// when creating a new habit (never overwrites an existing one's saved
/// target just because you glanced at a different type while editing).
const _defaultCountTarget = 10;
const _defaultDurationTarget = 15;

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
  late TextEditingController _unitController;
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
    _type = h?.type ?? HabitType.boolean;
    _dailyTargetController = TextEditingController(
      text: '${h?.dailyTarget ?? _defaultTargetFor(_type)}',
    );
    _unitController = TextEditingController(text: h?.unit ?? '');
    _frequency = h?.frequency ??
        context.read<SettingsProvider>().defaultHabitFrequency;
    _targetPerWeek = h?.targetPerWeek ?? 3;
    _tolerancePerMonth = h?.tolerancePerMonth ?? 0;
    _color = h?.color ?? _colorChoices.first;
    _icon = h?.icon ?? habitIconChoices.first;
  }

  static int _defaultTargetFor(HabitType type) => switch (type) {
        HabitType.count => _defaultCountTarget,
        HabitType.duration => _defaultDurationTarget,
        HabitType.boolean => _defaultCountTarget,
      };

  String get _nameHint => switch (_type) {
        HabitType.boolean => 'e.g. Go to the gym',
        HabitType.count => 'e.g. Pages of book read',
        HabitType.duration => 'e.g. Meditate',
      };

  void _onTypeChanged(HabitType newType) {
    setState(() {
      // Only auto-fill the target for a brand-new habit — editing an
      // existing one should never silently overwrite its real saved
      // target just because you switched types to look around.
      if (!_isEditing && newType != _type) {
        _dailyTargetController.text = '${_defaultTargetFor(newType)}';
      }
      _type = newType;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dailyTargetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<HabitProvider>();
    final needsTarget = _type != HabitType.boolean;
    final unit = _unitController.text.trim();
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
      unit: (_type == HabitType.count && unit.isNotEmpty) ? unit : null,
      clearUnit: !(_type == HabitType.count && unit.isNotEmpty),
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
            // The title: the main thing you're naming, so it gets more
            // visual weight than the optional notes below it.
            TextFormField(
              controller: _nameController,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: _nameHint,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Give it a title' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              style: Theme.of(context).textTheme.bodyMedium,
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
              onSelectionChanged: (s) => _onTypeChanged(s.first),
            ),
            if (_type != HabitType.boolean) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _dailyTargetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _type == HabitType.count
                      ? 'Daily target (e.g. pages)'
                      : 'Daily target (minutes)',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n <= 0) ? 'Enter a number > 0' : null;
                },
              ),
            ],
            if (_type == HabitType.count) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit (optional)',
                  hintText: 'e.g. pages, glasses, reps',
                ),
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
                  label: Text('Weekly'),
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
                for (final icon in habitIconChoices)
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
                    selected: color.value == _color.value,
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
