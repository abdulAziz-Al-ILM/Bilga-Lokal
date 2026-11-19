import 'package:flutter/material.dart';

import '../../core/editor_form.dart';
import '../../core/strings.dart';
import 'book_library.dart';

int bookInteger(String text) {
  var value = text.trim();
  for (final start in [0x660, 0x6f0, 0x966, 0x9e6, 0xe50, 0xff10]) {
    for (var digit = 0; digit < 10; digit++) {
      value = value.replaceAll(String.fromCharCode(start + digit), '$digit');
    }
  }
  final parsed = RegExp(r'^\d+$').hasMatch(value) ? int.tryParse(value) : null;
  if (parsed == null) throw const FormatException('book_integer');
  return parsed;
}

class BookDetailsEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const BookDetailsEditor({
    super.key,
    required this.initial,
    required this.onSave,
  });
  @override
  State<BookDetailsEditor> createState() => _DetailsState();
}

class _DetailsState extends State<BookDetailsEditor> {
  final form = GlobalKey<FormState>();
  late final Map<String, dynamic> original = BookLibrary.metadata(
    widget.initial,
  );
  late final fields = <String, TextEditingController>{
    'title': TextEditingController(text: widget.initial['title'] as String),
    for (final key in [
      'author',
      'description',
      'genre',
      'publisher',
      'publicationYear',
      'isbn',
      'language',
      'startedOn',
      'finishedOn',
      'pages',
      'currentPage',
    ])
      key: TextEditingController(text: '${original[key] ?? ''}'),
    for (final key in ['categories', 'tags', 'shelves'])
      key: TextEditingController(text: (original[key] as List).join(', ')),
  };
  late final anchors = {for (final key in fields.keys) key: GlobalKey()};
  late String status = original['status'] as String;
  late int rating = original['rating'] as int? ?? 0;
  late bool favorite = original['favorite'] as bool;
  bool saving = false, leaving = false;
  String? error;
  static const labels = {
    'title': 'title',
    'author': 'bAuthor',
    'description': 'description',
    'genre': 'bGenre',
    'publisher': 'bPublisher',
    'publicationYear': 'bPublicationYear',
    'isbn': 'bIsbn',
    'language': 'bLanguage',
    'startedOn': 'bStartedOn',
    'finishedOn': 'bFinishedOn',
    'pages': 'bPages',
    'currentPage': 'bCurrentPage',
    'categories': 'bCategories',
    'tags': 'tags',
    'shelves': 'bShelves',
  };
  bool get dirty =>
      status != original['status'] ||
      rating != (original['rating'] ?? 0) ||
      favorite != original['favorite'] ||
      fields.entries.any(
        (item) =>
            item.value.text !=
            (item.key == 'title'
                ? widget.initial['title']
                : original[item.key] is List
                ? (original[item.key] as List).join(', ')
                : '${original[item.key] ?? ''}'),
      );
  @override
  void dispose() {
    for (final value in fields.values) {
      value.dispose();
    }
    super.dispose();
  }

  int? number(String key) =>
      fields[key]!.text.trim().isEmpty ? null : bookInteger(fields[key]!.text);
  String? validate(String key, String? raw) {
    final text = raw ?? '';
    try {
      if (key == 'title' && (text.trim().isEmpty || text.length > 200)) {
        return context.tr('bTitleInvalid');
      }
      if (key == 'isbn') BookLibrary.isbn(text);
      if ({'pages', 'currentPage', 'publicationYear'}.contains(key)) {
        final value = number(key);
        if ((key == 'currentPage' && value == null) ||
            (value != null &&
                (value < (key == 'currentPage' ? 0 : 1) ||
                    value > (key == 'publicationYear' ? 9999 : 10000000)))) {
          return context.tr('bNumberInvalid');
        }
        if (key == 'currentPage' &&
            value != null &&
            number('pages') != null &&
            value > number('pages')!) {
          return context.tr('bPageInvalid');
        }
      }
      if ({'categories', 'tags', 'shelves'}.contains(key)) {
        final values = BookLibrary.labels(text);
        if (values.length > 50 || values.any((value) => value.length > 100)) {
          return context.tr('bLabelsInvalid');
        }
      }
      if ({'startedOn', 'finishedOn'}.contains(key)) {
        if (text.isNotEmpty && !BookLibrary.validDate(text)) {
          return context.tr('bDatesInvalid');
        }
        if (key == 'finishedOn' &&
            text.isNotEmpty &&
            fields['startedOn']!.text.isNotEmpty &&
            fields['startedOn']!.text.compareTo(text) > 0) {
          return context.tr('bDatesInvalid');
        }
      }
    } catch (_) {
      return context.tr(key == 'isbn' ? 'bIsbnInvalid' : 'bNumberInvalid');
    }
    return null;
  }

