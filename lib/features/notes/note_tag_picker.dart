import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/dialogs.dart';
import '../../core/strings.dart';
import 'note_tag_store.dart';

Future<List<NoteTag>?> showNoteTagPicker(
  BuildContext context,
  NoteTagStore store, {
  List<String> selected = const [],
  bool single = false,
}) => showDialog<List<NoteTag>>(
  context: context,
  builder: (_) => _TagPicker(store: store, selected: selected, single: single),
);

/// One compact library serves editing, filtering and tag management.
class _TagPicker extends StatefulWidget {
  final NoteTagStore store;
  final List<String> selected;
  final bool single;
  const _TagPicker({
    required this.store,
    required this.selected,
    required this.single,
  });
  @override
  State<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<_TagPicker> {
  final input = TextEditingController();
  late final Set<String> selected = widget.selected.toSet();
  List<NoteTag>? tags;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final all = await widget.store.all();
      if (mounted) {
        setState(() {
          tags = all;
          selected.removeWhere((id) => !all.any((t) => t.id == id));
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'error');
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      await load();
    } on TagNameException catch (e) {
      if (mounted) setState(() => error = e.messageKey);
    } catch (_) {
      if (mounted) setState(() => error = 'error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void toggle(NoteTag tag) => setState(() {
    if (selected.remove(tag.id)) return;
    if (widget.single) selected.clear();
    selected.add(tag.id);
  });
  Future<void> create() => run(() async {
    final tag = await widget.store.create(input.text);
    if (widget.single) selected.clear();
    selected.add(tag.id);
    if (mounted) input.clear();
  });
  Future<void> manage(NoteTag tag, String action) async {
    if (action == 'rename') {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => _TagRenameDialog(name: tag.name),
      );
      if (name != null) await run(() => widget.store.rename(tag.id, name));
    } else if (await confirm(
      context,
      context.tr('tagDeleteConfirm'),
      title: tag.name,
    )) {
      await run(() => widget.store.delete(tag.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = NoteTagStore.normalizeName(input.text);
    final visible =
        tags
            ?.where((t) => NoteTagStore.normalizeName(t.name).contains(query))
            .toList() ??
        [];
    return Dialog(
      child: SizedBox(
        width: 440,
        height: min(480, MediaQuery.sizeOf(context).height * .75),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('tags'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('tag-search'),
                controller: input,
                maxLength: 80,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                onChanged: (_) => setState(() => error = null),
                onSubmitted: (_) => input.text.trim().isEmpty ? null : create(),
                decoration: InputDecoration(
                  hintText: context.tr('tagName'),
                  prefixIcon: const Icon(Icons.search),
                  counterText: '',
                  suffixIcon: IconButton(
                    tooltip: context.tr('add'),
                    icon: const Icon(Icons.add),
                    onPressed: busy || input.text.trim().isEmpty
                        ? null
                        : create,
                  ),
                ),
              ),
              if (error != null)
                Text(
                  context.tr(error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (busy) const LinearProgressIndicator(),
              Expanded(
                child: tags == null && error == null
                    ? const Center(child: CircularProgressIndicator())
                    : visible.isEmpty
                    ? Center(child: Text(context.tr('empty')))
                    : ListView(
                        children: visible
                            .map(
                              (tag) => CheckboxListTile(
                                key: ValueKey('tag-${tag.id}'),
                                value: selected.contains(tag.id),
                                onChanged: busy ? null : (_) => toggle(tag),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  tag.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                secondary: PopupMenuButton<String>(
                                  enabled: !busy,
                                  onSelected: (action) => manage(tag, action),
                                  itemBuilder: (c) =>
                                      ['rename', 'deleteForever']
                                          .map(
                                            (key) => PopupMenuItem(
                                              value: key,
                                              child: Text(c.tr(key)),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: Text(context.tr('cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: tags == null || busy
                        ? null
                        : () => Navigator.pop(
                            context,
                            tags!
                                .where((t) => selected.contains(t.id))
                                .toList(),
                          ),
                    child: Text(context.tr('save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagRenameDialog extends StatefulWidget {
  final String name;
  const _TagRenameDialog({required this.name});

  @override
  State<_TagRenameDialog> createState() => _TagRenameDialogState();
}

class _TagRenameDialogState extends State<_TagRenameDialog> {
  late final controller = TextEditingController(text: widget.name);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr('rename')),
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: 80,
      decoration: InputDecoration(hintText: context.tr('tagName')),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('cancel')),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: Text(context.tr('save')),
      ),
    ],
  );
}

/// Horizontal chips keep cards compact even when a note has many tags.
class NoteTagChips extends StatelessWidget {
  final List<String> names;
  final List<String>? ids;
  final ValueChanged<String>? onSelected, onRemoved;
  const NoteTagChips({
    super.key,
    required this.names,
    this.ids,
    this.onSelected,
    this.onRemoved,
  });
  @override
  Widget build(BuildContext context) => names.isEmpty
      ? const SizedBox.shrink()
      : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < names.length; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: InputChip(
                    visualDensity: VisualDensity.compact,
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        '#${names[i]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    tooltip: names[i],
                    onPressed:
                        onSelected == null || ids == null || i >= ids!.length
                        ? null
                        : () => onSelected!(ids![i]),
                    onDeleted:
                        onRemoved == null || ids == null || i >= ids!.length
                        ? null
                        : () => onRemoved!(ids![i]),
                  ),
                ),
            ],
          ),
        );
}
