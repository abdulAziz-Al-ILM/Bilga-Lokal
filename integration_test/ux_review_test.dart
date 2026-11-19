import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/ux_data_cases.dart';
import '../test/support/ux_ui_cases.dart';
import '../test/support/finance_planning_ui_cases.dart';
import '../test/support/habit_advanced_ui_cases.dart';
import 'review_guard.dart';

Future<Directory> fixture() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp('review-ux-');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  testWidgets(
    'Actual Android speech engine handles a synthetic message in selected languages',
    (tester) async {
      await requireReviewPackage();
      const channel = MethodChannel('bilga/speech_output');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      for (final (language, text) in [
        ('en-US', 'Bilga Review. Speech output test.'),
        ('uz-UZ', 'Bilga sinovi. Ovozli javob.'),
        ('ru-RU', 'Билга. Проверка голосового ответа.'),
      ]) {
        final result = await tester.runAsync(() async {
          try {
            await channel
                .invokeMethod<void>('speak', {
                  'language': language,
                  'text': text,
                  'rate': 1.1,
                })
                .timeout(const Duration(seconds: 25));
            return 'synthesis-complete';
          } on PlatformException catch (error) {
            if (error.code != 'language') rethrow;
            return 'no-installed-voice';
          } finally {
            await channel.invokeMethod<void>('stop');
          }
        });
        expect(result, anyOf('synthesis-complete', 'no-installed-voice'));
        // Synthetic text only. Engine completion alone does not measure audibility.
        debugPrint('BILGA_REVIEW_TTS $language $result');
      }
    },
  );
  group(
    'UX data, backup and real record retrieval',
    () => registerUxDataCases(fixture: fixture, secure: true),
  );
  group(
    'Quick Finance and Habit quantity screens',
    () => registerUxUiCases(fixture: fixture, secure: true),
  );
  group(
    'Preserved Finance planning and guides',
    () => registerFinancePlanningUiCases(
      createDirectory: fixture,
      secure: true,
      includeCompact: false,
    ),
  );
  group(
    'Preserved Habit statistics and scheduling',
    () => registerAdvancedHabitUiCases(
      createDirectory: fixture,
      secure: true,
      includeCompact: false,
    ),
  );
}
