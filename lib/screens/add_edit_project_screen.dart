import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../l10n/app_localizations.dart';
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

/// A lightened version of [parentColor] — the default color a new
/// sub-project starts with, so a project family tends to look related
/// by color (on top of the grouped-card and collapsible-parent
/// treatments) rather than every project picking an unrelated color
/// independently. Still just a starting point: picking a swatch below
/// overrides it as usual.
Color childTint(Color parentColor) => Color.lerp(parentColor, Colors.white, 0.35)!;

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

  /// True once the user has explicitly picked a color swatch this
  /// session — after that, choosing/changing a parent no longer
  /// auto-suggests a tint, since they've already made their own call.
  bool _colorTouched = false;

  bool get _isEditing => widget.existing != null;

  /// A tint of the currently-chosen parent's color, if any — kept as a
  /// standing suggestion (see the color [Wrap] in [build]) rather than
  /// something that disappears the moment another swatch is tapped.
  Color? _suggestedColor;

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
    _suggestedColor = _parentId == null
        ? null
        : childTint(eligibleParents
            .firstWhere((p) => p.id == _parentId,
                orElse: () => eligibleParents.first)
            .color);
    final t = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? t.editProjectTitle : t.newProjectTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t.projectNameLabel,
                hintText: t.projectNameHint,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? t.giveItAName : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: t.notesOptionalLabel,
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
                    decoration: InputDecoration(labelText: t.typeDropdownLabel),
                    items: [
                      DropdownMenuItem(value: null, child: Text(t.none)),
                      for (final category in categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(category.icon, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  category.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: t.manageCategoriesTooltip,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManageCategoriesScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(t.statusLabel, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ProjectStatus>(
              segments: [
                ButtonSegment(
                    value: ProjectStatus.ongoing, label: Text(t.statusOngoing)),
                ButtonSegment(
                    value: ProjectStatus.onHold, label: Text(t.statusOnHold)),
                ButtonSegment(
                    value: ProjectStatus.completed, label: Text(t.statusCompleted)),
              ],
              selected: {_status},
              onSelectionChanged: (selected) =>
                  setState(() => _status = selected.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              value: _parentId,
              decoration: InputDecoration(
                labelText: t.parentProjectOptionalLabel,
                helperText: t.parentProjectHelper,
                helperMaxLines: 2,
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(t.none)),
                for (final p in eligibleParents)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() {
                _parentId = v;
                // New (not yet customized) sub-project: default its
                // color to a tint of its new parent's, so the family
                // reads as related. Skipped once the user has picked
                // their own swatch, or when editing an existing
                // project (nesting it shouldn't silently recolor it).
                if (!_isEditing && !_colorTouched && v != null) {
                  final parent = eligibleParents.firstWhere(
                    (p) => p.id == v,
                    orElse: () => eligibleParents.first,
                  );
                  _color = childTint(parent.color);
                }
              }),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.weeklyTimeGoal),
              subtitle: Text(t.weeklyTimeGoalSubtitle),
              value: _hasGoal,
              onChanged: (v) => setState(() => _hasGoal = v),
            ),
            if (_hasGoal)
              TextFormField(
                controller: _goalHoursController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: InputDecoration(
                  labelText: t.hoursPerWeek,
                ),
                validator: (v) {
                  if (!_hasGoal) return null;
                  final n = double.tryParse(v ?? '');
                  return (n == null || n <= 0) ? t.enterNumberGreaterThanZeroDecimal : null;
                },
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(t.colorLabel, style: Theme.of(context).textTheme.titleSmall),
                if (_suggestedColor != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.suggestedFromParent,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // The parent-tint suggestion is always available as its
                // own swatch (marked with a small star) for as long as a
                // parent is set — tapping any other swatch by mistake no
                // longer loses it, since it isn't hidden once "touched"
                // the way earlier versions of this screen worked.
                if (_suggestedColor != null)
                  _ColorSwatch(
                    color: _suggestedColor!,
                    selected: _color.value == _suggestedColor!.value,
                    suggested: true,
                    onTap: () => setState(() {
                      _color = _suggestedColor!;
                      _colorTouched = true;
                    }),
                  ),
                for (final color in _colorChoices)
                  _ColorSwatch(
                    color: color,
                    selected: _color.value == color.value,
                    onTap: () => setState(() {
                      _color = color;
                      _colorTouched = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? t.saveChanges : t.createProject),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable circle in the color picker. [suggested] draws a small
/// star badge in the corner to mark the parent-tint suggestion so it
/// stays recognizable alongside the fixed palette.
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.suggested = false,
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(backgroundColor: color, radius: 12),
            if (suggested)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.star,
                    size: 10,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
