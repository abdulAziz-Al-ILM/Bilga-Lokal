import '../guidance/guide_controller.dart';

import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'rich_note_codec.dart';
import 'rich_note_widgets.dart';
import '../attachments/attachments_page.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/dialogs.dart';
import '../collections/collection_repository.dart';
import 'note_history_page.dart';
import 'note_model.dart';
import 'note_service.dart';
import 'note_tag_picker.dart';

/// Owns persistence: callers only reload their lists when this route closes.
class NoteEditorPage extends StatefulWidget {
  final Note? note;
  final String? folderId;
  final NoteService? service;
  final GuideController? guide;
  final Map<String, GlobalKey> guideTargets;

  const NoteEditorPage({
    super.key,
    this.note,
    this.folderId,
    this.service,
    this.guide,
    this.guideTargets = const {},
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage>
    with WidgetsBindingObserver {
  late final TextEditingController _title;
  late final quill.QuillController _document;
  final _bodyFocus = FocusNode();
  final _bodyScroll = ScrollController();
  StreamSubscription<quill.DocChange>? _documentChanges;
  bool _formatFailure = false;
  int _richRevision = 0, _savedRichRevision = 0;
  String get _bodyText {
    final text = _document.document.toPlainText();
    return text.substring(0, text.length - 1);
  }

  String? _richSnapshot() {
    final ops = _document.document.toDelta().toJson();
    if (_note.richBody == null &&
        ops.length == 1 &&
        ops.single.length == 1 &&
        ops.single['insert'] == '${_note.body}\n') {
      return null;
    }
    return RichNoteCodec.encode(ops, body: _bodyText);
  }

  void _listenToDocument() {
    _documentChanges = _document.document.changes.listen((_) {
      _richRevision++;
      if (mounted) _changed('');
    });
  }

  late final NoteService _service;
  late Note _note;
  late bool _inserted;
  late List<String> _tagNames;
  List<String>? _tagIds;
  bool _historyRecorded = false;
  bool _allowPop = false;
  bool _busy = false;
  String? _error;
  Timer? _debounce;
  Future<void> _queue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _note =
        widget.note ??
        Note(
          id: now.microsecondsSinceEpoch.toString(),
          title: '',
          body: '',
          folderId: widget.folderId,
          createdAt: now,
          updatedAt: now,
        );
    _inserted = widget.note != null;
    _tagNames = List.of(_note.tags);
    _tagIds = _note.tagIds == null ? null : List.of(_note.tagIds!);
    _service = widget.service ?? NoteService();
    _title = TextEditingController(text: _note.title);
    quill.Document doc;
    try {
      doc = quill.Document.fromJson(
        _note.richBody == null
            ? [
                {'insert': '${_note.body}\n'},
              ]
            : RichNoteCodec.decode(_note.richBody!, expectedBody: _note.body),
      );
    } on FormatException {
      _formatFailure = true;
      doc = quill.Document.fromJson([
        {'insert': '${_note.body}\n'},
      ]);
    }
    _document = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _listenToDocument();
  }

  bool _same(List<String>? a, List<String>? b) => a == null || b == null
      ? a == b
      : a.length == b.length &&
            a.asMap().entries.every((e) => b[e.key] == e.value);
  bool get _dirty =>
      _title.text != _note.title ||
      _bodyText != _note.body ||
      _richRevision != _savedRichRevision ||
      !_same(_tagIds, _note.tagIds) ||
      !_same(_tagNames, _note.tags);

  Future<void> _chooseTags() async {
    if (_busy) return;
    try {
      final store = await _service.tagStore;
      final currentIds =
          _tagIds ?? (await store.forNote(_note.id)).map((t) => t.id).toList();
      if (!mounted) return;
      final picked = await showNoteTagPicker(
        context,
        store,
        selected: currentIds,
      );
      // Apply a confirmed selection before another Save/Back can close the
      // editor. IDs are validated/canonicalized by the transactional tag store.
      final selected =
          picked ??
          (await store.all()).where((t) => currentIds.contains(t.id)).toList();
      if (!mounted) return;
      setState(() {
        _tagIds = selected.map((t) => t.id).toList();
        _tagNames = selected.map((t) => t.name).toList();
      });
      _changed('');
    } catch (_) {
      if (mounted) showError(context);
    }
  }

  void _removeTag(String id) {
    final index = _tagIds?.indexOf(id) ?? -1;
    if (index < 0) return;
    setState(() {
      _tagIds!.removeAt(index);
      _tagNames.removeAt(index);
    });
    _changed('');
  }

  void _changed(String _) {
    widget.guide?.satisfy('titleEntered', valid: _title.text.trim().isNotEmpty);
    widget.guide?.satisfy('bodyEntered', valid: _bodyText.trim().isNotEmpty);
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_persist());
    });
  }

  Future<bool> _persist() {
    final title = _title.text;
    if (_formatFailure) return Future.value(false);
    final body = _bodyText;
    String? rich;
    try {
      rich = _richSnapshot();
    } catch (_) {
      if (mounted) setState(() => _error = 'saveError');
      return Future.value(false);
    }
    final richRevision = _richRevision;
    final names = List<String>.of(_tagNames);
    final ids = _tagIds == null ? null : List<String>.of(_tagIds!);
    final completion = Completer<bool>();
    _queue = _queue.then((_) async {
      try {
        if (!_inserted &&
            title.trim().isEmpty &&
            body.trim().isEmpty &&
            names.isEmpty) {
          completion.complete(true);
          return;
        }
        if (_inserted &&
            title == _note.title &&
            body == _note.body &&
            rich == _note.richBody &&
            _same(ids, _note.tagIds) &&
            _same(names, _note.tags)) {
          _savedRichRevision = richRevision;
          if (mounted) setState(() => _error = null);
          completion.complete(true);
          return;
        }
        final next = _note.copyWith(
          title: title,
          body: body,
          richBody: rich,
          updatedAt: DateTime.now(),
          tags: names,
          tagIds: ids,
        );
        if (_inserted) {
          await _service.updateNote(next, recordHistory: !_historyRecorded);
        } else {
          await _service.addNote(next);
        }
        if (!_inserted ||
            title != _note.title ||
            body != _note.body ||
            rich != _note.richBody) {
          _historyRecorded = true;
        }
        _inserted = true;
        _note = next;
        _savedRichRevision = richRevision;
        if (mounted) setState(() => _error = null);
        completion.complete(true);
      } catch (_) {
        if (mounted) setState(() => _error = 'saveError');
        completion.complete(false);
      }
    });
    return completion.future;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _debounce?.cancel();
      unawaited(_persist());
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_formatFailure) {
      await _pop();
      return;
    }
    setState(() => _busy = true);
    _debounce?.cancel();
    final saved = await _persist();
    if (!mounted) return;
    if (!saved) {
      setState(() => _busy = false);
      return;
    }
    if (_inserted) widget.guide?.event('saved');
    await _pop();
  }

  Future<void> _pop() async {
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, _inserted ? _note : null);
  }

  Future<void> _trash() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('trash')),
        content: Text(context.tr('trashConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('trash')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    _debounce?.cancel();
    if (!await _persist() || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      if (_inserted) {
        await _service.moveToTrash(_note);
        _note = _note.copyWith(isDeleted: true);
      }
      await _pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'error';
        });
      }
    }
  }

  Future<void> _history() async {
    if (_busy) return;
    setState(() => _busy = true);
    _debounce?.cancel();
    if (!await _persist() || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (_inserted) {
      final restored = await Navigator.push<Note>(
        context,
        MaterialPageRoute(builder: (_) => NoteHistoryPage(note: _note)),
      );
      if (!mounted) return;
      if (restored != null) {
        _note = restored;
        _title.text = restored.title;
        await _documentChanges?.cancel();
        final previousDocument = _document.document;
        _document.document = quill.Document.fromJson(
          restored.richBody == null
              ? [
                  {'insert': '${restored.body}\n'},
                ]
              : RichNoteCodec.decode(
                  restored.richBody!,
                  expectedBody: restored.body,
                ),
        );
        previousDocument.close();
        _richRevision = _savedRichRevision = 0;
        _listenToDocument();
        _tagIds = restored.tagIds;
        _tagNames = List.of(restored.tags);
      }
      _historyRecorded = false;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _attachments() async {
    if (_busy || _formatFailure) return;
    setState(() => _busy = true);
    _debounce?.cancel();
    try {
      if (!_inserted &&
          _title.text.trim().isEmpty &&
          _bodyText.trim().isEmpty) {
        _title.text = context.tr('untitled');
      }
      if (!await _persist() || !mounted || !_inserted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => AttachmentsPage(
            kind: 'note',
            owner: _note.id,
            title: _note.title,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _move() async {
    if (_busy) return;
    setState(() => _busy = true);
    _debounce?.cancel();
    if (!await _persist() || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      final folders = await CollectionRepository(CollectionKind.notes)
          .activeFolders();
      if (!mounted) return;
      final target = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(c.tr('move')),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, ''),
              child: Text(c.tr('home')),
            ),
            ...folders.map(
              (f) => SimpleDialogOption(
                onPressed: () => Navigator.pop(c, f['id'] as String),
                child: Text(f['name'] as String),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (target != null) {
        final folderId = target.isEmpty ? null : target;
        if (_inserted) await _service.moveNoteToFolder(_note, folderId);
        _note = _note.copyWith(folderId: folderId);
        await _pop();
        return;
      }
    } catch (_) {
      if (mounted) showError(context);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _title.dispose();
    unawaited(_documentChanges?.cancel());
    _bodyFocus.dispose();
    _bodyScroll.dispose();
    _document.dispose();
    super.dispose();
  }

  String _date(DateTime value) =>
      '${MaterialLocalizations.of(context).formatMediumDate(value)} ${TimeOfDay.fromDateTime(value).format(context)}';

  @override
  Widget build(BuildContext context) {
    _document.readOnly = _busy || _formatFailure;
    final compact =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        MediaQuery.sizeOf(context).height < 550;
    return PopScope<Note>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.tr('back'),
            onPressed: _busy ? null : _close,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            widget.note == null ? context.tr('newNote') : context.tr('note'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              tooltip: context.tr('xAttach'),
              onPressed: _busy || _formatFailure ? null : _attachments,
            ),
            PopupMenuButton<String>(
              enabled: !_busy && !_formatFailure,
              onSelected: (value) {
                if (value == 'history') _history();
                if (value == 'move') _move();
                if (value == 'trash') _trash();
                if (value == 'tags') _chooseTags();
              },
              itemBuilder: (c) => [
                for (final key in ['tags', 'history', 'move', 'trash'])
                  PopupMenuItem(value: key, child: Text(c.tr(key))),
              ],
            ),
            IconButton(
              key: widget.guideTargets['save'],
              tooltip: context.tr('save'),
              onPressed: _busy ? null : _close,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.all(compact ? 12 : 20),
          child: Column(
            children: [
              KeyedSubtree(
                key: widget.guideTargets['title'],
                child: TextField(
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  key: const Key('note-title'),
                  controller: _title,
                  readOnly: _busy || _formatFailure,
                  onChanged: _changed,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('title'),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (!compact)
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _busy || _formatFailure ? null : _chooseTags,
                      icon: const Icon(Icons.label_outline, size: 18),
                      label: Text(context.tr('tags')),
                    ),
                    Expanded(
                      child: NoteTagChips(
                        names: _tagNames,
                        ids: _tagIds,
                        onRemoved: _busy || _formatFailure ? null : _removeTag,
                      ),
                    ),
                  ],
                ),
              SizedBox(height: compact ? 4 : 12),
              RichNoteToolbar(
                controller: _document,
                focusNode: _bodyFocus,
                enabled: !_busy && !_formatFailure,
              ),
              const SizedBox(height: 8),
              Expanded(
                key: widget.guideTargets['body'],
                child: noteQuillLocalizations(
                  context,
                  quill.QuillEditor(
                    key: const Key('note-body'),
                    controller: _document,
                    focusNode: _bodyFocus,
                    scrollController: _bodyScroll,
                    config: quill.QuillEditorConfig(
                      expands: true,
                      placeholder: context.tr('write'),
                      onLaunchUrl: (url) => launchNoteLink(context, url),
                    ),
                  ),
                ),
              ),
              if (_formatFailure)
                Text(
                  context.tr('richUnsupported'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_inserted && !compact)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${context.tr('created')}: ${_date(_note.createdAt)} · ${context.tr('updated')}: ${_date(_note.updatedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  (_error == null ? null : context.tr(_error!)) ??
                      (_dirty
                          ? context.tr('saving')
                          : (_inserted ? context.tr('saved') : '')),
                  style: TextStyle(
                    fontSize: 12,
                    color: _error == null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
