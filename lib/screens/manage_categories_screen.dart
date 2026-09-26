import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/project_category.dart';
import '../widgets/confirm_dialog.dart';

/// Add, rename, re-icon, or delete the project types (categories)
/// available when creating or editing a project — e.g. "Course",
/// "Research", "Side project". Each one carries an icon (picked from
/// a wide set) that a project tagged with it shows as its own avatar.
/// Deleting a category just clears it off any project that had it;
/// nothing else about those projects is touched.
class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  Future<void> _add() async {
    final t = context.l10n;
    final result = await _showCategoryDialog(
      title: t.newCategoryTitle,
      initialName: '',
      initialIcon: categoryIconChoices.first,
      saveLabel: t.add,
    );
    if (result == null) return;
    if (mounted) {
      await context
          .read<ProjectProvider>()
          .addCategory(result.name, result.icon);
    }
  }

  Future<void> _edit(ProjectCategory category) async {
    final t = context.l10n;
    final result = await _showCategoryDialog(
      title: t.editCategoryTitle,
      initialName: category.name,
      initialIcon: category.icon,
      saveLabel: t.save,
    );
    if (result == null) return;
    if (result.name == category.name && result.icon == category.icon) return;
    if (mounted) {
      await context.read<ProjectProvider>().updateCategory(
            category,
            name: result.name,
            icon: result.icon,
          );
    }
  }

  Future<_CategoryEdit?> _showCategoryDialog({
    required String title,
    required String initialName,
    required IconData initialIcon,
    required String saveLabel,
  }) {
    final controller = TextEditingController(text: initialName);
    var selectedIcon = initialIcon;
    return showDialog<_CategoryEdit>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(labelText: context.l10n.name),
                  ),
                  const SizedBox(height: 16),
                  Text(context.l10n.iconLabel, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final icon in categoryIconChoices)
                        InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () =>
                              setDialogState(() => selectedIcon = icon),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: icon == selectedIcon
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : null,
                              border: Border.all(
                                color: icon == selectedIcon
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: icon == selectedIcon
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.of(context)
                    .pop(_CategoryEdit(name, selectedIcon));
              },
              child: Text(saveLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(ProjectCategory category) async {
    final t = context.l10n;
    final confirmed = await confirmDelete(
      context,
      title: t.deleteCategoryTitle(category.name),
      message: t.deleteCategoryMessage(category.name),
    );
    if (!confirmed) return;
    if (mounted) {
      await context.read<ProjectProvider>().deleteCategory(category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ProjectProvider>().categories;
    final t = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(t.projectCategoriesTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(t.noCategoriesYet),
            )
          else
            for (final category in categories)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(category.icon)),
                  title: Text(category.name),
                  onTap: () => _edit(category),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: t.delete,
                    onPressed: () => _delete(category),
                  ),
                ),
              ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: Text(t.addCategory),
          ),
        ],
      ),
    );
  }
}

class _CategoryEdit {
  final String name;
  final IconData icon;
  const _CategoryEdit(this.name, this.icon);
}
