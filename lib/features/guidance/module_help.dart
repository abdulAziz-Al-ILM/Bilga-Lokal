import 'package:flutter/material.dart';

import '../../core/strings.dart';

class ModuleHelp {
  final String id, title;
  final IconData icon;
  const ModuleHelp(this.id, this.title, this.icon);
  String get purpose => 'help${id}Purpose';
  String get examples => 'help${id}Examples';
  String get start => 'help${id}Start';
  String get results => 'help${id}Results';
}

const moduleHelp = [
  ModuleHelp('notes', 'notes', Icons.edit_note_outlined),
  ModuleHelp('tasks', 'todos', Icons.task_alt_outlined),
  ModuleHelp('habits', 'xHabits', Icons.local_fire_department_outlined),
  ModuleHelp('finance', 'xFinance', Icons.account_balance_wallet_outlined),
  ModuleHelp('experiences', 'xExperience', Icons.auto_stories_outlined),
  ModuleHelp('books', 'xBooks', Icons.menu_book_outlined),
];

/// A user chooses every action; opening help never owns a repository or record.
Future<String?> showModuleHelp(BuildContext context, String id) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) {
        final info = moduleHelp.singleWhere((m) => m.id == id);
        return FractionallySizedBox(
          heightFactor: .85,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.tr(info.title),
                  style: Theme.of(c).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(c.tr(info.purpose)),
                const SizedBox(height: 16),
                Text(c.tr(info.examples)),
                const SizedBox(height: 16),
                Text(c.tr(info.start)),
                const SizedBox(height: 16),
                Text(c.tr(info.results)),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('module-help-start'),
                  onPressed: () => Navigator.pop(c, 'start'),
                  child: Text(c.tr('helpStart')),
                ),
                OutlinedButton(
                  key: const Key('module-help-templates'),
                  onPressed: () => Navigator.pop(c, 'templates'),
                  child: Text(c.tr('tpl_templates')),
                ),
                OutlinedButton(
                  key: const Key('module-help-tutorial'),
                  onPressed: () => Navigator.pop(c, 'tutorial'),
                  child: Text(c.tr('gShowMe')),
                ),
                TextButton(
                  key: const Key('module-help-results'),
                  onPressed: () => Navigator.pop(c, 'results'),
                  child: Text(c.tr('helpResults')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text(c.tr('close')),
                ),
              ],
            ),
          ),
        );
      },
    );
