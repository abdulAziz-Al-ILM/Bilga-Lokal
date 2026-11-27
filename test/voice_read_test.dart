import 'dart:async';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/voice/speech_bridge.dart';
import 'package:bilga/features/voice/voice_command.dart';
import 'package:bilga/features/voice/voice_read_command.dart';
import 'package:bilga/features/voice/voice_screen_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/voice_ui_cases.dart' show ControlledSpeech;

void main() => registerVoiceReadCases();

void registerVoiceReadCases() {
  test('Natural read-aloud requests preserve folder and book actions', () {
    for (final request in [
      'Shu bo‘limdagi matnlarni o‘qib bering.',
      "Bu sahifani o'qib bera olasanmi?",
      'Read this text aloud, please.',
      'Прочитай этот текст вслух.',
    ]) {
      expect(VoiceReadCommand.parse(request), VoiceReadCommand.read);
    }
    expect(VoiceReadCommand.parse('Read my maths folder'), isNull);
    expect(VoiceReadCommand.parse('Continue reading'), isNull);
    for (final request in [
      'Qaydlar bo‘limidagi matnlarni o‘qib ber',
      'Read the notes section aloud',
      'Прочитай раздел заметки вслух',
    ]) {
      final command = VoiceCommand.parse(request);
      expect(command.action, VoiceAction.readSection);
      expect(command.argument, 'notes');
    }
  });

  test('Speech preparation preserves the end of long text after expanding Uzbek numbers', () {
    final parts = SpeechOutput.readingChunks(
      '${List.filled(400, '12 ta kitob.').join(' ')} Yakuniy jumla.',
      'uz-UZ',
    );
    expect(parts.every((text) => text.length <= 960), isTrue);
    expect('o\'n ikki ta kitob.'.allMatches(parts.join(' ')), hasLength(400));
    expect(parts.last, endsWith('Yakuniy jumla.'));
  });

  late List<MethodCall> output;
  Future<void> Function()? pending;
  const outputChannel = MethodChannel('bilga/speech_output');
  setUp(() {
    output = [];
    pending = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(outputChannel, (call) async {
          output.add(call);
          if (call.method == 'speak') await pending?.call();
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(outputChannel, null);
  });

  testWidgets(
    'A requested section is read once after opening and only while visible',
    (tester) async {
      await tester.runAsync(Strings.load);
      final routes = VoiceScreenNavigator();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routes],
          builder: (context, child) =>
              VoiceScreenHost(enabled: false, routes: routes, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(
                      name: VoiceScreenNavigator.readSectionRoute,
                    ),
                    builder: (_) =>
                        const Scaffold(body: Text('Requested section text')),
                  ),
                ),
                child: const Text('Open section and read'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open section and read'));
      await tester.pumpAndSettle();
      expect(
        output.single.arguments['text'],
        contains('Requested section text'),
      );
      expect(
        output.single.arguments['text'],
        isNot(contains('Open section and read')),
      );
    },
  );

  testWidgets('Read aloud excludes covered, hidden and password content', (
    tester,
  ) async {
    await tester.runAsync(Strings.load);
    final routes = VoiceScreenNavigator();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routes],
        builder: (context, child) =>
            VoiceScreenHost(enabled: false, routes: routes, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    body: Column(
                      children: [
                        const Text('Visible section content'),
                        const Offstage(child: Text('Hidden content')),
                        TextFormField(
                          initialValue: 'VeryPrivatePassword',
                          obscureText: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('Previous page content'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Previous page content'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice-read-open')));
    await tester.pumpAndSettle();
    final spoken =
        output.where((call) => call.method == 'speak').single.arguments['text']
            as String;
    expect(spoken, contains('Visible section content'));
    expect(
      spoken,
      isNot(contains(RegExp('Hidden content|Previous page|Password|[•●]{2}'))),
    );
  });

  testWidgets(
    'A spoken request reads full document text and pause resumes the interrupted chunk',
    (tester) async {
      await tester.runAsync(Strings.load);
      final routes = VoiceScreenNavigator();
      final speech = ControlledSpeech();
      final first = Completer<void>();
      pending = () => first.future;
      final body =
          '${List.filled(150, 'To‘liq jumla.').join(' ')} Oxirgi band.';
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [routes],
          builder: (context, child) => VoiceScreenHost(
            enabled: true,
            routes: routes,
            speech: speech,
            child: child!,
          ),
          home: VoiceReadRegion(
            read: () => body,
            child: const Scaffold(body: Text('An excerpt')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voice-screen-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voice-screen-speak')));
      await tester.pumpAndSettle();
      speech.pending!.complete('Shu matnni o‘qib ber');
      await tester.pumpAndSettle();
      final firstText = output.single.arguments['text'];
      expect(firstText, contains('To‘liq jumla.'));
      expect(firstText, isNot(contains('An excerpt')));
      expect(speech.followUps, [false]);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();
      expect(output.last.method, 'stop');
      first.complete();
      await tester.pumpAndSettle();
      expect(output.where((call) => call.method == 'speak'), hasLength(1));

      pending = null;
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();
      final spoken = output
          .where((call) => call.method == 'speak')
          .skip(1)
          .map((call) => call.arguments['text'] as String)
          .toList();
      expect(spoken.first, firstText);
      expect(spoken.join(' '), body);
    },
  );
}
