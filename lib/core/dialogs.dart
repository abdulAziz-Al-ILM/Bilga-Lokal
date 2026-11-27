import 'package:flutter/material.dart';

import 'strings.dart';

Future<bool> confirm(
  BuildContext context,
  String message, {
  String? title,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title ?? c.tr('confirm')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr('continue')),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
  bool allowEmpty = false,
  int maxLength = 150,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: maxLength,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        onSubmitted: (v) {
          if (allowEmpty || v.trim().isNotEmpty) Navigator.pop(c, v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(c.tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (allowEmpty || controller.text.trim().isNotEmpty) {
              Navigator.pop(c, controller.text.trim());
            }
          },
          child: Text(c.tr('save')),
        ),
      ],
    ),
  );
  // Wait for the closing dialog animation before disposing its controller.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}

void showError(BuildContext context, [String key = 'error']) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(context.tr(key))));
}
