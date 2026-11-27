import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'habit_templates.dart';

/// Preview and selection only. The caller must open an editable creation form.
class HabitTemplatePage extends StatefulWidget {
  const HabitTemplatePage({super.key});
  @override
  State<HabitTemplatePage> createState() => _TemplatesState();
}

class _TemplatesState extends State<HabitTemplatePage> {
  String category = 'all', query = '';
  @override
  Widget build(BuildContext context) {
    final categories = habitTemplates.map((t) => t.category).toSet();
    final matches = habitTemplates.where(
      (t) =>
          (category == 'all' || t.category == category) &&
          '${context.tr('ht_${t.id}')} ${context.tr('htWhy_${t.id}')} '
                  '${context.tr('htCat_${t.category}')}'
              .toLowerCase()
              .contains(query.toLowerCase().trim()),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('htLibrary'))),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(context.tr('htPreviewNotice')),
              const SizedBox(height: 16),
              TextField(
                key: const Key('habit-template-search'),
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                decoration: InputDecoration(
                  labelText: context.tr('search'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (text) => setState(() => query = text),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final value in ['all', ...categories])
                    FilterChip(
                      label: Text(context.tr('htCat_$value')),
                      selected: category == value,
                      onSelected: (_) => setState(() => category = value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (matches.isEmpty) Text(context.tr('empty')),
              for (final template in matches)
                Card(
                  child: ListTile(
                    key: ValueKey('habit-template-${template.id}'),
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(context.tr('ht_${template.id}')),
                    subtitle: Text(context.tr('htWhy_${template.id}')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final plan = template.plan(context.tr);
                      final use = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(c.tr('ht_${template.id}')),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.tr('htWhy_${template.id}')),
                                const SizedBox(height: 12),
                                Text(
                                  '${c.tr('hTarget')}: ${plan.target} ${plan.unit}',
                                ),
                                Text(
                                  '${c.tr('hDays')}: ${(plan.weekdays.toList()..sort()).map((d) => MaterialLocalizations.of(c).narrowWeekdays[d % 7]).join(', ')}',
                                ),
                                const SizedBox(height: 12),
                                Text(c.tr('htPreviewNotice')),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text(c.tr('cancel')),
                            ),
                            FilledButton(
                              key: const Key('habit-template-customize'),
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(c.tr('htCustomize')),
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
        ),
      ),
    );
  }
}
