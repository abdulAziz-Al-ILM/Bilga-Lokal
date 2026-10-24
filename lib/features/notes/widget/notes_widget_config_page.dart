import '../note_widget_permission_store.dart';
import '../../../core/dialogs.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/settings.dart';
import '../../../core/strings.dart';
import '../note_database.dart';
import '../note_model.dart';
import '../note_tag_store.dart';
import 'notes_widget_bridge.dart';
import 'notes_widget_data.dart';
import 'notes_widget_sync.dart';
import 'notes_widget_loading.dart';

class NotesWidgetConfigPage extends StatefulWidget {
  final int widgetId;
  final NotesWidgetSync sync;
  final Database? database;
  final Future<Database> Function()? databaseLoader;
  final bool Function()? canRead;
  const NotesWidgetConfigPage({
    super.key,
    required this.widgetId,
    required this.sync,
    this.database,
    this.databaseLoader,
    this.canRead,
  });
  @override
  State<NotesWidgetConfigPage> createState() => _NotesWidgetConfigPageState();
}

class _NotesWidgetConfigPageState extends State<NotesWidgetConfigPage>
    with WidgetsBindingObserver {
  WidgetSource source = WidgetSource.recent;
  WidgetPrivacy privacy = WidgetPrivacy.hidden;
  String? tagId;
  final pinned = <String>{};
  String query = '';
  Map<String, bool> grants = {};
  Timer? debounce;
  List<NoteTag> tags = [];
  List<Note>? notes;
  bool busy = false, loading = false, configLoaded = false;
  String? error;
  int request = 0;
  Future<Database> get db async =>
      widget.database ??
      await (widget.databaseLoader?.call() ?? NoteDatabase.database);
  NotesWidgetConfig get config => NotesWidgetConfig(
    id: widget.widgetId,
    source: source,
    privacy: privacy,
    tagId: tagId,
    pinnedIds: pinned.toList(),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    request++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        error != null &&
        !loading &&
        !busy) {
      unawaited(load());
    }
  }

  bool get canRead => widget.canRead?.call() ?? true;

  Future<void> load() async {
    final current = ++request;
    if (!mounted) return;
    setState(() {
      loading = true;
      notes = null;
      error = null;
    });
    try {
      if (!canRead) throw StateError('locked');
      if (!configLoaded) {
        final configs = await NotesWidgetLoading.step(
          'config.store',
          NotesWidgetBridge.configs,
        );
        if (!mounted || current != request || !canRead) return;
        final old = configs
            .where((v) => v['id'] == widget.widgetId)
            .firstOrNull;
        if (old != null) {
          final value = NotesWidgetConfig.fromMap(old);
          source = value.source;
          privacy = value.privacy;
          tagId = value.tagId;
          pinned.addAll(value.pinnedIds);
        }
        configLoaded = true;
      }
      final database = await NotesWidgetLoading.step(
        'config.database',
        () => db,
      );
      final foundTags = await NotesWidgetLoading.step(
        'config.tags',
        () => NoteTagStore(database).all(),
      );
      if (!mounted || current != request || !canRead) return;
      tags = foundTags;
      if (!tags.any((t) => t.id == tagId)) tagId = null;
      final found = await NotesWidgetLoading.step(
        'config.notes',
        () =>
            NotesWidgetData(database)
                .available(config, choosing: true, query: query),
      );
      final permissions = await NotesWidgetLoading.step(
        'config.permissions',
        () => NoteWidgetPermissionStore(database).allowed(found),
      );
      if (mounted && current == request && canRead) {
        setState(() {
          notes = found;
          grants = permissions;
        });
      }
    } catch (_) {
      if (mounted && current == request) {
        setState(() => error = 'widgetNotesUnavailable');
      }
    } finally {
      if (mounted && current == request) {
        setState(() {
          loading = false;
          if (notes == null) error ??= 'widgetNotesUnavailable';
        });
      }
    }
  }

  Future<void> reload() => load();

  Future<void> save() async {
    if (busy || notes == null) return;
    setState(() => busy = true);
    try {
      await NotesWidgetLoading.step(
        'config.save',
        () => NotesWidgetBridge.channel.invokeMethod<void>('saveConfig', {
          ...config.toMap(),
          'approvals': <String, String>{},
        }),
      );
      await NotesWidgetLoading.step('config.export', widget.sync.refresh);
      await NotesWidgetLoading.step(
        'config.finish',
        () =>
            NotesWidgetBridge.channel.invokeMethod<void>('finishConfiguration'),
      );
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = 'saveError');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel() async {
    try {
      await NotesWidgetLoading.step(
        'config.cancel',
        () =>
            NotesWidgetBridge.channel.invokeMethod<void>('cancelConfiguration'),
      );
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !busy) cancel();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('widgetNotes')),
        leading: IconButton(
          onPressed: busy ? null : cancel,
          icon: const Icon(Icons.close),
          tooltip: context.tr('cancel'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<WidgetSource>(
            isExpanded: true,
            initialValue: source,
            key: ValueKey(source),
            decoration: InputDecoration(labelText: context.tr('widgetSource')),
            items: WidgetSource.values
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      context.tr(switch (v) {
                        WidgetSource.recent => 'widgetRecent',
                        WidgetSource.pinned => 'widgetPinned',
                        WidgetSource.tag => 'tags',
                      }),
                    ),
                  ),
                )
                .toList(),
            onChanged: busy || loading || !configLoaded
                ? null
                : (v) {
                    if (v != null) {
                      setState(() {
                        source = v;
                      });
                      reload();
                    }
                  },
          ),
          if (source == WidgetSource.tag)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DropdownButtonFormField<String>(
                initialValue: tagId,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.tr('tags')),
                items: tags
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: busy || loading || !configLoaded
                    ? null
                    : (v) {
                        setState(() {
                          tagId = v;
                        });
                        reload();
                      },
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<WidgetPrivacy>(
            isExpanded: true,
            initialValue: privacy,
            key: ValueKey(privacy),
            decoration: InputDecoration(labelText: context.tr('xPrivacy')),
            items: WidgetPrivacy.values
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      context.tr(switch (v) {
                        WidgetPrivacy.hidden => 'widgetHidden',
                        WidgetPrivacy.titles => 'widgetTitles',
                        WidgetPrivacy.preview => 'widgetPreview',
                      }),
                    ),
                  ),
                )
                .toList(),
            onChanged: busy || loading || !configLoaded
                ? null
                : (v) {
                    if (v != null) {
                      setState(() {
                        privacy = v;
                      });
                    }
                  },
          ),
          const SizedBox(height: 12),
          Text(context.tr('widgetPrivacyInfo')),
          const SizedBox(height: 8),
          Text(context.tr('widgetPermissionHint')),
          if (AppSettings.instance.appLock)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${context.tr('appLock')}: ${context.tr('widgetHidden')}',
              ),
            ),
          if (source == WidgetSource.pinned) ...[
            const SizedBox(height: 16),
            Text(
              context.tr('widgetPinned'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextField(
              decoration: InputDecoration(
                hintText: context.tr('search'),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: busy || loading || !configLoaded
                  ? null
                  : (value) {
                      query = value;
                      debounce?.cancel();
                      debounce = Timer(
                        const Duration(milliseconds: 250),
                        reload,
                      );
                    },
            ),
            if (notes != null && notes!.isEmpty) Text(context.tr('empty')),
            for (final note in notes ?? <Note>[])
              CheckboxListTile(
                key: ValueKey(note.id),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  note.title.isEmpty ? context.tr('untitled') : note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: privacy == WidgetPrivacy.preview
                    ? Text(
                        '${NotesWidgetData.excerpt(note.body, 240)}\n${note.tags.map((t) => '#$t').join(' ')}',
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                value: pinned.contains(note.id),
                onChanged:
                    busy ||
                        loading ||
                        (pinned.length >= 100 && !pinned.contains(note.id))
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          pinned.add(note.id);
                        } else {
                          pinned.remove(note.id);
                        }
                      }),
              ),
          ],
          Text(
            context.tr('widgetAllow'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final note in notes ?? <Note>[])
            SwitchListTile(
              title: Text(
                note.title.isEmpty ? context.tr('untitled') : note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  NotesWidgetData.excerpt(note.body, 240),
                  if (note.tags.isNotEmpty)
                    note.tags.take(3).map((t) => '#$t').join('  '),
                ].join('\n'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              value: grants[note.id] == true,
              onChanged: busy || loading || !configLoaded
                  ? null
                  : (v) async {
                      if (v &&
                          !await confirm(
                            context,
                            context.tr('widgetPrivacyInfo'),
                          )) {
                        return;
                      }
                      if (!mounted) return;
                      setState(() => busy = true);
                      try {
                        await NoteWidgetPermissionStore(await db)
                            .setAllowed(note, v);
                        if (v) privacy = WidgetPrivacy.preview;
                        await reload();
                      } catch (_) {
                        if (mounted) setState(() => error = 'saveError');
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
            ),
          if (loading && error == null)
            const Center(child: CircularProgressIndicator()),
          if (error != null) ...[
            Text(
              context.tr(error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton.icon(
              onPressed: busy || loading ? null : load,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('retry')),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                busy ||
                    loading ||
                    !canRead ||
                    notes == null ||
                    (source == WidgetSource.tag && tagId == null)
                ? null
                : save,
            child: Text(context.tr('save')),
          ),
        ],
      ),
    ),
  );
}
