import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/voice_ui_cases.dart';
import 'review_guard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerVoiceUiCases(
    createDirectory: () async {
      await requireReviewPackage();
      return (await getTemporaryDirectory()).createTemp('review-voice-');
    },
    secure: true,
    includeCompact: false,
  );
}
