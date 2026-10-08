import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bilga/core/editor_form.dart';
import 'package:bilga/core/strings.dart';

void main() {
  testWidgets(
    'Failed persistence retains input; retry closes only after saving',
    (tester) async {
      Strings.catalogs['en'] = {
        'save': 'Save',
        'title': 'Title',
        'saveError': 'Not saved',
        'cancel': 'Cancel',
      };
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Edit'),
                onPressed: () => editFields(
                  context,
                  'Record',
                  {'title': 'Title'},
                  requiredFields: {'title'},
                  onSave: (values) async {
                    attempts++;
                    expect(values['title'], 'Private entry');
                    if (attempts == 1) throw StateError('disk failure');
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Private entry');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Not saved'), findsOneWidget);
      expect(find.text('Private entry'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
}
