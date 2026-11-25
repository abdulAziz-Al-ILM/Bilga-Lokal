import 'package:bilga/features/voice/speech_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;
import 'support/voice_ui_cases.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  test('Recognizer selection is stored separately for each language', () async {
    SharedPreferences.setMockInitialValues({});
    await SpeechBridge().setDeviceRecognizerPreference('uz-UZ', false);
    expect(await SpeechBridge().prefersDeviceRecognizer('uz-UZ'), isFalse);
    expect(await SpeechBridge().prefersDeviceRecognizer('en-US'), isTrue);
    expect(await SpeechBridge().prefersDeviceRecognizer('ru-RU'), isTrue);
  });
  test(
    'Recognition retains at most two distinct alternative transcripts',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(
        () => messenger.setMockMethodCallHandler(SpeechBridge.channel, null),
      );
      messenger.setMockMethodCallHandler(SpeechBridge.channel, (call) async {
        expect(call.method, 'listen');
        return {
          'text': ' primary ',
          'alternatives': [
            'primary',
            null,
            ' ',
            'next ',
            'next',
            'other',
            'extra',
          ],
        };
      });
      final result = await SpeechBridge().recognize(
        language: 'uz-UZ',
        onDevice: true,
      );
      expect(result?.text, 'primary');
      expect(result?.alternatives, ['next', 'other']);
    },
  );
  registerVoiceUiCases();
}
