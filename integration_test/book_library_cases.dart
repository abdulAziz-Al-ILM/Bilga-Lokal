import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/book_library_data_cases.dart';
import '../test/support/book_library_ui_cases.dart';
import 'review_guard.dart';

Future<Directory> _directory() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp('review-book-library-');
}

void registerBookLibraryCases(IntegrationTestWidgetsFlutterBinding binding) {
  group(
    'Encrypted book library',
    () =>
        registerBookLibraryDataTests(createDirectory: _directory, secure: true),
  );
  registerBookLibraryUiTests(
    createDirectory: _directory,
    secure: true,
    includeCompact: false,
    onUiVerified: () => binding.reportData = {
      ...?binding.reportData,
      'bookLibrary': {
        'encryptedFixtures': true,
        'realCreateValidateFilterSearch': true,
        'legacyChaptersAndBookmarkPreserved': true,
        'syntheticEntitlementOnly': true,
      },
    },
  );
}
