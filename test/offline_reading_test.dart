import 'dart:async';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_command.dart';
import 'package:bilga/features/agent/voice/reading_controller.dart';
import 'package:bilga/features/agent/voice/voice_languages.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeOutput implements OfflineReadingOutput {
  final spoken = <String>[];
  Completer<bool>? current;
  bool paused = false;
  int position = 0;
  @override
  Future<bool> speak(String text, String language) {
    spoken.add(text);
    position = 0;
    current = Completer<bool>();
    return current!.future;
  }

  void finish() {
    if (current?.isCompleted == false) current!.complete(true);
  }

  @override
  Future<void> pause() async {
    paused = true;
  }

  @override
  Future<void> resume() async {
    paused = false;
  }

  @override
  Future<void> stop() async {
    if (current?.isCompleted == false) current!.complete(false);
    paused = false;
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('Every application language has reading vocabulary', () {
    expect(voiceLanguages.keys.toSet(), languages.keys.toSet());
    expect(voiceAvailabilityMessages.keys.toSet(), languages.keys.toSet());
  });
  for (final entry in voiceLanguages.entries) {
    test(
      '${entry.key}: all stop/resume/read aliases and cross-language routing',
      () {
        for (final intent in ReadingIntent.values) {
          for (final alias in entry.value.aliases(intent)) {
            final parsed = parseReadingCommand(
              '$alias!',
              preferredLanguage: entry.key,
            );
            expect(parsed?.intent, intent, reason: '$alias in ${entry.key}');
            final command = parseAgentCommand(
              alias,
              preferredLanguage: 'uz-UZ',
            );
            expect(command.action, switch (intent) {
              ReadingIntent.pause => AgentAction.pauseReading,
              ReadingIntent.resume => AgentAction.resumeReading,
              ReadingIntent.read => AgentAction.findNotes,
            });
          }
        }
        expect(
          parseReadingCommand(
            '${entry.value.read.first}: Project',
            preferredLanguage: entry.key,
          )?.argument,
          'Project',
        );
        expect(textLanguage('12345', entry.key), entry.key);
        expect(
          voiceAvailabilityText(entry.key, 'unavailable'),
          voiceAvailabilityMessages[entry.key]!.$2,
        );
        expect(
          voiceAvailabilityText(entry.key, 'unknown'),
          voiceAvailabilityMessages[entry.key]!.$3,
        );
      },
    );
  }
  test(
    'Control words cannot swallow note titles, music commands or mutations',
    () {
      expect(parseAgentCommand('stop music').action, AgentAction.stopMusic);
      expect(parseAgentCommand('create note: stop').action, AgentAction.note);
      expect(
        parseAgentCommand('stop everything and delete').action,
        AgentAction.unknown,
      );
      expect(parseAgentCommand('read note: Hello').argument, 'Hello');
      expect(
        parseAgentCommand('oʻqib ber: Salom', preferredLanguage: 'uz').argument,
        'Salom',
      );
    },
  );
  test('Long content preserves every character including surrogate pairs', () {
    final text =
        '${'😀Long note.\n' * 3000}${'x' * 6000} x${'😀' * 2000}  \nFinal.';
    final chunks = readingChunks(text, 'en');
    expect(chunks.map((c) => c.text).join(), text);
    expect(chunks.every((c) => c.text.length <= 1200), isTrue);
    for (final chunk in chunks) {
      expect(
        text.substring(chunk.start, chunk.start + chunk.text.length),
        chunk.text,
      );
      expect(
        chunk.text.codeUnitAt(chunk.text.length - 1),
        isNot(inInclusiveRange(0xd800, 0xdbff)),
      );
    }
  });
  test('Mixed sentence language hints and ambiguous Latin fallback', () {
    final chunks = readingChunks(
      'Hello there. Привет мир. Salom do‘stim. 日本語です。',
      'uz',
    );
    expect(chunks.map((c) => c.language).toList(), ['en', 'ru', 'uz', 'ja']);
    expect(textLanguage('Documento', 'it'), 'it');
  });
  test(
    'Pause and resume retain current audio position without repeating text',
    () async {
      final output = FakeOutput();
      final reader = ReadingController(output);
      final reading = reader.read('First. Second. Third.', 'en');
      await tick();
      output.position = 1733;
      await reader.pause();
      await reader.resume();
      expect(output.position, 1733);
      expect(output.spoken.length, 1);
      output.finish();
      await tick();
      await reader.pause();
      output.finish();
      await tick();
      expect(reader.index, 2);
      expect(output.spoken.length, 2);
      await reader.resume();
      await tick();
      output.finish();
      await reading;
      expect(output.spoken.join(), 'First. Second. Third.');
      expect(reader.active, isFalse);
      reader.dispose();
    },
  );
  test(
    'Replacement and stop ignore late completion from older reading',
    () async {
      final output = FakeOutput();
      final reader = ReadingController(output);
      final first = reader.read('Old. Never.', 'en');
      await tick();
      final second = reader.read('New. End.', 'en');
      await tick();
      await first;
      expect(output.spoken, ['Old.', 'New.']);
      await reader.stop();
      await second;
      expect(output.spoken, ['Old.', 'New.']);
      reader.dispose();
    },
  );
  test(
    'Reading longer than original 3500 limit reaches its final text',
    () async {
      final output = FakeOutput();
      final reader = ReadingController(output);
      final text = '${'a' * 10000} FINAL';
      final result = reader.read(text, 'en');
      await tick();
      while (reader.active) {
        output.finish();
        await tick();
      }
      await result;
      expect(output.spoken.join(), text);
      reader.dispose();
    },
  );
}
