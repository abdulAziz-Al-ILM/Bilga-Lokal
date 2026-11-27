import 'rich_note_widgets.dart';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/dialogs.dart';
import 'note_model.dart';
import 'note_service.dart';
import 'note_version_model.dart';

class NoteHistoryPage extends StatefulWidget {
  final Note note;
  const NoteHistoryPage({super.key, required this.note});
  @override
  State<NoteHistoryPage> createState() => _NoteHistoryPageState();
}

class _NoteHistoryPageState extends State<NoteHistoryPage> {
  final service = NoteService();
  List<NoteVersion>? versions;
  Set<int> selected = {};
  final undo = <Set<int>>[], redo = <Set<int>>[];
  bool busy = false, allowPop = false, leaving = false, failed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await service.getNoteVersions(widget.note.id);
      if (mounted) {
        setState(() {
          versions = rows;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Set<int> get protected {
    final rows = versions ?? [];
    return {
      ...rows.take(2).map((v) => v.versionId!),
      ...rows.reversed.take(2).map((v) => v.versionId!),
    };
  }

  void select(Set<int> next) {
    undo.add({...selected});
    redo.clear();
    setState(() => selected = next);
  }

  Future<void> leave() async {
    if (busy || leaving) return;
    leaving = true;
    if (selected.isNotEmpty &&
        !await confirm(context, context.tr('discardChanges'))) {
      leaving = false;
      return;
    }
    if (!mounted) return;
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> restore(NoteVersion version) async {
    if (busy || !await confirm(context, context.tr('restoreConfirm'))) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final note = await service.restoreVersion(widget.note, version);
      if (!mounted) return;
      setState(() => allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, note);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showError(context);
      }
    }
  }

  Future<void> remove() async {
    if (busy ||
        selected.isEmpty ||
        !await confirm(context, context.tr('permanentConfirm'))) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await service.deleteSelectedVersions(
        noteId: widget.note.id,
        versionIds: selected.difference(protected),
      );
      selected.clear();
      undo.clear();
      redo.clear();
      await load();
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Note>(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('history')),
        leading: IconButton(
          onPressed: leave,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('undo'),
            icon: const Icon(Icons.undo),
            onPressed: busy || undo.isEmpty
                ? null
                : () {
                    redo.add({...selected});
                    setState(() => selected = undo.removeLast());
                  },
          ),
          IconButton(
            tooltip: context.tr('redo'),
            icon: const Icon(Icons.redo),
            onPressed: busy || redo.isEmpty
                ? null
                : () {
                    undo.add({...selected});
                    setState(() => selected = redo.removeLast());
                  },
          ),
          PopupMenuButton<String>(
            enabled: !busy,
            itemBuilder: (c) => ['selectAll', 'duplicates', 'clear']
                .map((k) => PopupMenuItem(value: k, child: Text(c.tr(k))))
                .toList(),
            onSelected: (key) {
              if (versions == null) return;
              if (key == 'clear') {
                select({});
                return;
              }
              final next = <int>{};
              final seen = <String>{};
              for (final v in versions!) {
                final signature =
                    '${v.title.length}:${v.title}${v.body.length}:${v.body}${v.richBody}';
                final duplicate = !seen.add(signature);
                if (!protected.contains(v.versionId) &&
                    (key == 'selectAll' || duplicate)) {
                  next.add(v.versionId!);
                }
              }
              select(next);
            },
          ),
          IconButton(
            tooltip: context.tr('deleteForever'),
            icon: const Icon(Icons.delete_outline),
            onPressed: busy || selected.isEmpty ? null : remove,
          ),
        ],
      ),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : failed
          ? Center(
              child: TextButton(
                onPressed: load,
                child: Text(context.tr('retry')),
              ),
            )
          : versions == null
          ? const Center(child: CircularProgressIndicator())
          : versions!.isEmpty
          ? Center(child: Text(context.tr('empty')))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: versions!
                  .map(
                    (v) => Card(
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: selected.contains(v.versionId),
                            onChanged: protected.contains(v.versionId)
                                ? null
                                : (checked) {
                                    final next = {...selected};
                                    if (checked == true) {
                                      next.add(v.versionId!);
                                    } else {
                                      next.remove(v.versionId);
                                    }
                                    select(next);
                                  },
                            title: Text(
                              v.title.isEmpty
                                  ? context.tr('untitled')
                                  : v.title,
                            ),
                            subtitle: v.richBody == null
                                ? Text(
                                    v.body,
                                    maxLines: 6,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : SizedBox(
                                    height: 140,
                                    child: SingleChildScrollView(
                                      child: RichNoteReader(
                                        body: v.body,
                                        richBody: v.richBody,
                                      ),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                if (protected.contains(v.versionId))
                                  const Icon(Icons.lock_outline, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${MaterialLocalizations.of(context).formatMediumDate(v.createdAt)} ${TimeOfDay.fromDateTime(v.createdAt).format(context)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => restore(v),
                                  icon: const Icon(Icons.restore),
                                  label: Text(context.tr('restore')),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    ),
  );
}
