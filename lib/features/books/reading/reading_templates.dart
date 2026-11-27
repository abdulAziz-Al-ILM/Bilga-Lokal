import 'package:flutter/material.dart';

import '../../../core/editor_form.dart';
import '../../../core/strings.dart';
import 'reading_store.dart';

const readingTemplates = <String, List<String>>{
  'note': ['idea', 'quote', 'interpretation', 'application'],
  'chapter': ['chapter', 'concepts', 'examples', 'learned'],
  'review': ['argument', 'strengths', 'weaknesses', 'evaluation', 'lessons'],
  'study': ['question', 'answer', 'explanation'],
  'goal': ['book', 'deadline', 'schedule', 'progress'],
};

/// Preview is a draft. Only the explicit form Save creates a reading card.
Future<void> useReadingTemplate(
  BuildContext context,
  ReadingStore store,
  String book,
  String title,
  bool Function() allowed,
) async {
  final key = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final key in readingTemplates.keys)
            ListTile(
              title: Text(c.tr('rTemplate_$key')),
              onTap: () => Navigator.pop(c, key),
            ),
        ],
      ),
    ),
  );
  if (key == null || !context.mounted) return;
  final fields = readingTemplates[key]!;
  if (!await consent(
        context,
        '${context.tr('rTemplate_$key')}\n\n${fields.map((f) => context.tr('rField_$f')).join('\n')}\n\n${context.tr('rTemplatePreview')}',
      ) ||
      !context.mounted) {
    return;
  }
  await editFields(
    context,
    context.tr('rTemplate_$key'),
    {for (final f in fields) f: context.tr('rField_$f')},
    initial: {if (key == 'goal') 'book': title},
    multiline: fields.toSet()..remove('deadline'),
    dateFields: {if (key == 'goal') 'deadline'},
    requiredFields: {fields.first, if (key == 'study') 'answer'},
    onSave: (v) async {
      if (!allowed()) throw StateError('access_expired');
      await store.put(book, 'card', {
        'v': 1,
        'type': key == 'study'
            ? 'question'
            : key == 'goal'
            ? 'action'
            : key == 'chapter'
            ? 'summary'
            : key == 'review'
            ? 'observation'
            : 'idea',
        'front': v[fields.first]!.trim(),
        'back': key == 'study'
            ? v['answer']!
            : fields
                  .skip(1)
                  .map((f) => '${context.tr('rField_$f')}: ${v[f]}')
                  .join('\n\n'),
        'explanation': v['explanation'] ?? '',
        'tags': <String>[],
        'box': 0,
        'reviews': 0,
        'due': DateTime.now().toUtc().toIso8601String(),
      });
    },
  );
}
