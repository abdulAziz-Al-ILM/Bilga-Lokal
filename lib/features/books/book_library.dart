import 'dart:convert';

/// Optional, versioned library metadata. Legacy chapter records remain readable
/// without a write or an invented author, reading status, date or page count.
class BookLibrary {
  static const statuses = {
    'unspecified',
    'planned',
    'reading',
    'completed',
    'paused',
    'abandoned',
  };
  static const fields = {
    'author',
    'description',
    'genre',
    'categories',
    'tags',
    'shelves',
    'publisher',
    'publicationYear',
    'isbn',
    'language',
    'status',
    'startedOn',
    'finishedOn',
    'pages',
    'currentPage',
    'rating',
    'favorite',
  };
  static Map<String, dynamic> get defaults => {
    'author': '',
    'description': '',
    'genre': '',
    'categories': <String>[],
    'tags': <String>[],
    'shelves': <String>[],
    'publisher': '',
    'publicationYear': null,
    'isbn': '',
    'language': '',
    'status': 'unspecified',
    'startedOn': '',
    'finishedOn': '',
    'pages': null,
    'currentPage': 0,
    'rating': null,
    'favorite': false,
  };
  static Map<String, dynamic> metadata(Map<String, dynamic> data) {
    if (!data.containsKey('libraryVersion') && !data.containsKey('library')) {
      return defaults;
    }
    if (data['libraryVersion'] is! int ||
        data['libraryVersion'] != 1 ||
        data['library'] is! Map) {
      throw const FormatException('book_library_version');
    }
    return Map<String, dynamic>.from(data['library'] as Map);
  }

