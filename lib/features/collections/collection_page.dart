import '../guidance/guide_controller.dart';
import '../guidance/guide_host.dart';
import '../guidance/module_help.dart';
import '../todo/widget/todo_widget_permissions.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/dialogs.dart';
import '../notes/note_model.dart';
import '../notes/note_editor_page.dart';
import '../notes/note_tag_store.dart';
import '../notes/note_tag_picker.dart';
import '../notes/note_service.dart';
import '../notes/widget/notes_widget_bridge.dart';
import '../notes/notes_changes.dart';
import '../notes/note_widget_permission_store.dart';
import '../todo/todo_editor_page.dart';
import '../todo/todo_card_surface.dart';
import '../todo/todo_changes.dart';
import '../todo/reminders/todo_bridge.dart';
import '../todo/reminders/todo_settings_page.dart';
import '../todo/todo_presentation.dart';
import 'collection_repository.dart';
import '../templates/template_catalog.dart';
import '../templates/template_page.dart';
import '../templates/task_templates_page.dart';
import '../templates/task_template_store.dart';
import '../todo/todo_project_store.dart';
import '../todo/todo_project_editor.dart';

class CollectionPage extends StatefulWidget {
  final CollectionKind kind;
  final String? folderId;
  final String? folderName;
  final bool trash;
  final String? initialTagId;
  final CollectionRepository? repository;
  final bool initialSearch, tutorial;
  const CollectionPage({
    super.key,
    required this.kind,
    this.folderId,
    this.folderName,
    this.trash = false,
    this.initialTagId,
    this.repository,
    this.initialSearch = false,
    this.tutorial = false,
  });
  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final anchors = {
    for (final k in ['create', 'title', 'body', 'save', 'results'])
      k: GlobalKey(),
  };
  late final guide = GuideController(
    id: '${repo.notes ? 'notes' : 'tasks'}.create',
    steps: [
      const GuideStep('create', 'create', 'helpGuideCreate', event: 'opened'),
      const GuideStep(
        'title',
        'title',
        'helpGuideTitle',
        event: 'titleEntered',
        backBoundary: true,
      ),
      GuideStep(
        'body',
        'body',
        repo.notes ? 'helpGuideNoteBody' : 'helpGuideTaskBody',
        event: repo.notes ? 'bodyEntered' : null,
      ),
      GuideStep(
        'save',
        'save',
        repo.notes ? 'helpGuideNoteSave' : 'helpGuideTaskSave',
        event: 'saved',
      ),
      const GuideStep(
        'results',
        'results',
        'helpGuideResults',
        backBoundary: true,
      ),
    ],
  );
  Future<void> help() async {
    final choice = await showModuleHelp(
      context,
      repo.notes ? 'notes' : 'tasks',
    );
    if (!mounted) return;
    if (choice == 'tutorial') guide.start();
    if (choice == 'start') await edit();
    if (choice == 'templates') await fromTemplate();
    if (choice == 'results') {
      setState(() {
        filter = 'all';
        query = '';
        searchController.clear();
      });
      await load();
    }
  }

