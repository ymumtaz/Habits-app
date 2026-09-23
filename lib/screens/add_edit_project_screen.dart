import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../models/project.dart';
import 'manage_categories_screen.dart';

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
  late TextEditingController _goalHoursController;
  late bool _hasGoal;
  late Color _color;
  int? _categoryId;
  late ProjectStatus _status;
  int? _parentId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController =
        TextEditingController(text: p?.description ?? '');
    _hasGoal = p?.goalMinutesPerWeek != null;
    _goalHoursController = TextEditingController(
      text: p?.goalMinutesPerWeek != null
          ? (p!.goalMinutesPerWeek! / 60).toStringAsFixed(1)
          : '5',
    );
    _color = p?.color ?? _colorChoices.first;
    _categoryId = p?.categoryId;
    _status = p?.status ?? ProjectStatus.ongoing;
    _parentId = p?.parentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _goalHoursController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProjectProvider>();
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
      categoryId: _categoryId,
      clearCategoryId: _categoryId == null,
      status: _status,
      parentId: _parentId,
      clearParentId: _parentId == null,
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
    final provider = context.watch<ProjectProvider>();
    final categories = provider.categories;
    // A category the project was tagged with, but that's since been
    // deleted, shouldn't still show as selected in the dropdown.
    if (_categoryId != null && categories.every((c) => c.id != _categoryId)) {
      _categoryId = null;
    }
    final eligibleParents = provider.eligibleParents(widget.existing);
    if (_parentId != null && eligibleParents.every((p) => p.id != _parentId)) {
      _parentId = null;
    }

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _categoryId,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      for (final category in categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Manage categories',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManageCategoriesScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Status', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ProjectStatus>(
              segments: const [
                ButtonSegment(
                    value: ProjectStatus.ongoing, label: Text('Ongoing')),
                ButtonSegment(
                    value: ProjectStatus.onHold, label: Text('On hold')),
                ButtonSegment(
                    value: ProjectStatus.completed, label: Text('Completed')),
              ],
              selected: {_status},
              onSelectionChanged: (selected) =>
                  setState(() => _status = selected.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              value: _parentId,
              decoration: const InputDecoration(
                labelText: 'Parent project (optional)',
                helperText: 'Nest this under another project, e.g. a '
                    'chapter under a thesis',
                helperMaxLines: 2,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final p in eligibleParents)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _parentId = v),
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
                          color: color.value == _color.value
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
