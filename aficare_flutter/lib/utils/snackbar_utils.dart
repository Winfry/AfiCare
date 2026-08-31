import 'package:flutter/material.dart';

/// Safely shows an error SnackBar.
///
/// Can be called from initState / async load methods that may still be
/// awaiting when the current frame renders. Uses [ScaffoldMessenger.maybeOf]
/// and defers the show until after the frame, and only if the [context] is
/// still mounted, so it never throws even if the widget was disposed.
void showErrorSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  });
}

/// Safely shows an informational SnackBar.
void showInfoSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  });
}
