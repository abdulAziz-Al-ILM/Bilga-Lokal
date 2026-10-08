import '../../core/strings.dart';

/// Immutable source templates. Created entries are independent database rows.
class EntryTemplate {
  final String id;
  final List<String> sections;
  final bool todo;
  const EntryTemplate(this.id, this.sections, {this.todo = false});
  String title(String language) => Strings.get(language, 'tpl_$id');
  List<String> lines(String language) =>
      sections.map((key) => Strings.get(language, 'tpl_$key')).toList();
  String body(String language) =>
      lines(language).map((line) => '$line\n\n').join('\n');
}

const entryTemplates = <EntryTemplate>[
  EntryTemplate('journal', ['events', 'lessons', 'next']),
  EntryTemplate('study', ['topic', 'points', 'questions', 'next']),
  EntryTemplate('meeting', ['topic', 'points', 'decisions', 'next']),
  EntryTemplate('idea', ['problem', 'solution', 'next']),
  EntryTemplate('book', ['author', 'points', 'lessons', 'next']),
  EntryTemplate('daily', ['plan', 'focus', 'review'], todo: true),
  EntryTemplate('weekly', ['plan', 'prepare', 'review'], todo: true),
  EntryTemplate('shopping', ['list', 'budget', 'buy'], todo: true),
  EntryTemplate('exam', ['topics', 'practice', 'review'], todo: true),
  EntryTemplate('travel', ['tickets', 'documents', 'pack'], todo: true),
];
