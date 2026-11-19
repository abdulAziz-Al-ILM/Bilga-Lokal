import 'package:bilga/core/strings.dart';
import 'package:bilga/features/voice/voice_screen_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Screen voice reviews real controls and rechecks their availability',
    (tester) async {
      await tester.runAsync(Strings.load);
      final routes = VoiceScreenNavigator();
      final enabled = ValueNotifier<bool>(true);
      final title = TextEditingController();
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routes],
          builder: (context, child) =>
              VoiceScreenHost(enabled: true, routes: routes, child: child!),
          home: Scaffold(
            body: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: enabled,
                  builder: (context, value, _) => FilledButton(
                    onPressed: value ? () => saves++ : null,
                    child: const Text('Save note'),
                  ),
                ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> open() async {
        await tester.tap(find.byKey(const Key('voice-screen-open')));
        await tester.pumpAndSettle();
      }

      Future<void> review(String words) async {
        final field = find.byKey(const Key('voice-screen-input'));
        await tester.enterText(field, words);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }

      Future<void> confirm() async {
        final button = find.byKey(const Key('voice-screen-confirm'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await open();
      await review('Iltimos, saqla');
      expect(saves, 0);
      await confirm();
      expect(saves, 1);
      await open();
      await review('Title maydoniga Bilga’s draft deb yoz');
      expect(title.text, isEmpty);
      await confirm();
      expect(title.text, 'Bilga’s draft');
      await open();
      await review('Save note');
      enabled.value = false;
      await tester.pumpAndSettle();
      await confirm();
      expect(saves, 1);
      expect(
        find.text(Strings.get('en', 'voiceScreenChanged')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      enabled.dispose();
      title.dispose();
    },
  );
}
