import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/book_library_ui_cases.dart';
import 'review_guard.dart';

Future<Directory> _directory() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp('review-book-editor-');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  registerBookLibraryUiTests(
    createDirectory: _directory,
    secure: true,
    includeCompact: false,
    onUiVerified: () => binding.reportData = {
      'bookLibraryUi': {
        'realCreateValidateFilterSearch': true,
        'encryptedTemporaryFixtures': true,
        'realFieldRefocusedBeforeFixtureInput': true,
        'manualKeyboardAcceptance': false,
        'syntheticEntitlementOnly': true,
      },
    },
  );
}
