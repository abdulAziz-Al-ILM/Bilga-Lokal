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

  const NoteEditorPage({super.key, this.note, this.folderId, this.service});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage>
    with WidgetsBindingObserver {
  late final TextEditingController _title;
  late final TextEditingController _body;
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
    _body = TextEditingController(text: _note.body);
  }

  bool _same(List<String>? a, List<String>? b) => a == null || b == null
      ? a == b
      : a.length == b.length &&
            a.asMap().entries.every((e) => b[e.key] == e.value);
  bool get _dirty =>
      _title.text != _note.title ||
      _body.text != _note.body ||
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
      final all = await store.all();
      if (!mounted) return;
      final selected =
          picked ?? all.where((t) => currentIds.contains(t.id)).toList();
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
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_persist());
    });
  }

  Future<bool> _persist() {
    final title = _title.text;
    final body = _body.text;
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
            _same(ids, _note.tagIds) &&
            _same(names, _note.tags)) {
          if (mounted) setState(() => _error = null);
          completion.complete(true);
          return;
        }
        final next = _note.copyWith(
          title: title,
          body: body,
          updatedAt: DateTime.now(),
          tags: names,
          tagIds: ids,
        );
        if (_inserted) {
          await _service.updateNote(next, recordHistory: !_historyRecorded);
        } else {
          await _service.addNote(next);
        }
        if (!_inserted || title != _note.title || body != _note.body) {
          _historyRecorded = true;
        }
        _inserted = true;
        _note = next;
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
    setState(() => _busy = true);
    _debounce?.cancel();
    final saved = await _persist();
    if (!mounted) return;
    if (!saved) {
      setState(() => _busy = false);
      return;
    }
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
        _body.text = restored.body;
        _tagIds = restored.tagIds;
        _tagNames = List.of(restored.tags);
      }
      _historyRecorded = false;
    }
    if (mounted) setState(() => _busy = false);
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
    _body.dispose();
    super.dispose();
  }

  String _date(DateTime value) =>
      '${MaterialLocalizations.of(context).formatMediumDate(value)} ${TimeOfDay.fromDateTime(value).format(context)}';

  @override
  Widget build(BuildContext context) {
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
              onPressed: _busy
                  ? null
                  : () async {
                      if (!await _persist() || !context.mounted) return;
                      if (!_inserted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AttachmentsPage(
                            kind: 'note',
                            owner: _note.id,
                            title: _note.title,
                          ),
                        ),
                      );
                    },
            ),
            IconButton(
              tooltip: context.tr('history'),
              onPressed: _busy ? null : _history,
              icon: const Icon(Icons.history),
            ),
            IconButton(
              tooltip: context.tr('move'),
              onPressed: _busy ? null : _move,
              icon: const Icon(Icons.drive_file_move_outline),
            ),
            IconButton(
              tooltip: context.tr('trash'),
              onPressed: _busy ? null : _trash,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: context.tr('save'),
              onPressed: _busy ? null : _close,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                key: const Key('note-title'),
                controller: _title,
                readOnly: _busy,
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
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : _chooseTags,
                    icon: const Icon(Icons.label_outline, size: 18),
                    label: Text(context.tr('tags')),
                  ),
                  Expanded(
                    child: NoteTagChips(
                      names: _tagNames,
                      ids: _tagIds,
                      onRemoved: _busy ? null : _removeTag,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  key: const Key('note-body'),
                  controller: _body,
                  readOnly: _busy,
                  onChanged: _changed,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(
                    hintText: context.tr('write'),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_inserted)
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
