import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/project_provider.dart';
import '../l10n/app_localizations.dart';

/// A row of selectable session-tag chips plus a small inline "add a
/// new tag" field — shared by anywhere a session's tags are edited
/// (ending a session, logging or editing a past one). Reads the
/// available tags live from [ProjectProvider] so a tag added here
/// shows up immediately without closing the dialog it's embedded in.
class TagPicker extends StatefulWidget {
  final Set<int> selectedTagIds;
  final ValueChanged<Set<int>> onChanged;

  const TagPicker({
    super.key,
    required this.selectedTagIds,
    required this.onChanged,
  });

  @override
  State<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPicker> {
  final _newTagController = TextEditingController();

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _addTag() async {
    final name = _newTagController.text.trim();
    if (name.isEmpty) return;
    _newTagController.clear();
    final provider = context.read<ProjectProvider>();
    await provider.addTag(name);
    final match = provider.tags.where((t) => t.name == name);
    if (match.isNotEmpty && match.first.id != null) {
      widget.onChanged({...widget.selectedTagIds, match.first.id!});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = context.watch<ProjectProvider>().tags;
    final t = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.tagsLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                FilterChip(
                  label: Text('#${tag.name}'),
                  selected: widget.selectedTagIds.contains(tag.id),
                  onSelected: (selected) {
                    final next = {...widget.selectedTagIds};
                    if (selected) {
                      next.add(tag.id!);
                    } else {
                      next.remove(tag.id);
                    }
                    widget.onChanged(next);
                  },
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newTagController,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: t.newTagHint,
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: t.addTagTooltip,
              onPressed: _addTag,
            ),
          ],
        ),
      ],
    );
  }
}
