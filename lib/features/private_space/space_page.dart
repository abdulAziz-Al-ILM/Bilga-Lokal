import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import '../attachments/attachment_store.dart';
import '../attachments/attachments_page.dart';
import 'record_store.dart';
import 'book_reader.dart';

class SpacePage extends StatefulWidget {
  final String kind;
  const SpacePage({super.key, required this.kind});
  @override
  State<SpacePage> createState() => _SpaceState();
}

class _SpaceState extends State<SpacePage> {
  final store = RecordStore();
  List<PrivateRecord> records = [];
  String query = '', category = '';
  int shown = 50;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await store.all(widget.kind);
      if (mounted) setState(() => records = rows);
    } catch (_) {
      if (mounted) failure(context);
    }
  }

  Future<void> create() async {
    if (busy) return;
    setState(() => busy = true);
    PrivateRecord? created;
    try {
      await editFields(
        context,
        context.tr(widget.kind == 'book' ? 'xBooks' : 'xExperience'),
        {
          'title': context.tr('title'),
          if (widget.kind == 'experience') 'body': context.tr('notes'),
          if (widget.kind == 'experience') 'feelings': context.tr('xFeelings'),
          if (widget.kind == 'experience') 'lesson': context.tr('xLesson'),
          if (widget.kind == 'experience') 'next': context.tr('xNextStep'),
        },
        multiline: {'body', 'feelings', 'lesson', 'next'},
        requiredFields: {'title'},
        onSave: (v) async {
          created = await store.save(widget.kind, {
            ...v,
            'title': v['title']!.trim(),
            if (widget.kind == 'book') 'chapters': [],
            if (widget.kind == 'book') 'characters': '',
            if (widget.kind == 'experience') 'category': 'life',
          });
        },
      );
      if (created != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecordPage(created!)),
        );
      }
      await load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr(widget.kind == 'book' ? 'xBooks' : 'xExperience')),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: busy ? null : create,
      child: const Icon(Icons.add),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: context.tr('search'),
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (s) => setState(() => query = s.toLowerCase()),
        ),
        if (widget.kind == 'experience')
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: Text(context.tr('xExperience')),
                selected: category.isEmpty,
                onSelected: (_) => setState(() => category = ''),
              ),
              for (final key in [
                'work',
                'life',
                'feelings',
                'gratitude',
                'spiritual',
                'lesson',
              ])
                ChoiceChip(
                  label: Text(context.tr('x$key')),
                  selected: category == key,
                  onSelected: (_) => setState(() => category = key),
                ),
            ],
          ),
        for (final r
            in records
                .where(
                  (r) =>
                      (category.isEmpty || r.data['category'] == category) &&
                      jsonEncode(r.data).toLowerCase().contains(query),
                )
                .take(shown))
          ListTile(
            title: Text(r.data['title']),
            subtitle: Text(
              widget.kind == 'book'
                  ? '${(r.data['chapters'] as List).length} ${context.tr('xChapters')}'
                  : context.tr('x${r.data['category']}'),
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RecordPage(r)),
              );
              await load();
            },
          ),
        if (records.length > shown)
          TextButton(
            onPressed: () => setState(() => shown += 50),
            child: Text(context.tr('continue')),
          ),
        const SizedBox(height: 80),
      ],
    ),
  );
}

class RecordPage extends StatefulWidget {
  final PrivateRecord record;
  const RecordPage(this.record, {super.key});
  @override
  State<RecordPage> createState() => _RecordState();
}

