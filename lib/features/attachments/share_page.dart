import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import '../notes/note_service.dart';
import '../notes/note_model.dart';
import '../todo/todo_service.dart';
import '../todo/todo_model.dart';
import '../habits/habit_store.dart';
import '../private_space/record_store.dart';
import 'attachment_store.dart';

class SharePage extends StatefulWidget {
  final Map<String, dynamic> incoming;
  const SharePage(this.incoming, {super.key});
  @override
  State<SharePage> createState() => _ShareState();
}

class _ShareState extends State<SharePage> {
  String kind = 'note';
  String? owner;
  List<(String, String)> targets = [];
  late String text = '${widget.incoming['text'] ?? ''}';
  late final files = List<Map<String, dynamic>>.from(
    (widget.incoming['files'] as List? ?? []).map(
      (r) => Map<String, dynamic>.from(r),
    ),
  );
  bool busy = false;
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      List<(String, String)> rows;
      switch (kind) {
        case 'note':
          rows = (await NoteService().getAllActiveNotes())
              .map((n) => (n.id, n.title))
              .toList();
        case 'todo':
          rows = (await TodoService().getTodos())
              .map((n) => (n.id, n.title))
              .toList();
        case 'habit':
          rows = (await HabitStore().all())
              .map((n) => (n.id, n.title))
              .toList();
        default:
          rows = (await RecordStore().all(kind))
              .map((n) => (n.id, n.data['title'] as String))
              .toList();
      }
      if (mounted) setState(() => targets = rows);
    } catch (_) {
      if (mounted) failure(context);
    }
  }

  Future<void> save() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (owner == null) {
        final v = await editFields(
          context,
          context.tr('xNew'),
          {'title': context.tr('title')},
          requiredFields: {'title'},
          onSave: (v) async {
            final title = v['title']!.trim();
            if (title.isEmpty) return;
            final id = localId(), now = DateTime.now();
            switch (kind) {
              case 'note':
                await NoteService().addNote(
                  Note(
                    id: id,
                    title: title,
                    body: '',
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
                owner = id;
              case 'todo':
                await TodoService().addTodo(
                  Todo(
                    id: id,
                    title: title,
                    isDone: false,
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
                owner = id;
              case 'habit':
                await HabitStore().create(title, id: id);
                owner = id;
              default:
                final r = await RecordStore().save(kind, {
                  'title': title,
                  if (kind == 'book') 'chapters': [],
                  if (kind == 'book') 'characters': '',
                  if (kind == 'experience') 'body': '',
                  if (kind == 'experience') 'category': 'life',
                });
                owner = r.id;
            }
          },
        );
        if (v == null || owner == null) return;
      }
      if (text.isNotEmpty) {
        await Attachments.text(kind, owner!, text);
        text = '';
      }
      while (files.isNotEmpty) {
        await Attachments.add(kind, owner!, files.first);
        files.removeAt(0);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(c.tr('xChoose'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (busy) const LinearProgressIndicator(),
        Text('${files.length} ${c.tr('xAttach')}'),
        if (text.isNotEmpty)
          Text(text, maxLines: 6, overflow: TextOverflow.ellipsis),
        DropdownButton<String>(
          isExpanded: true,
          value: kind,
          items: [
            for (final e in {
              'note': 'notes',
              'todo': 'todos',
              'habit': 'xHabits',
              'experience': 'xExperience',
              'book': 'xBooks',
            }.entries)
              DropdownMenuItem(value: e.key, child: Text(c.tr(e.value))),
          ],
          onChanged: busy || owner != null
              ? null
              : (v) {
                  setState(() {
                    kind = v!;
                    targets = [];
                  });
                  reload();
                },
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: owner ?? '',
          items: [
            DropdownMenuItem(value: '', child: Text(c.tr('xNew'))),
            for (final r in targets)
              DropdownMenuItem(
                value: r.$1,
                child: Text(r.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            if (owner != null && !targets.any((r) => r.$1 == owner))
              DropdownMenuItem(value: owner, child: Text(c.tr('saved'))),
          ],
          onChanged: busy
              ? null
              : (v) => setState(() => owner = v == '' ? null : v),
        ),
        FilledButton(onPressed: busy ? null : save, child: Text(c.tr('save'))),
      ],
    ),
  );
}
