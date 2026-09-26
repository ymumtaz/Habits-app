import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/session_tag.dart';
import '../widgets/confirm_dialog.dart';

/// Add, rename, or delete the tags available when ending a session or
/// logging/editing a past one — e.g. "Physics", "Coding", "Literature
/// review". Deleting one just clears it off any session that had it;
/// nothing else about those sessions is touched.
class ManageSessionTagsScreen extends StatefulWidget {
  const ManageSessionTagsScreen({super.key});

  @override
  State<ManageSessionTagsScreen> createState() =>
      _ManageSessionTagsScreenState();
}

class _ManageSessionTagsScreenState extends State<ManageSessionTagsScreen> {
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
    await context.read<ProjectProvider>().addTag(name);
  }

  Future<void> _rename(SessionTag tag) async {
    final t = context.l10n;
    final controller = TextEditingController(text: tag.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.renameTagTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: t.name),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == tag.name) return;
    if (mounted) {
      await context.read<ProjectProvider>().renameTag(tag, newName);
    }
  }

  Future<void> _delete(SessionTag tag) async {
    final t = context.l10n;
    final confirmed = await confirmDelete(
      context,
      title: t.deleteTagTitle(tag.name),
      message: t.deleteTagMessage(tag.name),
    );
    if (!confirmed) return;
    if (mounted) {
      await context.read<ProjectProvider>().deleteTag(tag);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = context.watch<ProjectProvider>().tags;
    final t = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(t.sessionTagsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(t.noTagsYet),
            )
          else
            for (final tag in tags)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('#${tag.name}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: t.renameTooltip,
                        onPressed: () => _rename(tag),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: t.delete,
                        onPressed: () => _delete(tag),
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
                  decoration: InputDecoration(
                    hintText: t.newTagExampleHint,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: t.addTagTooltip,
                onPressed: _add,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
