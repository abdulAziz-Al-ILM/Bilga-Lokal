import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/editor_form.dart';
import '../../core/strings.dart';
import 'organization_store.dart';

const _icons = [
  Icons.folder_outlined,
  Icons.work_outline,
  Icons.school_outlined,
  Icons.favorite_border,
  Icons.menu_book_outlined,
];
const _colors = [
  null,
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.red,
];

class FoldersPage extends StatefulWidget {
  final OrganizationStore store;
  final bool Function() allowed;
  final Future<void> Function(FolderItem) open;
  final FolderItem? moveItem;
  final String? sourceFolder;
  final String? ledger;
  const FoldersPage({
    super.key,
    required this.store,
    required this.allowed,
    required this.open,
    this.moveItem,
    this.ledger,
    this.sourceFolder,
  });

  @override
  State<FoldersPage> createState() => _FoldersState();
}

class _FoldersState extends State<FoldersPage> {
  final search = TextEditingController();
  final path = <RecordFolder>[];
  List<RecordFolder> all = [];
  List<FolderItem> items = [];
  Timer? debounce;
  int generation = 0;
  bool trash = false,
      latest = false,
      busy = false,
      failed = false,
      more = false;
  String? get folder => path.lastOrNull?.id;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool append = false}) async {
    final token = ++generation;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final folders = await widget.store.folders();
      final records = widget.moveItem != null || trash
          ? <FolderItem>[]
          : await widget.store.items(
              folder: folder,
              query: search.text,
              offset: append ? items.length : 0,
              ledger: widget.ledger,
            );
      if (!mounted || token != generation) return;
      setState(() {
        all = folders;
        items = [if (append) ...items, ...records.take(50)];
        more = records.length > 50;
      });
    } catch (_) {
      if (mounted && token == generation) setState(() => failed = true);
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  void navigate(List<RecordFolder> folders) {
    final next = folders.toList();
    path
      ..clear()
      ..addAll(next);
    search.clear();
    load();
  }

  List<RecordFolder> ancestors(RecordFolder folder) {
    final chain = [folder];
    final seen = {folder.id};
    var parent = folder.parent;
    while (parent.isNotEmpty && seen.add(parent)) {
      final row = all.where((f) => f.id == parent).firstOrNull;
      if (row == null) break;
      chain.insert(0, row);
      parent = row.parent;
    }
    return chain;
  }

  Future<void> edit([RecordFolder? row]) async {
    var icon = row?.icon ?? 'folder', color = row?.color ?? 0;
    await editFields(
      context,
      context.tr(row == null ? 'newFolder' : 'edit'),
      {'name': context.tr('title')},
      initial: {'name': row?.name ?? ''},
      requiredFields: {'name'},
      extra: (c) => StatefulBuilder(
        builder: (context, update) => Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            DropdownButton<String>(
              value: icon,
              onChanged: (v) => update(() => icon = v!),
              items: [
                for (var i = 0; i < _icons.length; i++)
                  DropdownMenuItem(
                    value: OrganizationStore.icons[i],
                    child: Icon(_icons[i]),
                  ),
              ],
            ),
            DropdownButton<int>(
              value: color,
              onChanged: (v) => update(() => color = v!),
              items: [
                for (var i = 0; i < _colors.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Icon(Icons.circle_outlined, color: _colors[i]),
                  ),
              ],
            ),
          ],
        ),
      ),
      onSave: (values) => widget.store.saveFolder(
        values['name']!,
        id: row?.id,
        parent: row?.parent ?? folder ?? '',
        icon: icon,
        color: color,
        allowed: widget.allowed,
      ),
    );
    if (mounted) await load();
  }

  Future<void> setDeleted(RecordFolder row) async {
    if (!row.deleted && !await consent(context, context.tr('orgDeleteInfo'))) {
      return;
    }
    if (!mounted) return;
    await perform(
      () => widget.store.saveFolder(
        row.name,
        id: row.id,
        parent: row.parent,
        icon: row.icon,
        color: row.color,
        deleted: !row.deleted,
        allowed: widget.allowed,
      ),
    );
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted) await load();
  }

  Future<void> move(FolderItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoldersPage(
          store: widget.store,
          allowed: widget.allowed,
          open: widget.open,
          moveItem: item,
          sourceFolder: folder,
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> moveHere() async {
    if (busy || !widget.allowed()) return;
    setState(() => busy = true);
    try {
      await widget.store.move(
        widget.moveItem!,
        folder ?? '',
        from: widget.sourceFolder,
        allowed: widget.allowed,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        failure(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final visible =
        all.where((row) {
          if (trash) {
            return row.deleted && row.name.toLowerCase().contains(query);
          }
          if (row.deleted || ancestors(row).any((f) => f.deleted)) return false;
          return query.isEmpty
              ? row.parent == (folder ?? '')
              : row.name.toLowerCase().contains(query);
        }).toList()..sort(
          (a, b) => latest
              ? b.updated.compareTo(a.updated)
              : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(widget.moveItem == null ? 'orgFolders' : 'orgMove'),
        ),
        actions: [
          IconButton(
            tooltip: context.tr(latest ? 'orgSortName' : 'orgSortRecent'),
            onPressed: () => setState(() => latest = !latest),
            icon: const Icon(Icons.sort),
          ),
          if (widget.moveItem == null)
            IconButton(
              tooltip: context.tr('trash'),
              onPressed: () {
                trash = !trash;
                navigate([]);
              },
              icon: Icon(trash ? Icons.folder_open : Icons.delete_outline),
            ),
        ],
      ),
      floatingActionButton: !trash && widget.allowed()
          ? FloatingActionButton.small(
              key: const Key('folder-create'),
              tooltip: context.tr('newFolder'),
              onPressed: busy ? null : edit,
              child: const Icon(Icons.create_new_folder_outlined),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: context.tr('search'),
              ),
              onChanged: (_) {
                debounce?.cancel();
                setState(() {});
                debounce = Timer(const Duration(milliseconds: 250), load);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => navigate([]),
                    child: Text(context.tr(trash ? 'trash' : 'orgFolders')),
                  ),
                  for (var i = 0; i < path.length; i++) ...[
                    const Icon(Icons.chevron_right, size: 16),
                    TextButton(
                      onPressed: () => navigate(path.take(i + 1).toList()),
                      child: Text(path[i].name),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.moveItem != null)
            FilledButton.icon(
              onPressed: busy ? null : moveHere,
              icon: const Icon(Icons.drive_file_move_outline),
              label: Text(
                context.tr(folder == null ? 'orgUnfile' : 'orgMoveHere'),
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
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 84),
                    itemCount: visible.length + items.length + 1,
                    itemBuilder: (c, i) {
                      if (i < visible.length) {
                        final row = visible[i];
                        return ListTile(
                          key: ValueKey(row.id),
                          leading: Icon(
                            _icons[OrganizationStore.icons.indexOf(row.icon)],
                            color: _colors[row.color],
                          ),
                          title: Text(row.name),
                          subtitle: Text(
                            query.isEmpty
                                ? context
                                      .tr('orgItemCount')
                                      .replaceFirst('{count}', '${row.count}')
                                : ancestors(row).map((f) => f.name).join(' / '),
                          ),
                          onTap: trash
                              ? null
                              : () {
                                  trash = false;
                                  navigate(ancestors(row));
                                },
                          trailing: widget.allowed()
                              ? PopupMenuButton<String>(
                                  onSelected: (action) => action == 'edit'
                                      ? edit(row)
                                      : setDeleted(row),
                                  itemBuilder: (c) => [
                                    if (!row.deleted)
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(c.tr('edit')),
                                      ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        c.tr(
                                          row.deleted ? 'restore' : 'delete',
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        );
                      }
                      final index = i - visible.length;
                      if (index < items.length) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item.title),
                          subtitle: item.subtitle.isEmpty
                              ? null
                              : Text(item.subtitle),
                          onTap: () => widget.open(item),
                          trailing: widget.allowed()
                              ? IconButton(
                                  tooltip: c.tr('orgMove'),
                                  icon: const Icon(
                                    Icons.drive_file_move_outline,
                                  ),
                                  onPressed: () => move(item),
                                )
                              : null,
                        );
                      }
                      if (more) {
                        return TextButton(
                          onPressed: busy ? null : () => load(append: true),
                          child: Text(c.tr('continue')),
                        );
                      }
                      return visible.isEmpty && items.isEmpty && !busy
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(c.tr('orgEmpty')),
                            )
                          : const SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