  Future<void> save() async {
    if (saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!form.currentState!.validate()) {
      final invalid = fields.entries
          .where((item) => validate(item.key, item.value.text) != null)
          .firstOrNull;
      final target = invalid == null
          ? null
          : anchors[invalid.key]?.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 200),
          alignment: 0.1,
        );
      }
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final data = BookLibrary.update(
        {...widget.initial, 'title': fields['title']!.text.trim()},
        {
          for (final key in [
            'author',
            'description',
            'genre',
            'publisher',
            'language',
          ])
            key: key == 'description'
                ? fields[key]!.text
                : fields[key]!.text.trim(),
          'isbn': BookLibrary.isbn(fields['isbn']!.text),
          for (final key in ['publicationYear', 'pages', 'currentPage'])
            key: number(key),
          for (final key in ['startedOn', 'finishedOn']) key: fields[key]!.text,
          for (final key in ['categories', 'tags', 'shelves'])
            key: BookLibrary.labels(fields[key]!.text),
          'status': status,
          'rating': rating == 0 ? null : rating,
          'favorite': favorite,
        },
      );
      await widget.onSave(data);
      if (!mounted) return;
      setState(() {
        saving = false;
        leaving = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = context.tr('saveError');
        });
      }
    }
  }

  Widget input(String key) {
    final date = {'startedOn', 'finishedOn'}.contains(key),
        numeric = {'publicationYear', 'pages', 'currentPage'}.contains(key);
    return Padding(
      key: anchors[key],
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        key: ValueKey('book-detail-$key'),
        controller: fields[key],
        enabled: !saving,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        keyboardType: numeric ? TextInputType.number : null,
        minLines: key == 'description' ? 4 : 1,
        maxLines: key == 'description' ? 10 : 1,
        maxLength: switch (key) {
          'description' => 100000,
          'author' => 1000,
          'categories' || 'tags' || 'shelves' => 6000,
          'pages' || 'currentPage' || 'publicationYear' => 12,
          _ => 200,
        },
        readOnly: date,
        validator: (raw) => validate(key, raw),
        decoration: InputDecoration(
          labelText: context.tr(labels[key]!),
          errorMaxLines: 3,
          suffixIcon: date && fields[key]!.text.isNotEmpty
              ? IconButton(
                  tooltip: context.tr('bClearDate'),
                  onPressed: saving
                      ? null
                      : () => setState(() => fields[key]!.clear()),
                  icon: const Icon(Icons.clear),
                )
              : null,
        ),
        onTap: !date
            ? null
            : () async {
                final value = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.tryParse(fields[key]!.text) ?? DateTime.now(),
                  firstDate: DateTime(1),
                  lastDate: DateTime(9999, 12, 31),
                );
                if (value != null && mounted) {
                  setState(
                    () => fields[key]!.text = value.toIso8601String().substring(
                      0,
                      10,
                    ),
                  );
                }
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && (leaving || !dirty),
    onPopInvokedWithResult: (did, _) async {
      if (!did &&
          !saving &&
          await consent(context, context.tr('discardChanges')) &&
          mounted) {
        setState(() => leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('bDetails')),
        actions: [
          IconButton(
            key: const Key('book-details-save'),
            tooltip: context.tr('save'),
            onPressed: saving ? null : save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Form(
        key: form,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              key: const Key('book-details-fields'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (saving) const LinearProgressIndicator(),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    input('title'),
                    input('author'),
                    DropdownButtonFormField<String>(
                      key: const Key('book-detail-status'),
                      initialValue: status,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('bStatus'),
                      ),
                      items: [
                        for (final value in BookLibrary.statuses)
                          DropdownMenuItem(
                            value: value,
                            child: Text(context.tr('bStatus$value')),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) => setState(() => status = value!),
                    ),
                    const SizedBox(height: 20),
                    input('description'),
                    input('genre'),
                    input('pages'),
                    input('currentPage'),
                    input('startedOn'),
                    input('finishedOn'),
                    DropdownButtonFormField<int>(
                      key: const Key('book-detail-rating'),
                      initialValue: rating,
                      decoration: InputDecoration(
                        labelText: context.tr('bRating'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(context.tr('bUnrated')),
                        ),
                        for (var value = 1; value <= 5; value++)
                          DropdownMenuItem(
                            value: value,
                            child: Text('$value / 5'),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) => setState(() => rating = value!),
                    ),
                    SwitchListTile(
                      key: const Key('book-detail-favorite'),
                      title: Text(context.tr('favorites')),
                      value: favorite,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => favorite = value),
                    ),
                    input('publisher'),
                    input('publicationYear'),
                    input('isbn'),
                    input('language'),
                    Text(context.tr('bLabelsInfo')),
                    input('categories'),
                    input('tags'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
