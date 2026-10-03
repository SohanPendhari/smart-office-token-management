import 'package:flutter/material.dart';

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? const Color(0xFFB91C1C) : null,
    behavior: SnackBarBehavior.floating,
  ));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirmLabel = 'Yes'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}
