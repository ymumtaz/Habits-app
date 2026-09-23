import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../models/project_category.dart';
import '../widgets/confirm_dialog.dart';

/// Add, rename, or delete the project types (categories) available
/// when creating or editing a project — e.g. "Course", "Research",
/// "Side project". Deleting one just clears it off any project that
/// had it; nothing else about those projects is touched.
class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    _controller.clear();
    await context.read<ProjectProvider>().addCategory(name);
  }

  Future<void> _rename(ProjectCategory category) async {
    final controller = TextEditingController(text: category.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == category.name) return;
    if (mounted) {
      await context.read<ProjectProvider>().renameCategory(category, newName);
    }
  }

  Future<void> _delete(ProjectCategory category) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete "${category.name}"?',
      message: 'Any project tagged "${category.name}" will just lose that '
          'tag — nothing else about them changes.',
    );
    if (!confirmed) return;
    if (mounted) {
      await context.read<ProjectProvider>().deleteCategory(category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ProjectProvider>().categories;

    return Scaffold(
      appBar: AppBar(title: const Text('Project categories')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No categories yet — add one below.'),
            )
          else
            for (final category in categories)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(category.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Rename',
                        onPressed: () => _rename(category),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () => _delete(category),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'New category, e.g. Freelance',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add category',
                onPressed: _add,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
