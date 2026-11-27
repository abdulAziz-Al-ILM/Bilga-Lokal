import 'dart:convert';

import 'package:bilga/features/books/book_library.dart';
import 'package:bilga/features/books/book_details_editor.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> legacy() => {
    'title': 'Existing book',
    'characters': 'Original characters',
    'bookmark': 1,
    'chapters': [
      {
        'title': 'One',
        'body': 'Complete saved content',
        'versions': [
          {'title': 'Old', 'body': 'Earlier content', 'date': '2020-01-01'},
        ],
      },
      {'title': 'Two', 'body': 'Second chapter', 'versions': <dynamic>[]},
    ],
  };
  test('Legacy metadata reads preserve chapters, history and bookmark without invented dates or status', () {
    final data = legacy(), before = jsonEncode(legacy());
    final meta = BookLibrary.metadata(data);
    RecordStore.validate('book', data);
    expect(meta['status'], 'unspecified');
    expect(meta['author'], '');
    expect(meta['pages'], isNull);
    expect(meta['startedOn'], '');
    expect(meta['finishedOn'], '');
    expect(meta['rating'], isNull);
    expect(jsonEncode(data), before);
    final changed = BookLibrary.update(data, {
      'author': 'Author',
      'status': 'reading',
      'pages': 250,
      'currentPage': 42,
    });
    RecordStore.validate('book', changed);
    expect(changed['chapters'], data['chapters']);
    expect(changed['bookmark'], 1);
    expect(changed['characters'], 'Original characters');
    expect(jsonEncode(data), before);
  });
  test('ISBN checks canonical 10/13 digits, X checksum and book prefixes without external lookup', () {
    expect(BookLibrary.isbn('0-306-40615-2'), '0306406152');
    expect(BookLibrary.isbn('978 0 306 40615 7'), '9780306406157');
    expect(BookLibrary.isbn('080442957x'), '080442957X');
    expect(BookLibrary.isbn('ISBN-13: ９７８‑０‑３０６‑４０６１５‑７'), '9780306406157');
    expect(BookLibrary.isbn(''), '');
    for (final bad in [
      '9780306406158',
      '0306406153',
      '123',
      '978030640615X',
      '0000000000000',
    ]) {
      expect(() => BookLibrary.isbn(bad), throwsFormatException, reason: bad);
    }
  });
  test('Metadata updates detach nested labels from both original and caller changes', () {
    final first = BookLibrary.update(legacy(), {
      'tags': ['Original'],
    });
    final next = BookLibrary.update(first, {'author': 'Different'});
    (next['library']['tags'] as List).add('New');
    expect(first['library']['tags'], ['Original']);
    final changes = {
      'shelves': <String>['One'],
    };
    final result = BookLibrary.update(first, changes);
    changes['shelves']!.add('Two');
    expect(result['library']['shelves'], ['One']);
  });
  test('Reading dates, known pages, ratings and label boundaries reject impossible metadata', () {
    for (final changes in <Map<String, dynamic>>[
      {'pages': 0},
      {'pages': 10, 'currentPage': 11},
      {'currentPage': -1},
      {'rating': 0},
      {'rating': 6},
      {'publicationYear': 0},
      {'status': 'fake'},
      {'startedOn': '2026-02-30'},
      {'startedOn': '2026-03-01', 'finishedOn': '2026-02-28'},
      {
        'tags': ['Duplicate', 'duplicate'],
      },
      {
        'shelves': ['   '],
      },
      {'author': 'a' * 1001},
    ]) {
      expect(
        () => BookLibrary.update(legacy(), changes),
        throwsFormatException,
        reason: '$changes',
      );
    }
    final valid = BookLibrary.update(legacy(), {
      'startedOn': '2024-02-29',
      'finishedOn': '2024-03-01',
      'pages': null,
      'currentPage': 200,
      'status': 'completed',
    });
    RecordStore.validate('book', valid);
    expect(valid['library']['pages'], isNull);
    expect(BookLibrary.labels(' Work,work\nPersonal،Study '), [
      'Work',
      'Personal',
      'Study',
    ]);
    expect(BookLibrary.labels('文學，歷史、宗教'), ['文學', '歷史', '宗教']);
    expect(bookInteger('２５０'), 250);
    expect(bookInteger('١٢٣'), 123);
    expect(bookInteger('۰۰۴۲'), 42);
    expect(() => bookInteger('1.5'), throwsFormatException);
    expect(() => bookInteger('-1'), throwsFormatException);
    expect(() => bookInteger('99999999999999999999999'), throwsFormatException);
  });
  test('Unknown and malformed library versions fail closed before update without changing input', () {
    for (final version in [2, 1.0, '1']) {
      final data = BookLibrary.update(legacy(), {});
      data['libraryVersion'] = version;
      final before = jsonEncode(data);
      expect(
        () => BookLibrary.update(data, {'author': 'Overwrite'}),
        throwsFormatException,
      );
      expect(() => RecordStore.validate('book', data), throwsFormatException);
      expect(jsonEncode(data), before);
    }
    final missing = legacy()..['library'] = {};
    expect(() => RecordStore.validate('book', missing), throwsFormatException);
  });
  test('Readable export includes complete owner metadata and original text while leaving unknown dates empty', () {
    final data = BookLibrary.update(legacy(), {
      'author': 'Saved author',
      'description': 'Full private description',
      'isbn': '9780306406157',
      'tags': ['My tag'],
      'shelves': ['Home'],
      'rating': 4,
    });
    final text = BookLibrary.readable(
      data,
      label: (key) => key,
      date: (raw) => raw,
    );
    for (final content in [
      'Saved author',
      'Full private description',
      '9780306406157',
      'My tag',
      'Home',
      '4 / 5',
      'Complete saved content',
      'Second chapter',
      'Original characters',
      'bStatusunspecified',
    ]) {
      expect(text, contains(content));
    }
    expect(text, isNot(contains('bStartedOn')));
    expect(text, isNot(contains('bFinishedOn')));
  });
}
