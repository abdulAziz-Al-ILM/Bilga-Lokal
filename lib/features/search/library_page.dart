import '../notes/rich_note_widgets.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/dialogs.dart';
import '../../core/strings.dart';
import '../attachments/attachment_store.dart';
import '../finance/ledger.dart';
import '../books/book_library.dart';
import '../books/reading/reading_store.dart';
import '../books/reading/book_reading_page.dart';
import '../agent/agent_access.dart';
import '../finance/finance_reports_page.dart';
import '../finance/account_ledger.dart';
import '../habits/habit_store.dart';
import '../notes/note_editor_page.dart';
import '../notes/note_model.dart';
import '../private_space/record_store.dart';
import '../private_space/space_page.dart';
import '../todo/todo_editor_page.dart';
import '../todo/todo_checklist_store.dart';
import '../todo/todo_project_store.dart';
import '../todo/todo_project_editor.dart' show taskProjectStatusKey;
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
  bool bookReadable = false;
  List<Map<String, Object?>> versions = [];
  List<PrivateRecord> attachments = [];
  List<TodoChecklistItem> checklist = [];
  TodoProject? project;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final source = await widget.repository.source(widget.hit);
      bookReadable =
          widget.hit.kind == 'book' &&
          (await ReadingStore(
                records: RecordStore(database: await widget.repository.notes),
              ).one(widget.hit.id, 'source')) !=
              null;
      if (source != null &&
          {'finance', 'book', 'experience'}.contains(widget.hit.kind)) {
        RecordStore.validate(
          widget.hit.kind,
          jsonDecode(source['payload'] as String) as Map<String, dynamic>,
        );
      }
      final projectValue = widget.hit.kind == 'todoFolder'
          ? (await TodoProjectStore(await widget.repository.todos)
                .all())[widget.hit.id]
          : null;
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
        where: "kind = ? AND json_extract(payload, '\$.owner') = ? AND json_extract(payload, '\$.ownerKind') = ? AND coalesce(json_extract(payload,'\$.role'),'') NOT IN ('bookSource','bookCover','bookIndex')",
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
          project = projectValue;
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
    if (project case final value?) {
      return [
        context.tr('taskProject'),
        context.tr(taskProjectStatusKey(value.status)),
        value.description,
        if (value.dueDate != null)
          '${context.tr('taskProjectDue')}: ${date(value.dueDate!)}',
      ].join('\n\n');
    }
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
        '${context.tr('haAdvanced')}: ${context.tr('haType_${h.plan.currentSchedule.type}')}',
        if (h.plan.currentSchedule.start != null)
          '${context.tr('haStart')}: ${h.plan.currentSchedule.start}',
        if (h.plan.currentSchedule.end != null)
          '${context.tr('haEnd')}: ${h.plan.currentSchedule.end}',
        if (['weekly', 'monthly'].contains(h.plan.currentSchedule.type))
          '${context.tr('haQuota')}: ${h.plan.currentSchedule.quota}',
        if (h.plan.currentSchedule.type == 'interval')
          '${context.tr('haInterval')}: ${h.plan.currentSchedule.interval}',
        for (final pause in h.plan.currentSchedule.pauses)
          '${context.tr('haPauses')}: ${pause.from} – ${pause.until}',
        if (h.plan.category.isNotEmpty)
          '${context.tr('haCategory')}: ${h.plan.category}',
        if (h.plan.tags.isNotEmpty)
          '${context.tr('eTags')}: ${h.plan.tags.join(', ')}',
        if (h.plan.goalTarget != null)
          '${context.tr('haGoalProgress')}: ${h.plan.completedDays(h.days, DateTime.now())} / ${h.plan.goalTarget}',
        if (h.plan.goalDate != null)
          '${context.tr('haGoalDate')}: ${h.plan.goalDate}',
        for (final day in {
          ...entries,
          ...h.days,
        }.toList()..sort((a, b) => b.compareTo(a)))
          '${date(day)}: ${h.plan.amount(DateTime.parse(day), h.days)} ${h.plan.unit}\n${h.plan.entries[day]?['note'] ?? ''}',
      ].join('\n\n');
    }
    if (widget.hit.kind == 'book') {
      return BookLibrary.readable(payload, label: context.tr, date: date);
    }
    if (widget.hit.kind == 'finance') {
      final accounts = AccountLedger.accounts(payload);
      final balances = AccountLedger.balances(
        payload,
        throughDate: DateTime.now().toIso8601String().substring(0, 10),
      );
      final names = {
        for (final account in accounts) account['id']: account['name'],
      };
      final entries = {
        for (final entry in payload['entries'] as List) entry['id']: entry,
      };
      return [
        context.tr('fAccounts'),
        for (final account in accounts)
          '${account['name']} · ${account['currency']}\n${context.tr('fAccountOpening')}: ${moneyText(account['opening'] as int, account['currency'] as String)}\n${context.tr('fAccountCurrent')}: ${moneyText(balances[account['id']]!, account['currency'] as String)}'
              '${account['openedOn'] == null ? '' : '\n${context.tr('fAccountOpeningDate')}: ${date(account['openedOn'] as String)}'}'
              '${account['archived'] == true ? '\n${context.tr('fAccountArchived')}' : ''}',
        for (final e in payload['entries'] as List? ?? [])
          '${date(e['date'] as String)} · ${context.tr('x${e['type']}')}\n${moneyText(e['amount'] as int, payload['currency'] as String)}\n${e['description'] ?? ''}'
              '${e['type'] == 'transfer' ? '\n${names[e['from']]} → ${names[e['to']]}' : '\n${names[e['account'] ?? AccountLedger.legacyId]}'}'
              '${e['void'] == true ? '\n${context.tr('fEntryVoided')}' : ''}',
        for (final entry in payload['entries'] as List)
          if ((entry['versions'] as List? ?? []).isNotEmpty) ...[
            '${context.tr('fTransactionHistory')} · ${context.tr('x${entry['type']}')}',
            for (final event in entry['versions'] as List)
              '${date(event['at'] as String)} · ${context.tr(switch (event['action']) {
                    'void' => 'fTransactionVoided',
                    'restore' => 'fTransactionRestored',
                    _ => 'fTransactionEdited',
                  })}\n${moneyText(event['before']['amount'] as int, payload['currency'] as String)} · ${date(event['before']['date'] as String)}\n${event['before']['category']}\n${event['before']['description']}'
                  '${event['before']['type'] == 'transfer' ? '\n${names[event['before']['from']]} → ${names[event['before']['to']]}' : '\n${names[event['before']['account']]}'}'
                  '${event['before']['void'] == true ? '\n${context.tr('fEntryVoided')}' : ''}',
          ],
        if ((payload['reconciliations'] as List? ?? []).isNotEmpty)
          context.tr('fAccountReconciliationHistory'),
        for (final event in payload['reconciliations'] as List? ?? [])
          '${date(event['date'] as String)} · ${names[event['account']]}\n${context.tr('fAccountObserved')}: ${moneyText(event['observed'] as int, payload['currency'] as String)}\n${event['description']}'
              '${event['adjustment'] == null
                  ? '\n${context.tr('fAccountMatched')}'
                  : entries[event['adjustment']]?['void'] == true
                  ? '\n${context.tr('fEntryVoided')}'
                  : ''}',
      ].join('\n\n');
    }
    return SearchHit.recordText(payload);
  }

  String date(String raw) {
    final d = DateTime.tryParse(raw)?.toLocal();
    return d == null
        ? raw
        : '${MaterialLocalizations.of(context).formatFullDate(d)}${raw.contains('T') ? ' · ${TimeOfDay.fromDateTime(d).format(context)}' : ''}';
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
      'experience' || 'book' => RecordPage(
        PrivateRecord.row(row!),
        store: RecordStore(database: widget.repository.notesDb),
      ),
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
        if (bookReadable)
          IconButton(
            key: const Key('library-read-book'),
            tooltip: context.tr('rRead'),
            icon: const Icon(Icons.menu_book),
            onPressed: row == null || busy
                ? null
                : () async {
                    final db = await widget.repository.notes;
                    if (!context.mounted) return;
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookReadingPage(
                          book: PrivateRecord.row(row!),
                          store: ReadingStore(
                            records: RecordStore(database: db),
                          ),
                          access: AgentAccess.instance,
                          readOnly: widget.readOnly,
                        ),
                      ),
                    );
                    if (mounted) load();
                  },
          ),
        if (widget.hit.kind == 'finance')
          IconButton(
            key: const Key('finance-reader-reports-open'),
            tooltip: context.tr('xReport'),
            icon: const Icon(Icons.insert_chart_outlined),
            onPressed: row == null || busy || failed
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FinanceReportsPage(
                        ledger: PrivateRecord.row(row!),
                        store: RecordStore(database: widget.repository.notesDb),
                      ),
                    ),
                  ),
          ),
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