class _RecordState extends State<RecordPage> {
  late PrivateRecord r = widget.record;
  final store = RecordStore();
  bool busy = false;
  bool get book => r.kind == 'book';
  Future<void> run(Future<void> Function() f) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await f();
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    r = await store.save(r.kind, data, previous: r);
  }

  Future<void> edit([int? index]) async {
    final chapters = List<Map<String, dynamic>>.from(
      (r.data['chapters'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e),
      ),
    );
    final old = book
        ? (index == null ? <String, dynamic>{} : chapters[index])
        : r.data;
    await editFields(
      context,
      context.tr('edit'),
      {
        'title': context.tr('title'),
        'body': context.tr('notes'),
        if (!book) 'feelings': context.tr('xFeelings'),
        if (!book) 'lesson': context.tr('xLesson'),
        if (!book) 'next': context.tr('xNextStep'),
      },
      initial: {
        for (final k in ['title', 'body', 'feelings', 'lesson', 'next'])
          k: '${old[k] ?? ''}',
      },
      multiline: {'body', 'feelings', 'lesson', 'next'},
      requiredFields: {'title'},
      onSave: (v) async {
        if (book) {
          final versions = [
            ...?old['versions'] as List?,
            if (index != null)
              {
                'title': old['title'],
                'body': old['body'],
                'date': DateTime.now().toIso8601String(),
              },
          ];
          while (versions.length > 20) {
            versions.removeAt(0);
          }
          final chapter = {...v, 'versions': versions};
          if (index == null) {
            chapters.add(chapter);
          } else {
            chapters[index] = chapter;
          }
          await save({...r.data, 'chapters': chapters});
        } else {
          await save({...r.data, ...v});
        }
      },
    );
  }

  String text() => book
      ? '${r.data['title']}\n\n${[for (final c in r.data['chapters']) '${c['title']}\n${c['body']}'].join('\n\n')}'
      : '${r.data['title']}\n\n${r.data['body'] ?? ''}\n\n${r.data['feelings'] ?? ''}\n${r.data['lesson'] ?? ''}\n${r.data['next'] ?? ''}';
  Future<void> export(String type) async {
    if (!await consent(context, context.tr('xPlainExport'))) return;
    List<int> bytes = utf8.encode(text());
    if (type == 'epub') {
      final a = Archive();
      void add(String p, String s, {bool plain = false}) {
        final f = ArchiveFile.string(p, s);
        if (plain) f.compression = CompressionType.none;
        a.addFile(f);
      }

      String esc(String s) => const HtmlEscape().convert(s);
      add('mimetype', 'application/epub+zip', plain: true);
      add(
        'META-INF/container.xml',
        '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
      );
      add(
        'OEBPS/content.opf',
        '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">urn:bilga:${esc(r.id)}</dc:identifier><dc:title>${esc(r.data['title'])}</dc:title><dc:language>und</dc:language><meta property="dcterms:modified">${DateTime.now().toUtc().toIso8601String().split('.').first}Z</meta></metadata><manifest><item id="text" href="book.xhtml" media-type="application/xhtml+xml"/><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/></manifest><spine><itemref idref="text"/></spine></package>',
      );
      add(
        'OEBPS/book.xhtml',
        '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>${esc(r.data['title'])}</title></head><body><pre>${esc(text())}</pre></body></html>',
      );
      add(
        'OEBPS/nav.xhtml',
        '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head><body><nav epub:type="toc"><ol><li><a href="book.xhtml">${esc(r.data['title'])}</a></li></ol></nav></body></html>',
      );
      bytes = ZipEncoder().encode(a);
    }
    await Attachments.export(
      'Bilga.$type',
      type == 'epub' ? 'application/epub+zip' : 'text/plain',
      Stream.value(bytes),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(r.data['title']),
      actions: [
        IconButton(
          icon: const Icon(Icons.attach_file),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AttachmentsPage(
                kind: r.kind,
                owner: r.id,
                title: r.data['title'],
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          enabled: !busy,
          onSelected: (action) => run(() async {
            if (action == 'read') {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookReader(
                    title: r.data['title'],
                    chapters: List<Map<String, dynamic>>.from(
                      r.data['chapters'],
                    ),
                    bookmark: r.data['bookmark'] as int? ?? 0,
                    saveBookmark: (index) =>
                        save({...r.data, 'bookmark': index}),
                  ),
                ),
              );
            } else if (action == 'rename') {
              await editFields(
                context,
                context.tr('title'),
                {'title': context.tr('title')},
                initial: {'title': r.data['title']},
                requiredFields: {'title'},
                onSave: (v) => save({...r.data, ...v}),
              );
            } else if (action == 'restoreChapter') {
              final trash = List<Map<String, dynamic>>.from(
                r.data['chapterTrash'] ?? [],
              );
              if (trash.isNotEmpty) {
                final chapter = trash.removeLast();
                await save({
                  ...r.data,
                  'chapters': [...r.data['chapters'], chapter],
                  'chapterTrash': trash,
                });
              }
            } else if (action == 'delete') {
              if (await consent(context, context.tr('deleteForever'))) {
                await store.remove(r);
                for (final attachment in await Attachments.all(r.kind, r.id)) {
                  await Attachments.remove(attachment);
                }
                if (context.mounted) Navigator.pop(context);
              }
            } else {
              await export(action);
            }
          }),
          itemBuilder: (c) => [
            if (book)
              PopupMenuItem(
                value: 'read',
                child: Row(
                  children: [
                    const Icon(Icons.menu_book),
                    const SizedBox(width: 8),
                    Text(c.tr('xBooks')),
                  ],
                ),
              ),
            PopupMenuItem(value: 'rename', child: Text(c.tr('edit'))),
            PopupMenuItem(value: 'delete', child: Text(c.tr('deleteForever'))),
            const PopupMenuItem(value: 'txt', child: Text('TXT')),
            if (book) const PopupMenuItem(value: 'epub', child: Text('EPUB')),
            if (book && (r.data['chapterTrash'] as List? ?? []).isNotEmpty)
              PopupMenuItem(
                value: 'restoreChapter',
                child: Text(c.tr('restore')),
              ),
          ],
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: busy ? null : () => run(edit),
      child: Icon(book ? Icons.add : Icons.edit),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (!book) ...[
          DropdownButton<String>(
            value: r.data['category'] ?? 'life',
            isExpanded: true,
            items: [
              for (final k in [
                'work',
                'life',
                'feelings',
                'gratitude',
                'spiritual',
                'lesson',
              ])
                DropdownMenuItem(value: k, child: Text(context.tr('x$k'))),
            ],
            onChanged: busy
                ? null
                : (s) => run(() => save({...r.data, 'category': s})),
          ),
          for (final k in ['body', 'feelings', 'lesson', 'next'])
            if ('${r.data[k] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        {
                          'body': 'notes',
                          'feelings': 'xFeelings',
                          'lesson': 'xLesson',
                          'next': 'xNextStep',
                        }[k]!,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText('${r.data[k]}'),
                  ],
                ),
              ),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    await store.save('book', {
                      'title': r.data['title'],
                      'chapters': [
                        {
                          'title': r.data['title'],
                          'body': text(),
                          'versions': [],
                        },
                      ],
                      'characters': '',
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('saved'))),
                      );
                    }
                  }),
            child: Text(context.tr('xBooks')),
          ),
        ] else ...[
          Text(
            '${text().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length} ${context.tr('xWords')}',
          ),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    await editFields(
                      context,
                      context.tr('xCharacters'),
                      {'characters': context.tr('xCharacters')},
                      initial: {'characters': r.data['characters'] ?? ''},
                      multiline: {'characters'},
                      onSave: (v) => save({...r.data, ...v}),
                    );
                  }),
            child: Text(context.tr('xCharacters')),
          ),
          for (var i = 0; i < (r.data['chapters'] as List).length; i++)
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(r.data['chapters'][i]['title']),
                    subtitle: Text(
                      r.data['chapters'][i]['body'],
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: busy ? null : () => run(() => edit(i)),
                  ),
                  Wrap(
                    children: [
                      IconButton(
                        tooltip: context.tr('trashConfirm'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                if (!await consent(
                                  context,
                                  context.tr('trashConfirm'),
                                )) {
                                  return;
                                }
                                final chapters = List.from(r.data['chapters']);
                                final removed = chapters.removeAt(i);
                                await save({
                                  ...r.data,
                                  'chapters': chapters,
                                  'chapterTrash': [
                                    ...?r.data['chapterTrash'] as List?,
                                    removed,
                                  ],
                                });
                              }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: busy || i == 0
                            ? null
                            : () => run(() async {
                                final cs = List.from(r.data['chapters']);
                                final c = cs.removeAt(i);
                                cs.insert(i - 1, c);
                                await save({...r.data, 'chapters': cs});
                              }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.history),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text(c.tr('history')),
                            content: SizedBox(
                              width: 500,
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final v
                                      in r.data['chapters'][i]['versions'] ??
                                          [])
                                    ExpansionTile(
                                      title: Text('${v['date']}'),
                                      children: [
                                        SelectableText(
                                          '${v['title']}\n${v['body']}',
                                        ),
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () {
                                                  Navigator.pop(c);
                                                  run(() async {
                                                    final cs =
                                                        List<
                                                          Map<String, dynamic>
                                                        >.from(
                                                          (r.data['chapters']
                                                                  as List)
                                                              .map(
                                                                (e) =>
                                                                    Map<
                                                                      String,
                                                                      dynamic
                                                                    >.from(e),
                                                              ),
                                                        );
                                                    final old = cs[i];
                                                    final history = [
                                                      ...?old['versions']
                                                          as List?,
                                                      {
                                                        'title': old['title'],
                                                        'body': old['body'],
                                                        'date': DateTime.now()
                                                            .toIso8601String(),
                                                      },
                                                    ];
                                                    cs[i] = {
                                                      'title': v['title'],
                                                      'body': v['body'],
                                                      'versions':
                                                          history.length > 20
                                                          ? history.sublist(
                                                              history.length -
                                                                  20,
                                                            )
                                                          : history,
                                                    };
                                                    await save({
                                                      ...r.data,
                                                      'chapters': cs,
                                                    });
                                                  });
                                                },
                                          child: Text(c.tr('restore')),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 80),
      ],
    ),
  );
}
