import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/editor_form.dart';
import '../../core/strings.dart';
import '../agent/agent_access.dart';
import '../agent/purchase_panel.dart';
import '../attachments/attachment_store.dart';
import '../attachments/attachments_page.dart';
import '../guidance/guide_controller.dart';
import '../guidance/guide_host.dart';
import '../modules/module_data.dart';
import '../private_space/record_store.dart';
import '../search/library_page.dart';
import '../search/search_repository.dart';
import 'experience_model.dart';
import '../voice/voice_screen_host.dart';
import 'experience_store.dart';
import 'experience_editor.dart';
import 'experience_links.dart';

class ExperiencePage extends StatefulWidget {
  final PrivateRecord record;
  final ExperienceStore? store;
  final AgentAccess? access;
  final bool readOnly;
  final GuideController? guide;
  final Map<String, GlobalKey> anchors;
  const ExperiencePage({
    super.key,
    required this.record,
    this.store,
    this.access,
    this.readOnly = false,
    this.guide,
    this.anchors = const {},
  });
  @override
  State<ExperiencePage> createState() => _ExperiencePageState();
}

class _ExperiencePageState extends State<ExperiencePage> {
  late final store = widget.store ?? ExperienceStore();
  late PrivateRecord entry = widget.record;
  AgentAccess get access => widget.access ?? AgentAccess.instance;
  Map<String, String> categories = {};
  List<Map<String, Object?>> links = [];
  bool busy = false;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final c = await store.categories(),
          l = await ExperienceLinks(store).all(entry.id);
      if (mounted) {
        setState(() {
          categories = c;
          links = l;
        });
      }
    } catch (_) {
      if (mounted) failure(context);
    }
  }

  Future<bool> allowed() async {
    if (widget.readOnly) return false;
    if (access.has(AgentAccess.core)) return true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PurchasePanel(product: AgentAccess.core, access: access),
    );
    return access.has(AgentAccess.core);
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) await refresh();
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit() async {
    if (!await allowed() || !mounted) return;
    final original = entry;
    final saved = await Navigator.push<PrivateRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => ExperienceEditor(
          initial: entry.data,
          editing: true,
          categories: categories,
          onSave: (data) async {
            if (!access.has(AgentAccess.core)) {
              throw StateError('access_expired');
            }
            return store.records.save('experience', data, previous: original);
          },
        ),
      ),
    );
    if (saved != null && mounted) setState(() => entry = saved);
  }

  String readable(Map<String, dynamic> data) => [
    data['title'],
    if (data['date'] != null) data['date'],
    for (final k in ExperienceModel.fields)
      if ('${data[k] ?? ''}'.isNotEmpty)
        '${context.tr('eField_$k')}\n${data[k]}',
    if ((data['tags'] as List? ?? []).isNotEmpty)
      '${context.tr('eTags')}: ${(data['tags'] as List).join(', ')}',
  ].join('\n\n');
  Future<void> history() async {
    var offset = 0;
    var selecting = false;
    var versions = await store.history(entry.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, change) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(c).height * .85,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(c.tr('eHistory'), style: Theme.of(c).textTheme.titleLarge),
                Text(c.tr('eHistoryHint')),
                for (final row in versions)
                  ListTile(
                    title: Text(
                      '${c.tr('eRevision')} ${row['entry_revision']}',
                    ),
                    subtitle: Text(row['created_at'] as String),
                    onTap: selecting
                        ? null
                        : () async {
                            change(() => selecting = true);
                            try {
                              final source = await (await store.db).query(
                                'module_data',
                                where: "id=? AND owner=? AND module='experience' AND kind='history'",
                                whereArgs: [row['id'], entry.id],
                                limit: 1,
                              );
                              if (source.isEmpty || !c.mounted) return;
                              final snapshot = Map<String, dynamic>.from(
                                ModuleData.decode(source.single)['snapshot'],
                              );
                              final restore = await showDialog<bool>(
                                context: c,
                                builder: (d) => AlertDialog(
                                  title: Text(d.tr('eHistory')),
                                  content: SingleChildScrollView(
                                    child: SelectableText(readable(snapshot)),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: Text(d.tr('close')),
                                    ),
                                    if (!widget.readOnly)
                                      FilledButton(
                                        onPressed: () => Navigator.pop(d, true),
                                        child: Text(d.tr('restore')),
                                      ),
                                  ],
                                ),
                              );
                              if (restore == true &&
                                  c.mounted &&
                                  await allowed()) {
                                if (!access.has(AgentAccess.core)) {
                                  throw StateError('access_expired');
                                }
                                final saved = await store.restore(entry, row);
                                if (mounted) setState(() => entry = saved);
                                if (c.mounted) Navigator.pop(c);
                              }
                            } catch (_) {
                              if (c.mounted) failure(c);
                            } finally {
                              if (c.mounted) change(() => selecting = false);
                            }
                          },
                  ),
                if (versions.length == offset + 30)
                  TextButton(
                    onPressed: selecting
                        ? null
                        : () async {
                            change(() => selecting = true);
                            try {
                              final next = await store.history(
                                entry.id,
                                offset: offset + 30,
                              );
                              if (c.mounted) {
                                change(() {
                                  offset += 30;
                                  versions = [...versions, ...next];
                                });
                              }
                            } catch (_) {
                              if (c.mounted) failure(c);
                            } finally {
                              if (c.mounted) change(() => selecting = false);
                            }
                          },
                    child: Text(c.tr('continue')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> task() async {
    if (!await allowed() || !mounted) return;
    final followups = (await ExperienceLinks(store).all(entry.id)).where((r) {
      final d = ModuleData.decode(r);
      return d['targetKind'] == 'todo' && d['action'] == 'followup';
    }).toList();
    if (followups.isNotEmpty) {
      final row = followups.single, data = ModuleData.decode(row);
      if (data['state'] == 'pending') {
        await ExperienceLinks(store).task(
          entry,
          title: entry.data['title'],
          body: '',
          allowed: () => access.has(AgentAccess.core),
        );
        if (!mounted) return;
        final ready = (await ExperienceLinks(store).all(entry.id))
            .firstWhere((r) => r['id'] == row['id']);
        if (mounted) await openLink(ready);
      } else {
        await openLink(row);
      }
      return;
    }
    if (!mounted) return;
    final proposed = '${entry.data['next'] ?? ''}'.trim().split('\n').first;
    await editFields(
      context,
      context.tr('eFollowup'),
      {
        'title': context.tr('title'),
        'body': context.tr('notes'),
        'due': context.tr('due'),
      },
      initial: {
        'title': proposed.isNotEmpty && proposed.length <= 200
            ? proposed
            : entry.data['title'],
        'body': readable(entry.data),
        'due': '',
      },
      requiredFields: {'title'},
      multiline: {'body'},
      dateFields: {'due'},
      onSave: (v) async {
        await ExperienceLinks(store).task(
          entry,
          title: v['title']!,
          body: v['body']!,
          due: DateTime.tryParse(v['due']!),
          allowed: () => access.has(AgentAccess.core),
        );
      },
    );
  }

  Future<void> attach() async {
    if (!await allowed() || !mounted) return;
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final k in ['note', 'book', 'habit'])
              ListTile(
                title: Text(c.tr(kindKey(k))),
                onTap: () => Navigator.pop(c, k),
              ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final target = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _TargetPicker(store: store, kind: kind),
      ),
    );
    if (target != null) {
      await ExperienceLinks(store).attach(
        entry.id,
        kind,
        target,
        allowed: () => access.has(AgentAccess.core),
      );
    }
  }

  Future<void> openLink(Map<String, Object?> row) async {
    final data = ModuleData.decode(row);
    final kind = data['targetKind'] as String, id = data['target'] as String;
    final repo = SearchRepository(notesDb: await store.db, todoDb: store.tasks);
    if (!mounted) return;
    final hit = SearchHit(id, kind, context.tr(kindKey(kind)), '', '', false);
    if (await repo.source(hit) == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('eLinkMissing'))));
      }
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPage(
          hit: hit,
          repository: repo,
          readOnly: widget.readOnly || !access.has(AgentAccess.core),
        ),
      ),
    );
  }

  Future<void> menu(String action) async {
    if (!mounted) return;
    if (action == 'attachments') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttachmentsPage(
            kind: 'experience',
            owner: entry.id,
            title: entry.data['title'],
            store: store.records,
          ),
        ),
      );
    } else if (action == 'export') {
      final text = readable(entry.data);
      if (await consent(context, context.tr('xPlainExport'))) {
        await Attachments.export(
          'Bilga-experience.txt',
          'text/plain',
          Stream.value(utf8.encode(text)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final data = entry.data;
    final body = Scaffold(
      appBar: AppBar(
        title: Text(data['title']),
        actions: [
          if (!widget.readOnly)
            IconButton(
              key: const Key('experience-edit'),
              tooltip: c.tr('edit'),
              onPressed: busy ? null : () => run(edit),
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            key: const Key('experience-history'),
            tooltip: c.tr('eHistory'),
            onPressed: busy ? null : () => run(history),
            icon: const Icon(Icons.history),
          ),
          if (!widget.readOnly)
            IconButton(
              key: const Key('experience-favorite'),
              tooltip: c.tr('favorites'),
              onPressed: busy
                  ? null
                  : () => run(() async {
                      if (!await allowed()) return;
                      if (!access.has(AgentAccess.core)) {
                        throw StateError('access_expired');
                      }
                      final saved = await store.records.save('experience', {
                        ...data,
                        'favorite': data['favorite'] != true,
                      }, previous: entry);
                      if (mounted) setState(() => entry = saved);
                    }),
              icon: Icon(
                data['favorite'] == true ? Icons.star : Icons.star_border,
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (v) => run(() => menu(v)),
            itemBuilder: (c) => [
              if (!widget.readOnly)
                PopupMenuItem(
                  value: 'attachments',
                  child: Text(c.tr('eAttachments')),
                ),
              const PopupMenuItem(value: 'export', child: Text('TXT')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            key: widget.anchors['results'],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data['date'] ?? ''} · ${categories[data['category']] ?? (ExperienceModel.categories.contains(data['category'] ?? 'life') ? c.tr('x${data['category'] ?? 'life'}') : c.tr('eCategoryUnavailable'))}',
                  ),
                  Text(c.tr('eStatus_${data['status'] ?? 'active'}')),
                  if ((data['tags'] as List? ?? []).isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final tag in data['tags']) Chip(label: Text(tag)),
                      ],
                    ),
                  for (final k in ExperienceModel.fields)
                    if ('${data[k] ?? ''}'.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.tr('eField_$k'),
                              style: Theme.of(c).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            SelectableText(data[k]),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          if (!widget.readOnly)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('experience-task'),
                  onPressed: busy ? null : () => run(task),
                  icon: const Icon(Icons.add_task),
                  label: Text(c.tr('eFollowup')),
                ),
                OutlinedButton.icon(
                  key: const Key('experience-link'),
                  onPressed: busy ? null : () => run(attach),
                  icon: const Icon(Icons.link),
                  label: Text(c.tr('eLink')),
                ),
              ],
            ),
          if (links.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                c.tr('eLinked'),
                style: Theme.of(c).textTheme.titleLarge,
              ),
            ),
          for (final row in links)
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(c.tr(kindKey(ModuleData.decode(row)['targetKind']))),
              subtitle: ModuleData.decode(row)['state'] == 'pending'
                  ? Text(c.tr('ePendingLink'))
                  : null,
              onTap: () => run(() => openLink(row)),
            ),
          const SizedBox(height: 60),
        ],
      ),
    );
    return VoiceReadRegion(
      read: () => readable(entry.data),
      child: widget.guide == null
          ? body
          : GuideHost(
              controller: widget.guide!,
              targets: widget.anchors,
              child: body,
            ),
    );
  }
}