  static bool validDate(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      DateTime.tryParse(value) != null &&
      DateTime.parse(value).year >= 1 &&
      DateTime.parse(value).year <= 9999 &&
      DateTime.parse(value).toIso8601String().substring(0, 10) == value;
  static String isbn(String input) {
    if (input.trim().isEmpty) return '';
    var code = input.trim().replaceFirst(
      RegExp(r'^ISBN(?:-1[03])?\s*:?\s*', caseSensitive: false),
      '',
    );
    for (var digit = 0; digit < 10; digit++) {
      code = code.replaceAll(String.fromCharCode(0xff10 + digit), '$digit');
    }
    code = code.replaceAll(RegExp(r'[\s\u2010-\u2015\-]'), '').toUpperCase();
    if (RegExp(r'^\d{9}[\dX]$').hasMatch(code)) {
      var sum = 0;
      for (var i = 0; i < 10; i++) {
        sum += (10 - i) * (code[i] == 'X' ? 10 : int.parse(code[i]));
      }
      if (sum % 11 == 0) return code;
    }
    if (RegExp(r'^(978|979)\d{10}$').hasMatch(code)) {
      var sum = 0;
      for (var i = 0; i < 13; i++) {
        sum += int.parse(code[i]) * (i.isEven ? 1 : 3);
      }
      if (sum % 10 == 0) return code;
    }
    throw const FormatException('isbn');
  }

  static List<String> labels(String input) {
    final seen = <String>{};
    return [
      for (final raw in input.split(RegExp(r'[,،，、\n]')))
        if (raw.trim().isNotEmpty && seen.add(raw.trim().toLowerCase()))
          raw.trim(),
    ];
  }

  static void validate(Map<String, dynamic> data) {
    final meta = metadata(data);
    if (meta.keys.any((key) => !fields.contains(key)) ||
        meta.keys.toSet().length != fields.length) {
      throw const FormatException('book_metadata');
    }
    for (final key in [
      'author',
      'description',
      'genre',
      'publisher',
      'isbn',
      'language',
      'startedOn',
      'finishedOn',
    ]) {
      final value = meta[key];
      final limit = key == 'description'
          ? 100000
          : key == 'author'
          ? 1000
          : 200;
      if (value is! String || value.length > limit) {
        throw const FormatException('book_text');
      }
    }
    if (!statuses.contains(meta['status']) || meta['favorite'] is! bool) {
      throw const FormatException('book_status');
    }
    for (final key in ['categories', 'tags', 'shelves']) {
      final values = meta[key];
      if (values is! List || values.length > 50) {
        throw const FormatException('book_labels');
      }
      final seen = <String>{};
      for (final value in values) {
        if (value is! String ||
            value.trim().isEmpty ||
            value != value.trim() ||
            value.length > 100 ||
            !seen.add(value.toLowerCase())) {
          throw const FormatException('book_label');
        }
      }
    }
    if (isbn(meta['isbn'] as String) != meta['isbn']) {
      throw const FormatException('isbn');
    }
    final year = meta['publicationYear'],
        pages = meta['pages'],
        current = meta['currentPage'],
        rating = meta['rating'];
    if ((year != null && (year is! int || year < 1 || year > 9999)) ||
        (pages != null && (pages is! int || pages < 1 || pages > 10000000)) ||
        current is! int ||
        current < 0 ||
        current > 10000000 ||
        (pages != null && current > pages) ||
        (rating != null && (rating is! int || rating < 1 || rating > 5))) {
      throw const FormatException('book_number');
    }
    final start = meta['startedOn'] as String,
        finish = meta['finishedOn'] as String;
    if ((start.isNotEmpty && !validDate(start)) ||
        (finish.isNotEmpty && !validDate(finish)) ||
        (start.isNotEmpty &&
            finish.isNotEmpty &&
            start.compareTo(finish) > 0)) {
      throw const FormatException('book_dates');
    }
  }

  static Map<String, dynamic> update(
    Map<String, dynamic> source,
    Map<String, dynamic> changes,
  ) {
    if (changes.keys.any((key) => !fields.contains(key))) {
      throw const FormatException('book_field');
    }
    final result = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    final original = metadata(result);
    final copiedChanges =
        jsonDecode(jsonEncode(changes)) as Map<String, dynamic>;
    result['libraryVersion'] = 1;
    result['library'] = {...original, ...copiedChanges};
    validate(result);
    return result;
  }

  static String readable(
    Map<String, dynamic> data, {
    required String Function(String) label,
    required String Function(String) date,
  }) {
    final meta = metadata(data);
    return [
      data['title'] as String,
      for (final field in [
        'author',
        'description',
        'genre',
        'publisher',
        'publicationYear',
        'isbn',
        'language',
      ])
        if (meta[field] != null && '${meta[field]}'.isNotEmpty)
          '${label(switch (field) {
            'author' => 'bAuthor',
            'description' => 'description',
            'genre' => 'bGenre',
            'publisher' => 'bPublisher',
            'publicationYear' => 'bPublicationYear',
            'isbn' => 'bIsbn',
            _ => 'bLanguage',
          })}: ${meta[field]}',
      '${label('bStatus')}: ${label('bStatus${meta['status']}')}',
      if (meta['pages'] != null || meta['currentPage'] != 0)
        '${label('bCurrentPage')}: ${meta['currentPage']}${meta['pages'] == null ? '' : ' / ${meta['pages']}'}',
      if (meta['rating'] != null) '${label('bRating')}: ${meta['rating']} / 5',
      if (meta['favorite'] == true) label('favorites'),
      for (final field in ['categories', 'tags', 'shelves'])
        if ((meta[field] as List).isNotEmpty)
          '${label(switch (field) {
            'categories' => 'bCategories',
            'tags' => 'tags',
            _ => 'bShelves',
          })}: ${(meta[field] as List).join(', ')}',
      if ((meta['startedOn'] as String).isNotEmpty)
        '${label('bStartedOn')}: ${date(meta['startedOn'] as String)}',
      if ((meta['finishedOn'] as String).isNotEmpty)
        '${label('bFinishedOn')}: ${date(meta['finishedOn'] as String)}',
      if ((data['characters'] as String? ?? '').isNotEmpty)
        '${label('xCharacters')}: ${data['characters']}',
      for (final chapter in data['chapters'] as List)
        '${chapter['title']}\n${chapter['body']}',
    ].join('\n\n');
  }
}
