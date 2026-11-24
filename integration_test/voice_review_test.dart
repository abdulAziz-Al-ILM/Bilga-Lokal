import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/voice_ui_cases.dart';
import '../test/voice_screen_test.dart' show registerVoiceScreenCases;
import 'review_guard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  if (!const bool.fromEnvironment('BILGA_REVIEW_SCREEN_ONLY')) {
    registerVoiceUiCases(
      createDirectory: () async {
        await requireReviewPackage();
        return (await getTemporaryDirectory()).createTemp('review-voice-');
      },
      secure: true,
      includeCompact: false,
    );
  }
  registerVoiceScreenCases();
}
