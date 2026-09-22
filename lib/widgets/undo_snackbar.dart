import 'package:flutter/material.dart';

/// Shows a brief snackbar with an "Undo" action — used right after a
/// delete so a mis-tap is cheap to recover from, on top of (not
/// instead of) the confirm dialog already shown for bigger deletes.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
        duration: const Duration(seconds: 4),
      ),
    );
}
