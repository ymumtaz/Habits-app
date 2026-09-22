import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../models/project.dart';

const _colorChoices = <Color>[
  Colors.indigo,
  Colors.teal,
  Colors.orange,
  Colors.pink,
  Colors.purple,
  Colors.green,
  Colors.blue,
  Colors.brown,
];

/// Create or edit a project. Pass [existing] to edit; omit to create new.
class AddEditProjectScreen extends StatefulWidget {
  final Project? existing;
  const AddEditProjectScreen({super.key, this.existing});

  @override
  State<AddEditProjectScreen> createState() => _AddEditProjectScreenState();
}

class _AddEditProjectScreenState extends State<AddEditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _goalHoursController;
  late bool _hasGoal;
  late Color _color;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController =
        TextEditingController(text: p?.description ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _hasGoal = p?.goalMinutesPerWeek != null;
    _goalHoursController = TextEditingController(
      text: p?.goalMinutesPerWeek != null
          ? (p!.goalMinutesPerWeek! / 60).toStringAsFixed(1)
          : '5',
    );
    _color = p?.color ?? _colorChoices.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _goalHoursController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProjectProvider>();
    final category = _categoryController.text.trim();
    final goalHours = double.tryParse(_goalHoursController.text);
    final goalMinutes =
        (_hasGoal && goalHours != null && goalHours > 0)
            ? (goalHours * 60).round()
            : null;

    final project = (widget.existing ??
            Project(name: '', createdAt: DateTime.now()))
        .copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      clearDescription: _descriptionController.text.trim().isEmpty,
      category: category.isEmpty ? null : category,
      clearCategory: category.isEmpty,
      goalMinutesPerWeek: goalMinutes,
      clearGoal: goalMinutes == null,
      color: _color,
    );

    if (_isEditing) {
      await provider.updateProject(project);
    } else {
      await provider.addProject(project);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit project' : 'New project')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Master\'s thesis',
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Tag / category (optional)',
                hintText: 'e.g. Coursework, Research, Personal',
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Weekly time goal'),
              subtitle: const Text('Track progress toward hours per week'),
              value: _hasGoal,
              onChanged: (v) => setState(() => _hasGoal = v),
            ),
            if (_hasGoal)
              TextFormField(
                controller: _goalHoursController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Hours per week',
                ),
                validator: (v) {
                  if (!_hasGoal) return null;
                  final n = double.tryParse(v ?? '');
                  return (n == null || n <= 0) ? 'Enter a number > 0' : null;
                },
              ),
            const SizedBox(height: 24),
            Text('Color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in _colorChoices)
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.toARGB32() == _color.toARGB32()
                              ? color
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(backgroundColor: color, radius: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Create project'),
            ),
          ],
        ),
      ),
    );
  }
}
