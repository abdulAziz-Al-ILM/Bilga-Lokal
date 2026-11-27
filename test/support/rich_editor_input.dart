import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercise the editor's content-change path; IME/privacy is tested separately.
Future<void> enterNoteBody(WidgetTester tester, String text) async {
  final editor = tester.widget<QuillEditor>(find.byKey(const Key('note-body')));
  editor.controller.replaceText(
    0,
    editor.controller.document.length - 1,
    text,
    TextSelection.collapsed(offset: text.length),
  );
  await tester.pump();
}
