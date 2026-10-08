import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/dialogs.dart';
import '../notes/note_model.dart';
import '../notes/note_editor_page.dart';
import '../todo/todo_editor_page.dart';
import '../todo/todo_status_indicator.dart';
import '../todo/todo_presentation.dart';
import 'collection_repository.dart';
import '../templates/template_catalog.dart';
import '../templates/template_page.dart';

class CollectionPage extends StatefulWidget {
  final CollectionKind kind;
  final String? folderId;
  final String? folderName;
  final bool trash;
  const CollectionPage({
    super.key,
    required this.kind,
    this.folderId,
    this.folderName,
    this.trash = false,
  });
  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  late final CollectionRepository repo;
  CollectionRows? rows;
  bool failed = false, busy = false;
  String query = '', filter = 'all';
  late String? name;
  Timer? debounce, timer;
  final searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    repo = CollectionRepository(widget.kind);
    name = widget.folderName;
    load();
    if (!repo.notes) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted &&
            ModalRoute.of(context)?.isCurrent == true &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    timer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  int _request = 0;
  Future<void> load() async {
    final request = ++_request;
    try {
      final result = await repo.load(
        folderId: widget.folderId,
        trash: widget.trash,
        query: query,
        filter: filter,
      );
      if (mounted && request == _request) {
        setState(() {
          rows = result;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) setState(() => failed = true);
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await load();
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([Map<String, Object?>? row]) async {
    if (widget.trash) {
      if (row != null) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(row['title'] as String? ?? ''),
            content: SingleChildScrollView(
              child: Text(
                row[repo.notes ? 'body' : 'description'] as String? ?? '',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(c.tr('close')),
              ),
            ],
          ),
        );
      }
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => repo.notes
            ? NoteEditorPage(
                note: row == null ? null : Note.fromMap(row),
                folderId: widget.folderId,
              )
            : TodoEditorPage(todo: row, folderId: widget.folderId),
      ),
    );
    await load();
  }

