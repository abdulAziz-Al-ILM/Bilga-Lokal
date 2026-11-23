import 'package:bilga/core/strings.dart';
import 'package:bilga/features/voice/voice_screen_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/voice_ui_cases.dart' show ControlledSpeech;

void main() {
  registerVoiceScreenCases();

  testWidgets('Voice controls fit above the keyboard on a short screen', (
    tester,
  ) async {
    await tester.runAsync(Strings.load);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 440);
    addTearDown(tester.view.reset);
    final routes = VoiceScreenNavigator();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routes],
        builder: (context, child) =>
            VoiceScreenHost(enabled: true, routes: routes, child: child!),
        home: const Scaffold(body: TextField()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice-screen-open')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 380);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(VoiceScreenHost), findsOneWidget);
  });
}

void registerVoiceScreenCases() {
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
            body: ListView(
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

      Future<void> tapVisible(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Future<void> confirm() =>
          tapVisible(find.byKey(const Key('voice-screen-confirm')));

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
      await review('Type Bilga draft into the title field');
      expect(title.text, 'Bilga’s draft');
      await confirm();
      expect(title.text, 'Bilga draft');
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

  testWidgets('One microphone tap lets the user review and confirm a control', (
    tester,
  ) async {
    await tester.runAsync(Strings.load);
    final routes = VoiceScreenNavigator();
    final speech = ControlledSpeech();
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routes],
        builder: (context, child) => VoiceScreenHost(
          enabled: true,
          routes: routes,
          speech: speech,
          child: child!,
        ),
        home: Scaffold(
          body: FilledButton(
            onPressed: () => saves++,
            child: const Text('Save note'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice-screen-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice-screen-speak')));
    await tester.pump();
    speech.pending!.complete('Save note');
    await tester.pump();
    expect(saves, 0);
    await tester.pump(const Duration(milliseconds: 700));
    expect(speech.followUps, [false, true]);
    speech.pending!.complete('Tasdiqlayman');
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(speech.followUps, [false, true]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
