import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'template_catalog.dart';

/// Returns a template only after explicit confirmation; preview never writes.
class TemplatePage extends StatelessWidget {
  final bool todos;
  const TemplatePage({super.key, required this.todos});

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('tpl_templates'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final template in entryTemplates.where((t) => t.todo == todos))
            Card(
              child: ListTile(
                leading: Icon(
                  todos ? Icons.checklist : Icons.description_outlined,
                ),
                title: Text(template.title(language)),
                subtitle: Text(template.lines(language).join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final use = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text(template.title(language)),
                      content: SingleChildScrollView(
                        child: Text(
                          todos
                              ? template
                                    .lines(language)
                                    .map((s) => '☐ $s')
                                    .join('\n\n')
                              : template.body(language),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(c.tr('cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: Text(c.tr('tpl_use')),
                        ),
                      ],
                    ),
                  );
                  if (use == true && context.mounted) {
                    Navigator.pop(context, template);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
