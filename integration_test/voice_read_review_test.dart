import 'package:bilga/features/voice/speech_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/voice_read_test.dart' show registerVoiceReadCases;
import 'review_guard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  group('Read aloud controls', registerVoiceReadCases);

  testWidgets('Android synthesizer completes an Uzbek read-aloud excerpt', (
    tester,
  ) async {
    final parts = SpeechOutput.readingChunks(
      'Assalomu alaykum. Bilga bu matnni ovoz chiqarib o‘qiydi.',
      'uz-UZ',
    );
    await tester.runAsync(
      () => SpeechOutput.speakReadingChunk(parts.single, 'uz-UZ'),
    );
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