class _TargetPicker extends StatefulWidget {
  final ExperienceStore store;
  final String kind;
  const _TargetPicker({required this.store, required this.kind});
  @override
  State<_TargetPicker> createState() => _TargetPickerState();
}

class _TargetPickerState extends State<_TargetPicker> {
  List<Map<String, Object?>> rows = [];
  String query = '';
  int generation = 0;
  bool more = false, loading = true, failed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool append = false}) async {
    final g = ++generation, db = await widget.store.db;
    try {
      final table = widget.kind == 'note'
          ? 'notes'
          : widget.kind == 'habit'
          ? 'habits'
          : 'private_records';
      final where = widget.kind == 'note'
          ? 'is_deleted=0'
          : widget.kind == 'book'
          ? "kind='book'"
          : '1';
      final title = widget.kind == 'book'
          ? "json_extract(payload,'\$.title')"
          : 'title';
      final escaped = query
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      final found = await db.rawQuery(
        "SELECT id,$title AS title FROM $table WHERE $where AND $title LIKE ? ESCAPE '\\' ORDER BY title,id LIMIT 50 OFFSET ?",
        ['%$escaped%', append ? rows.length : 0],
      );
      if (mounted && g == generation) {
        setState(() {
          rows = append ? [...rows, ...found] : found;
          more = found.length == 50;
          loading = false;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted && g == generation) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(c.tr('eLink'))),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(labelText: c.tr('search')),
            onChanged: (v) {
              query = v;
              load();
            },
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        if (failed) TextButton(onPressed: load, child: Text(c.tr('retry'))),
        Expanded(
          child: ListView(
            children: [
              for (final row in rows)
                ListTile(
                  title: Text(row['title'] as String),
                  onTap: () => Navigator.pop(c, row['id']),
                ),
              if (more)
                TextButton(
                  onPressed: () => load(append: true),
                  child: Text(c.tr('continue')),
                ),
              if (rows.isEmpty && !loading)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(c.tr('eNoLinkTargets')),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
