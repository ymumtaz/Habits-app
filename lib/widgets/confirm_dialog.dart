import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shows a small "are you sure?" dialog before a destructive action.
/// Returns true if the user confirmed, false/null if they backed out
/// (tapped Cancel, the scrim, or the back button) — always treat a
/// non-true result as "don't delete".
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
          ),
          child: Text(context.l10n.delete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