  Future<void> folder(Map<String, Object?> row) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionPage(
          kind: widget.kind,
          folderId: row['id'] as String,
          folderName: row['name'] as String,
          trash: widget.trash,
        ),
      ),
    );
    await load();
  }

  Future<void> fromTemplate() async {
    final language = Localizations.localeOf(context).languageCode;
    final template = await Navigator.push<EntryTemplate>(
      context,
      MaterialPageRoute(builder: (_) => TemplatePage(todos: !repo.notes)),
    );
    if (template == null || !mounted) return;
    Map<String, Object?>? created;
    await run(() async {
      created = await repo.createFromTemplate(
        template,
        language,
        widget.folderId,
      );
      if (mounted) {
        debounce?.cancel();
        searchController.clear();
        setState(() {
          filter = 'all';
          query = '';
        });
      }
    });
    if (created == null || !mounted) return;
    if (repo.notes) {
      await edit(created);
    } else {
      await folder(created!);
    }
  }

  Future<void> createFolder() async {
    final text = await askText(context, context.tr('newFolder'));
    if (text != null) await run(() => repo.createFolder(text, widget.folderId));
  }

  Future<void> move(String id, bool folder) async {
    final folders = await repo.activeFolders();
    if (!mounted) return;
    final blocked = <String>{if (folder) id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final f in folders) {
        if (blocked.contains(f['parent_id']) &&
            blocked.add(f['id'] as String)) {
          changed = true;
        }
      }
    }
    final target = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(c.tr('move')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, ''),
            child: Text(c.tr('home')),
          ),
          ...folders
              .where((f) => !blocked.contains(f['id']))
              .map(
                (f) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, f['id'] as String),
                  child: Text(_path(f, folders)),
                ),
              ),
        ],
      ),
    );
    if (target != null) {
      await run(
        () => repo.move(id, target.isEmpty ? null : target, folder: folder),
      );
    }
  }

  String _path(Map<String, Object?> folder, List<Map<String, Object?>> all) {
    final byId = {for (final f in all) f['id']: f};
    final parts = <String>[];
    final seen = <Object>{};
    Map<String, Object?>? at = folder;
    while (at != null && seen.add(at['id']!)) {
      parts.add(at['name'] as String);
      at = byId[at['parent_id']];
    }
    return parts.reversed.join(' / ');
  }

  Future<void> action(
    String key,
    Map<String, Object?> row,
    bool isFolder,
  ) async {
    final id = row['id'] as String;
    switch (key) {
      case 'rename':
        final text = await askText(
          context,
          context.tr('rename'),
          initial: row['name'] as String,
        );
        if (text != null) await run(() => repo.renameFolder(id, text));
        break;
      case 'move':
        await move(id, isFolder);
        break;
      case 'trash':
        if (await confirm(context, context.tr('trashConfirm'))) {
          await run(() => repo.trash(id, folder: isFolder));
        }
        break;
      case 'restore':
        await run(() => repo.restore(id, folder: isFolder));
        break;
      case 'deleteForever':
        if (await confirm(context, context.tr('permanentConfirm'))) {
          await run(() => repo.removeForever(id, folder: isFolder));
        }
        break;
      case 'favorites':
        await run(
          () =>
              repo.setField(id, 'is_favorite', row['is_favorite'] == 1 ? 0 : 1),
        );
        break;
      case 'archive':
        await run(
          () =>
              repo.setField(id, 'is_archived', row['is_archived'] == 1 ? 0 : 1),
        );
        break;
      case 'tags':
        final tags = List<String>.from(
          jsonDecode(row['tags'] as String? ?? '[]') as List,
        );
        final text = await askText(
          context,
          context.tr('tags'),
          initial: tags.join(', '),
          allowEmpty: true,
        );
        if (text != null) {
          await run(
            () => repo.setField(
              id,
              'tags',
              jsonEncode(
                text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .toList(),
              ),
            ),
          );
        }
        break;
    }
  }

  Widget menu(Map<String, Object?> row, bool folder) => PopupMenuButton<String>(
    enabled: !busy,
    onSelected: (key) => action(key, row, folder),
    itemBuilder: (c) => [
      for (final key
          in widget.trash
              ? ['restore', 'deleteForever']
              : [
                  if (folder) 'rename',
                  'move',
                  if (!folder && repo.notes) ...[
                    'favorites',
                    'archive',
                    'tags',
                  ],
                  'trash',
                ])
        PopupMenuItem(value: key, child: Text(c.tr(key))),
    ],
  );
  String dueText(Map<String, Object?> row) {
    final due = DateTime.tryParse(row['due_at'] as String? ?? '');
    if (due == null) return '';
    final difference = due.difference(DateTime.now());
    final duration = difference.abs();
    final clock =
        '${duration.inDays} ${context.tr('dayUnit')} ${duration.inHours % 24}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    return '${context.tr(difference.isNegative ? 'overdue' : 'remaining')}: $clock';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final visibleItems =
        rows?.items
            .where(
              (row) =>
                  repo.notes ||
                  widget.trash ||
                  matchesTodoFilter(row, filter, now),
            )
            .toList() ??
        <Map<String, Object?>>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          name ??
              context.tr(
                widget.trash
                    ? 'trash'
                    : repo.notes
                    ? 'notes'
                    : 'todos',
              ),
        ),
        actions: [
          if (!widget.trash)
            IconButton(
              tooltip: context.tr('trash'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CollectionPage(kind: widget.kind, trash: true),
                  ),
                );
                await load();
              },
            ),
          if (widget.folderId != null)
            PopupMenuButton<String>(
              onSelected: (key) async {
                final row = {'id': widget.folderId, 'name': name};
                if (key == 'rename') {
                  final text = await askText(
                    context,
                    context.tr('rename'),
                    initial: name ?? '',
                  );
                  if (text != null) {
                    await run(() => repo.renameFolder(widget.folderId!, text));
                    if (mounted) setState(() => name = text);
                  }
                  return;
                }
                await action(key, row, true);
                if (!mounted) return;
                if ([
                  'trash',
                  'restore',
                  'deleteForever',
                  'move',
                ].contains(key)) {
                  final current = (await repo.database).query(
                    repo.folders,
                    where: 'id = ?',
                    whereArgs: [widget.folderId],
                  );
                  final result = await current;
                  if (!mounted || !context.mounted) return;
                  if (result.isEmpty ||
                      result.first['is_deleted'] != (widget.trash ? 1 : 0)) {
                    Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (c) => [
                for (final key
                    in widget.trash
                        ? ['restore', 'deleteForever']
                        : ['rename', 'move', 'trash'])
                  PopupMenuItem(value: key, child: Text(c.tr(key))),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: context.tr('search'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) {
                query = v;
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 250), load);
              },
            ),
          ),
          if (repo.notes && !widget.trash)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final key in ['all', 'favorites', 'archive'])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(context.tr(key)),
                        selected: filter == key,
                        onSelected: (_) {
                          setState(() => filter = key);
                          load();
                        },
                      ),
                    ),
                ],
              ),
            ),
          if (!repo.notes && !widget.trash)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final key in [
                    'all',
                    'todoAll',
                    'todoDone',
                    'todoOverdue',
                    'todoHour',
                    'todoDay',
                  ])
                    Semantics(
                      selected: filter == key,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() {
                            filter = key;
                            rows = null;
                          });
                          load();
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: filter == key
                                    ? scheme.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            context.tr(key == 'all' ? 'folderView' : key),
                            style: TextStyle(
                              fontWeight: filter == key
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: filter == key
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (!repo.notes && !widget.trash && filter != 'all')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.tr('allFoldersHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: failed
                ? Center(
                    child: TextButton(
                      onPressed: load,
                      child: Text(context.tr('retry')),
                    ),
                  )
                : rows == null
                ? const Center(child: CircularProgressIndicator())
                : rows!.folders.isEmpty && visibleItems.isEmpty
                ? Center(child: Text(context.tr('empty')))
                : RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                      children: [
                        ...rows!.folders.map(
                          (row) => Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.folder_outlined,
                                color: scheme.primary,
                              ),
                              title: Text(row['name'] as String),
                              onTap: () => folder(row),
                              trailing: menu(row, true),
                            ),
                          ),
                        ),
                        ...visibleItems.map(
                          (row) => Card(
                            shape: repo.notes
                                ? null
                                : RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: todoIsOverdue(row, now)
                                          ? scheme.outline
                                          : todoColor(
                                              row,
                                              now,
                                            ).withValues(alpha: .55),
                                    ),
                                  ),
                            child: ListTile(
                              leading: repo.notes
                                  ? Icon(
                                      row['is_favorite'] == 1
                                          ? Icons.star
                                          : Icons.description_outlined,
                                      color: scheme.primary,
                                    )
                                  : Checkbox(
                                      value: row['is_done'] == 1,
                                      activeColor: todoPriorityColors.first,
                                      onChanged: widget.trash || busy
                                          ? null
                                          : (v) => run(
                                              () => repo.setField(
                                                row['id'] as String,
                                                'is_done',
                                                v == true ? 1 : 0,
                                              ),
                                            ),
                                    ),
                              title: Text(
                                (row['title'] as String).isEmpty
                                    ? context.tr('untitled')
                                    : row['title'] as String,
                                style: TextStyle(
                                  decoration: !repo.notes && row['is_done'] == 1
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: repo.notes
                                  ? Text(
                                      row['body'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : Text(
                                      '${context.tr(['normal', 'important', 'veryImportant', 'critical'][(row['priority'] as int? ?? 0).clamp(0, 3).toInt()])}'
                                      '${row['is_done'] == 1 ? '' : '\n${dueText(row)}'}',
                                    ),
                              onTap: () => edit(row),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!repo.notes)
                                    TodoStatusIndicator(
                                      key: ValueKey('status-${row['id']}'),
                                      interval: todoPulseMilliseconds(row, now),
                                      overdue: todoIsOverdue(row, now),
                                      completed: row['is_done'] == 1,
                                      color: todoColor(row, now),
                                    ),
                                  menu(row, false),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.trash
          ? null
          : FloatingActionButton(
              tooltip: context.tr('add'),
              onPressed: busy
                  ? null
                  : () async {
                      final choice = await showModalBottomSheet<String>(
                        context: context,
                        builder: (c) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.add),
                                title: Text(
                                  c.tr(repo.notes ? 'newNote' : 'newTask'),
                                ),
                                onTap: () => Navigator.pop(c, 'item'),
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.dashboard_customize_outlined,
                                ),
                                title: Text(c.tr('tpl_templates')),
                                onTap: () => Navigator.pop(c, 'template'),
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.create_new_folder_outlined,
                                ),
                                title: Text(c.tr('newFolder')),
                                onTap: () => Navigator.pop(c, 'folder'),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (!mounted) return;
                      if (choice == 'item') await edit();
                      if (choice == 'folder') await createFolder();
                      if (choice == 'template') await fromTemplate();
                    },
              child: const Icon(Icons.add),
            ),
    );
  }
}
