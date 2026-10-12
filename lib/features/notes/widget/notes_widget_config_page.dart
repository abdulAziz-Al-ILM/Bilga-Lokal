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

class NotesWidgetConfigPage extends StatefulWidget {
  final int widgetId;
  final NotesWidgetSync sync;
  final Database? database;
  const NotesWidgetConfigPage({
    super.key,
    required this.widgetId,
    required this.sync,
    this.database,
  });
  @override
  State<NotesWidgetConfigPage> createState() => _NotesWidgetConfigPageState();
}

class _NotesWidgetConfigPageState extends State<NotesWidgetConfigPage> {
  WidgetSource source = WidgetSource.recent;
  WidgetPrivacy privacy = WidgetPrivacy.hidden;
  String? tagId;
  final pinned = <String>{};
  String query = '';
  Map<String, bool> grants = {};
  Timer? debounce;
  List<NoteTag> tags = [];
  List<Note>? notes;
  bool busy = false;
  String? error;
  int request = 0;
  Future<Database> get db async =>
      widget.database ?? await NoteDatabase.database;
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
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final configs = await NotesWidgetBridge.configs();
      final old = configs.where((v) => v['id'] == widget.widgetId).firstOrNull;
      if (old != null) {
        final value = NotesWidgetConfig.fromMap(old);
        source = value.source;
        privacy = value.privacy;
        tagId = value.tagId;
        pinned.addAll(value.pinnedIds);
      }
      tags = await NoteTagStore(await db).all();
      if (!tags.any((t) => t.id == tagId)) tagId = null;
      await reload();
    } catch (_) {
      if (mounted) setState(() => error = 'error');
    }
  }

  Future<void> reload() async {
    final current = ++request;
    if (mounted) {
      setState(() {
        notes = null;
        error = null;
      });
    }
    try {
      final found = await NotesWidgetData(await db)
          .available(config, choosing: true, query: query);
      final permissions = await NoteWidgetPermissionStore(await db)
          .allowed(found);
      if (mounted && current == request) {
        setState(() {
          notes = found;
          grants = permissions;
        });
      }
    } catch (_) {
      if (mounted && current == request) setState(() => error = 'error');
    }
  }

  Future<void> save() async {
    if (busy || notes == null) return;
    setState(() => busy = true);
    try {
      await NotesWidgetBridge.channel.invokeMethod<void>('saveConfig', {
        ...config.toMap(),
        'approvals': <String, String>{},
      });
      await widget.sync.refresh();
      await NotesWidgetBridge.channel.invokeMethod<void>('finishConfiguration');
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = 'saveError');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel() async {
    try {
      await NotesWidgetBridge.channel.invokeMethod<void>('cancelConfiguration');
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
            onChanged: busy
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
                onChanged: busy
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
            onChanged: busy
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
              onChanged: busy
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
                    busy || (pinned.length >= 100 && !pinned.contains(note.id))
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
                NotesWidgetData.excerpt(note.body, 240),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              value: grants[note.id] == true,
              onChanged: busy
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
          if (notes == null && error == null)
            const Center(child: CircularProgressIndicator()),
          if (error != null)
            Text(
              context.tr(error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                busy ||
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
