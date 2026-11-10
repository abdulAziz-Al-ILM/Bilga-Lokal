import '../notes/rich_note_widgets.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/dialogs.dart';
import '../../core/strings.dart';
import '../attachments/attachment_store.dart';
import '../finance/ledger.dart';
import '../habits/habit_store.dart';
import '../notes/note_editor_page.dart';
import '../notes/note_model.dart';
import '../private_space/record_store.dart';
import '../private_space/space_page.dart';
import '../todo/todo_editor_page.dart';
import '../todo/todo_checklist_store.dart';
import 'search_repository.dart';

String kindKey(String kind) => switch (kind) {
  'note' => 'notes',
  'todo' => 'todos',
  'habit' => 'xHabits',
  'folder' || 'todoFolder' => 'folderView',
  'experience' => 'xExperience',
  'book' => 'xBooks',
  'finance' => 'xFinance',
  _ => 'all',
};

/// No mutation routes exist when readOnly is true. This remains available
/// behind AppLock after trial expiry, independently of billing/network state.
class LibraryPage extends StatefulWidget {
  final bool readOnly, assistant;
  final SearchRepository? repository;
  const LibraryPage({
    super.key,
    this.readOnly = false,
    this.assistant = false,
    this.repository,
  });
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final repo = widget.repository ?? SearchRepository();
  final query = TextEditingController();
  List<SearchHit> hits = [];
  String? kind;
  bool archived = false, busy = false, failed = false, more = false;
  int generation = 0;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    query.dispose();
    super.dispose();
  }

  Future<void> load({bool append = false}) async {
    final request = ++generation;
    final offset = append ? hits.length : 0;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final rows = await repo.search(
        query.text,
        kind: kind,
        includeArchived: archived,
        offset: offset,
      );
      if (!mounted || request != generation) return;
      setState(() {
        hits = append ? [...hits, ...rows] : rows;
        more = rows.length == 50;
      });
    } catch (_) {
      if (mounted && request == generation) setState(() => failed = true);
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr(widget.assistant ? 'textAssistant' : 'dataLibrary'),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (widget.assistant)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(context.tr('searchAssistantInfo')),
                ),
              if (widget.readOnly)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(context.tr('readOnlyInfo')),
                ),
              TextField(
                controller: query,
                decoration: InputDecoration(
                  labelText: context.tr('search'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (_) {
                  // Invalidate an in-flight result immediately, before the debounce.
                  generation++;
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 250), load);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: kind ?? '',
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(context.tr('all')),
                        ),
                        for (final k in [
                          'note',
                          'todo',
                          'habit',
                          'experience',
                          'book',
                          'finance',
                          'folder',
                          'todoFolder',
                        ])
                          DropdownMenuItem(
                            value: k,
                            child: Text(
                              '${context.tr(kindKey(k))}${k == 'todoFolder' ? ' · ${context.tr('todos')}' : ''}',
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        setState(() => kind = v == '' ? null : v);
                        load();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: Text(context.tr('archive')),
                    selected: archived,
                    onSelected: (v) {
                      setState(() => archived = v);
                      load();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (failed)
          TextButton(onPressed: load, child: Text(context.tr('retry'))),
        Expanded(
          child: !busy && !failed && hits.isEmpty
              ? Center(child: Text(context.tr('empty')))
              : ListView.builder(
                  itemCount: hits.length + (more ? 1 : 0),
                  itemBuilder: (c, i) {
                    if (i == hits.length) {
                      return TextButton(
                        onPressed: busy ? null : () => load(append: true),
                        child: Text(c.tr('searchMore')),
                      );
                    }
                    final hit = hits[i];
                    return ListTile(
                      title: Text(
                        hit.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${c.tr(kindKey(hit.kind))}\n${hit.preview}',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push<void>(
                          c,
                          MaterialPageRoute(
                            builder: (_) => DocumentPage(
                              hit: hit,
                              repository: repo,
                              readOnly: widget.readOnly,
                            ),
                          ),
                        );
                        if (mounted) load();
                      },
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class DocumentPage extends StatefulWidget {
  final SearchHit hit;
  final SearchRepository repository;
  final bool readOnly;
  const DocumentPage({
    super.key,
    required this.hit,
    required this.repository,
    this.readOnly = true,
  });
  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  Map<String, Object?>? row;
  bool busy = false, failed = false;
  List<Map<String, Object?>> versions = [];
  List<PrivateRecord> attachments = [];
  List<TodoChecklistItem> checklist = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final source = await widget.repository.source(widget.hit);
      final subtasks = widget.hit.kind == 'todo'
          ? await TodoChecklistStore.load(
              await widget.repository.todos,
              widget.hit.id,
            )
          : <TodoChecklistItem>[];
      final history = widget.hit.kind == 'note'
          ? await (await widget.repository.notes).query(
              'note_versions',
              where: 'note_id = ?',
              whereArgs: [widget.hit.id],
              orderBy: 'version_id DESC',
              limit: 100,
            )
          : <Map<String, Object?>>[];
      final files = await (await widget.repository.notes).query(
        'private_records',
        where: "kind = ? AND json_extract(payload, '\$.owner') = ? AND json_extract(payload, '\$.ownerKind') = ?",
        whereArgs: ['attachment', widget.hit.id, widget.hit.kind],
      );
      final owned = files
          .map(PrivateRecord.row)
          .where(
            (r) =>
                r.data['owner'] == widget.hit.id &&
                r.data['ownerKind'] == widget.hit.kind,
          )
          .toList();
      if (mounted) {
        setState(() {
          row = source;
          failed = source == null;
          versions = history;
          attachments = owned;
          checklist = subtasks;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Map<String, dynamic> get payload => row?['payload'] is String
      ? jsonDecode(row!['payload'] as String) as Map<String, dynamic>
      : {};
  String get text {
    final r = row!;
    if (widget.hit.kind == 'note') return r['body'] as String;
    if (widget.hit.kind == 'todo') {
      return [
        r['description'],
        if (r['due_at'] != null)
          '${context.tr('due')}: ${date(r['due_at'] as String)}',
        context.tr(r['is_done'] == 1 ? 'todoDone' : 'todoAll'),
        if (checklist.isNotEmpty) context.tr('taskChecklist'),
        for (final item in checklist) '${item.done ? '☑' : '☐'} ${item.title}',
      ].join('\n\n');
    }
    if (widget.hit.kind == 'habit') {
      final h = Habit.fromMap(r);
      final entries = h.plan.entries.keys.toList()
        ..sort((a, b) => b.compareTo(a));
      return [
        '${context.tr('hTarget')}: ${h.plan.target} ${h.plan.unit}',
        h.plan.reason,
        for (final day in {
          ...entries,
          ...h.days,
        }.toList()..sort((a, b) => b.compareTo(a)))
          '${date(day)}: ${h.plan.amount(DateTime.parse(day), h.days)} ${h.plan.unit}\n${h.plan.entries[day]?['note'] ?? ''}',
      ].join('\n\n');
    }
    if (widget.hit.kind == 'finance') {
      return [
        for (final e in payload['entries'] as List? ?? [])
          '${date(e['date'] as String)} · ${context.tr('x${e['type']}')}\n${moneyText(e['amount'] as int, payload['currency'] as String)}\n${e['description'] ?? ''}',
      ].join('\n\n');
    }
    return SearchHit.recordText(payload);
  }

  String date(String raw) {
    final d = DateTime.tryParse(raw)?.toLocal();
    return d == null
        ? raw
        : MaterialLocalizations.of(context).formatMediumDate(d);
  }

  Future<void> export(Stream<List<int>> bytes, String name, String mime) async {
    if (busy) return;
    if (!await confirm(context, context.tr('xPlainExport')) || !mounted) return;
    setState(() => busy = true);
    try {
      await Attachments.export(name, mime, bytes);
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit() async {
    if (widget.readOnly || row == null) return;
    final Widget? page = switch (widget.hit.kind) {
      'note' => NoteEditorPage(note: Note.fromMap(row!)),
      'todo' => TodoEditorPage(todo: row, database: widget.repository.todoDb),
      'experience' || 'book' => RecordPage(PrivateRecord.row(row!)),
      _ => null,
    };
    if (page == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.hit.title),
      actions: [
        if (!widget.readOnly &&
            {'note', 'todo', 'experience', 'book'}.contains(widget.hit.kind))
          IconButton(
            tooltip: context.tr('edit'),
            onPressed: row == null ? null : edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        IconButton(
          tooltip: context.tr('export'),
          onPressed: row == null || busy
              ? null
              : () => export(
                  Stream.value(utf8.encode('${widget.hit.title}\n\n$text')),
                  'Bilga-${widget.hit.kind}.txt',
                  'text/plain',
                ),
          icon: const Icon(Icons.ios_share),
        ),
      ],
    ),
    body: failed
        ? Center(
            child: TextButton(
              onPressed: load,
              child: Text(context.tr('retry')),
            ),
          )
        : row == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (busy) const LinearProgressIndicator(),
              Text(
                context.tr(kindKey(widget.hit.kind)),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              if (widget.hit.kind == 'note')
                RichNoteReader(
                  body: row!['body'] as String,
                  richBody: row!['rich_body'] as String?,
                )
              else
                SelectableText(text),
              const SizedBox(height: 24),
              Text(
                '${context.tr('created')}: ${date(row!['created_at'] as String)}',
              ),
              Text(
                '${context.tr('updated')}: ${date(row!['updated_at'] as String)}',
              ),
              for (final a in attachments)
                ListTile(
                  title: Text(a.data['title'] as String),
                  subtitle: a.data['text'] is String
                      ? SelectableText(a.data['text'] as String)
                      : null,
                  trailing: a.data['blob'] is String
                      ? IconButton(
                          tooltip: context.tr('export'),
                          onPressed: busy
                              ? null
                              : () => export(
                                  Attachments.read(a.data['blob'] as String),
                                  a.data['title'] as String,
                                  a.data['mime'] as String? ??
                                      'application/octet-stream',
                                ),
                          icon: const Icon(Icons.download_outlined),
                        )
                      : null,
                ),
              if (versions.isNotEmpty)
                ExpansionTile(
                  title: Text(context.tr('history')),
                  children: [
                    for (final v in versions)
                      ExpansionTile(
                        title: Text(date(v['created_at'] as String)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(
                              '${v['title']}\n\n${v['body']}',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
  );
}
