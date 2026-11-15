import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/reading_ui_cases.dart';
import '../test/support/book_library_ui_cases.dart';
import '../test/support/reading_data_cases.dart';
import '../test/support/reading_pdf_ui_cases.dart';
import 'review_guard.dart';

Future<Directory> directory() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp('review-reading-');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  registerReadingDataCases(createDirectory: directory, secure: true);
  registerReadingUiCases(createDirectory: directory, secure: true);
  registerReadingPdfUiCases(createDirectory: directory, secure: true);
  registerBookLibraryUiTests(
    createDirectory: directory,
    secure: true,
    includeCompact: false,
  );
}