  late final CollectionRepository repo;
  CollectionRows? rows;
  bool failed = false, busy = false;
  String query = '', filter = 'all';
  String? selectedTagId;
  List<NoteTag> tagLibrary = [];
  Map<String, bool> widgetPermissions = {};
  late String? name;
  TodoProject? get currentProject => rows?.projects[widget.folderId];
  Timer? debounce, timer;
  StreamSubscription<void>? notesChanges;
  final searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? CollectionRepository(widget.kind);
    selectedTagId = repo.notes ? widget.initialTagId : null;
    name = widget.folderName;
    load();
    if (widget.tutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) guide.start();
      });
    }
    {
      notesChanges = (repo.notes ? NotesChanges.events : TodoChanges.events)
          .listen((_) {
            if (mounted) unawaited(load());
          });
    }
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
    guide.dispose();
    debounce?.cancel();
    timer?.cancel();
    unawaited(notesChanges?.cancel());
    searchController.dispose();
    super.dispose();
  }

  int _request = 0;
  Future<void> load() async {
    final request = ++_request;
    try {
      final tags = repo.notes
          ? await NoteTagStore(await repo.database).all()
          : const <NoteTag>[];
      if (!mounted || request != _request) return;
      if (selectedTagId != null &&
          !tags.any((tag) => tag.id == selectedTagId)) {
        selectedTagId = null;
      }
      final result = await repo.load(
        folderId: widget.folderId,
        trash: widget.trash,
        query: query,
        filter: filter,
        tagId: selectedTagId,
      );
      final permissions = repo.notes
          ? await NoteWidgetPermissionStore(await repo.database)
                .allowed(result.items.map(Note.fromMap).toList())
          : await TodoWidgetPermissions.allowed(await repo.database);
      if (mounted && request == _request) {
        setState(() {
          rows = result;
          tagLibrary = tags;
          widgetPermissions = permissions;
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
    final notesService = repo.notes
        ? NoteService(database: await repo.database)
        : null;
    if (!mounted) return;
    final guided = guide.active && row == null;
    if (guided) guide.event('opened');
    final editor = repo.notes
        ? NoteEditorPage(
            note: row == null ? null : Note.fromMap(row),
            folderId: widget.folderId,
            service: notesService,
            guide: guided ? guide : null,
            guideTargets: guided ? anchors : const {},
          )
        : TodoEditorPage(
            todo: row,
            folderId: widget.folderId,
            database: repo.provided,
            guide: guided ? guide : null,
            guideTargets: guided ? anchors : const {},
          );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => guided
            ? GuideHost(controller: guide, targets: anchors, child: editor)
            : editor,
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
          repository: repo,
        ),
      ),
    );
    await load();
  }

  Future<void> fromTemplate() async {
    final language = Localizations.localeOf(context).languageCode;
    if (!repo.notes) {
      final db = await repo.database;
      if (!mounted) return;
      final choice = await Navigator.push<TaskTemplateChoice>(
        context,
        MaterialPageRoute(builder: (_) => TaskTemplatesPage(database: db)),
      );
      if (choice == null || !mounted) return;
      Map<String, Object?>? created;
      await run(() async {
        created = choice.customId != null
            ? await TaskTemplateStore(db)
                  .instantiate(choice.customId!, folderId: widget.folderId)
            : await repo.createFromTemplate(
                choice.preset!,
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
      if (created != null && mounted) {
        if (choice.customId != null) {
          await edit(created);
        } else {
          await folder(created!);
        }
      }
      return;
    }
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

  Future<void> editProject({
    Map<String, Object?>? row,
    bool create = false,
  }) async {
    try {
      final db = await repo.database;
      final id = create ? null : row?['id'] as String? ?? widget.folderId;
      final folder = id == null
          ? null
          : (await db.query(
              'todo_folders',
              where: 'id=?',
              whereArgs: [id],
            )).single;
      final project = id == null
          ? null
          : (await TodoProjectStore(db).all())[id];
      if (!mounted) return;
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => TodoProjectEditor(
            database: db,
            project: project,
            folder: folder,
            parentId: create ? widget.folderId : null,
          ),
        ),
      );
      if (result == null || !mounted) return;
      await load();
      final saved = (await db.query(
        'todo_folders',
        where: 'id=?',
        whereArgs: [result],
      )).single;
      if (!mounted) return;
      if (widget.folderId == result) {
        setState(() => name = saved['name'] as String);
      }
      if (create) await this.folder(saved);
    } catch (_) {
      if (mounted) showError(context);
    }
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
      case 'taskProjectDetails':
        await editProject(row: row);
        break;
      case 'taskProjectRemove':
        final project = rows?.projects[id];
        if (project != null &&
            await confirm(context, context.tr('taskProjectRemoveInfo')) &&
            mounted) {
          await run(() async {
            await TodoProjectStore(await repo.database).removeMarker(project);
          });
        }
        break;
      case 'rename':
        final text = await askText(
          context,
          context.tr('rename'),
          initial: row['name'] as String,
        );
        if (text != null) await run(() => repo.renameFolder(id, text));
        break;
      case 'taskDuplicate':
        await run(() async {
          await repo.duplicateTask(id);
        });
        break;
      case 'taskTemplateSave':
        try {
          final store = TaskTemplateStore(await repo.database);
          final initial = await store.fromTask(id);
          if (!mounted) return;
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TaskTemplateEditor(store: store, initial: initial),
            ),
          );
        } catch (_) {
          if (mounted) showError(context);
        }
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
        final store = NoteTagStore(await repo.database);
        final current = await store.forNote(id);
        if (!mounted) return;
        final picked = await showNoteTagPicker(
          context,
          store,
          selected: current.map((t) => t.id).toList(),
        );
        if (picked != null) {
          await run(() async {
            final db = await repo.database;
            await db.transaction(
              (txn) => NoteTagStore.assign(
                txn,
                id,
                ids: picked.map((t) => t.id).toList(),
              ),
            );
            NotesChanges.committed();
          });
        } else {
          await load(); // Global rename/delete persists even when selection cancels.
        }
        break;
    }
  }

  Widget todoSurface(Map<String, Object?> row, Widget child) => repo.notes
      ? child
      : TodoCardSurface(
          color: todoColor(
            row,
            DateTime.now(),
            dark: Theme.of(context).brightness == Brightness.dark,
          ),
          child: child,
        );

  Future<void> allowWidget(Map<String, Object?> row, bool enabled) async {
    if (enabled &&
        !await confirm(
          context,
          context.tr('widgetPrivacyInfo'),
          title: context.tr('widgetAllow'),
        )) {
      return;
    }
    if (!mounted) return;
    await run(() async {
      if (repo.notes) {
        await NoteWidgetPermissionStore(await repo.database)
            .setAllowed(Note.fromMap(row), enabled);
      } else {
        await TodoWidgetPermissions.set(await repo.database, row, enabled);
      }
    });
  }

  Widget? projectSubtitle(Map<String, Object?> row) {
    final project = rows?.projects[row['id']];
    if (project == null) return null;
    final progress = rows!.projectProgress[project.folderId];
    final local = MaterialLocalizations.of(context);
    return Text(
      '${context.tr(taskProjectStatusKey(project.status))} · ${local.formatDecimal(progress?.done ?? 0)} / ${local.formatDecimal(progress?.total ?? 0)}',
    );
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
                  if (folder && !repo.notes) 'taskProjectDetails',
                  if (folder &&
                      !repo.notes &&
                      rows?.projects[row['id']] != null)
                    'taskProjectRemove',
                  if (!folder && !repo.notes) 'taskDuplicate',
                  if (!folder && !repo.notes) 'taskTemplateSave',
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
  void filterByTag(String id) {
    debounce?.cancel();
    searchController.clear();
    setState(() {
      selectedTagId = id;
      query = '';
      filter = 'all';
    });
    load();
  }

  Future<void> pickTagFilter() async {
    final store = NoteTagStore(await repo.database);
    if (!mounted) return;
    final picked = await showNoteTagPicker(
      context,
      store,
      selected: [?selectedTagId],
      single: true,
    );
    final all = await store.all();
    if (!mounted) return;
    setState(() {
      selectedTagId = picked != null
          ? (picked.isEmpty ? null : picked.single.id)
          : all.any((t) => t.id == selectedTagId)
          ? selectedTagId
          : null;
    });
    await load();
  }

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
    return GuideHost(
      controller: guide,
      targets: anchors,
      child: Scaffold(
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
                key: const Key('collection-module-help'),
                tooltip: context.tr('gHelp'),
                icon: const Icon(Icons.help_outline),
                onPressed: busy ? null : help,
              ),
            if (!repo.notes && !widget.trash)
              IconButton(
                tooltip: context.tr('reminderSettings'),
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TodoSettingsPage()),
                ),
              ),
            if (!repo.notes && !widget.trash && widget.folderId == null)
              IconButton(
                tooltip: context.tr('widgetTodo'),
                icon: const Icon(Icons.widgets_outlined),
                onPressed: () async {
                  try {
                    final ok = await TodoBridge.channel.invokeMethod<bool>(
                      'requestPin',
                    );
                    if (ok != true && context.mounted) showError(context);
                  } catch (_) {
                    if (context.mounted) showError(context);
                  }
                },
              ),
            if (repo.notes && !widget.trash && widget.folderId == null)
              IconButton(
                tooltip: context.tr('widgetNotes'),
                icon: const Icon(Icons.widgets_outlined),
                onPressed: () async {
                  try {
                    final ok = await NotesWidgetBridge.channel
                        .invokeMethod<bool>('requestPin');
                    if (ok != true && context.mounted) showError(context);
                  } catch (_) {
                    if (context.mounted) showError(context);
                  }
                },
              ),
            if (!widget.trash)
              IconButton(
                tooltip: context.tr('trash'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CollectionPage(
                        kind: widget.kind,
                        trash: true,
                        repository: repo,
                      ),
                    ),
                  );
                  await load();
                },
              ),
            if (widget.folderId != null)
              PopupMenuButton<String>(
                key: const Key('collection-folder-actions'),
                onSelected: (key) async {
                  final row = {'id': widget.folderId, 'name': name};
                  if (key == 'rename') {
                    final text = await askText(
                      context,
                      context.tr('rename'),
                      initial: name ?? '',
                    );
                    if (text != null) {
                      await run(
                        () => repo.renameFolder(widget.folderId!, text),
                      );
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
                          : [
                              'rename',
                              if (!repo.notes) 'taskProjectDetails',
                              if (!repo.notes && currentProject != null)
                                'taskProjectRemove',
                              'move',
                              'trash',
                            ])
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
                autofocus: repo.notes && widget.initialSearch,
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
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: InputChip(
                        avatar: const Icon(Icons.label_outline, size: 18),
                        label: Text(
                          tagLibrary
                                  .where((t) => t.id == selectedTagId)
                                  .firstOrNull
                                  ?.name ??
                              context.tr('tags'),
                        ),
                        selected: selectedTagId != null,
                        onPressed: busy ? null : pickTagFilter,
                        onDeleted: selectedTagId == null
                            ? null
                            : () {
                                setState(() => selectedTagId = null);
                                load();
                              },
                      ),
                    ),
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
            if (!widget.trash &&
                ((!repo.notes && filter != 'all') ||
                    (repo.notes && selectedTagId != null)))
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
              key: anchors['results'],
              child: failed
                  ? Center(
                      child: TextButton(
                        onPressed: load,
                        child: Text(context.tr('retry')),
                      ),
                    )
                  : rows == null
                  ? const Center(child: CircularProgressIndicator())
                  : rows!.folders.isEmpty &&
                        visibleItems.isEmpty &&
                        currentProject == null
                  ? Center(child: Text(context.tr('empty')))
                  : RefreshIndicator(
                      onRefresh: load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                        children: [
                          if (currentProject case final project?)
                            TodoProjectSummary(
                              project: project,
                              progress:
                                  rows!.projectProgress[project.folderId] ??
                                  (total: 0, done: 0, overdue: 0),
                              onEdit: widget.trash ? null : () => editProject(),
                            ),
                          if (currentProject != null &&
                              rows!.folders.isEmpty &&
                              visibleItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(context.tr('empty')),
                            ),
                          ...rows!.folders.map(
                            (row) => Card(
                              child: ListTile(
                                leading: Icon(
                                  rows!.projects.containsKey(row['id'])
                                      ? Icons.work_outline
                                      : Icons.folder_outlined,
                                  color: scheme.primary,
                                ),
                                title: Text(row['name'] as String),
                                subtitle: projectSubtitle(row),
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
                                        color: todoColor(
                                          row,
                                          now,
                                          dark:
                                              Theme.of(context).brightness ==
                                              Brightness.dark,
                                        ),
                                        width: 1.5,
                                      ),
                                    ),
                              child: todoSurface(
                                row,
                                ListTile(
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
                                      decoration:
                                          !repo.notes && row['is_done'] == 1
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  subtitle: repo.notes
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              row['body'] as String,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            NoteTagChips(
                                              names: NoteTagStore.legacyNames(
                                                row['tags'],
                                              ),
                                              ids: NoteTagStore.legacyNames(
                                                row['tag_ids'],
                                              ),
                                              onSelected: widget.trash
                                                  ? null
                                                  : filterByTag,
                                            ),
                                            if (!widget.trash)
                                              SwitchListTile.adaptive(
                                                key: ValueKey(
                                                  'widget-allow-${row['id']}',
                                                ),
                                                contentPadding: EdgeInsets.zero,
                                                dense: true,
                                                title: Text(
                                                  context.tr('widgetAllow'),
                                                ),
                                                value:
                                                    widgetPermissions[row['id']] ==
                                                    true,
                                                onChanged: busy
                                                    ? null
                                                    : (v) =>
                                                          allowWidget(row, v),
                                              ),
                                          ],
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${context.tr(['normal', 'important', 'veryImportant', 'critical'][(row['priority'] as int? ?? 0).clamp(0, 3).toInt()])}${row['is_done'] == 1 ? '' : '\n${dueText(row)}'}',
                                            ),
                                            if (rows?.checklistProgress[row['id']]
                                                case final progress?) ...[
                                              Text(
                                                '${context.tr('taskChecklist')}: ${MaterialLocalizations.of(context).formatDecimal(progress.done)} / ${MaterialLocalizations.of(context).formatDecimal(progress.total)}',
                                              ),
                                              LinearProgressIndicator(
                                                value:
                                                    progress.done /
                                                    progress.total,
                                                semanticsLabel: context.tr(
                                                  'taskChecklist',
                                                ),
                                              ),
                                            ],
                                            if (!widget.trash)
                                              SwitchListTile.adaptive(
                                                key: ValueKey(
                                                  'widget-allow-${row['id']}',
                                                ),
                                                contentPadding: EdgeInsets.zero,
                                                dense: true,
                                                title: Text(
                                                  context.tr('widgetAllow'),
                                                ),
                                                value:
                                                    widgetPermissions[row['id']] ==
                                                    true,
                                                onChanged: busy
                                                    ? null
                                                    : (v) =>
                                                          allowWidget(row, v),
                                              ),
                                          ],
                                        ),
                                  onTap: () => edit(row),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [menu(row, false)],
                                  ),
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
                key: anchors['create'],
                tooltip: context.tr('add'),
                onPressed: busy
                    ? null
                    : () async {
                        if (guide.active) {
                          await edit();
                          return;
                        }
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
                                if (!repo.notes)
                                  ListTile(
                                    leading: const Icon(Icons.work_outline),
                                    title: Text(c.tr('taskProjectNew')),
                                    onTap: () => Navigator.pop(c, 'project'),
                                  ),
                              ],
                            ),
                          ),
                        );
                        if (!mounted) return;
                        if (choice == 'item') await edit();
                        if (choice == 'folder') await createFolder();
                        if (choice == 'template') await fromTemplate();
                        if (choice == 'project') {
                          await editProject(create: true);
                        }
                      },
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}
