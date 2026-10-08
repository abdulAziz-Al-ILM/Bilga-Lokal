import 'package:bilga/app/home_page.dart';
import 'package:bilga/core/settings.dart';
import 'package:bilga/core/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(Strings.load);
  testWidgets('Carousel wraps in both directions without large-text overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: bilgaTheme('forest', Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();
    final pager = find.byType(PageView).first;
    for (var i = 0; i < 5; i++) {
      await tester.drag(pager, const Offset(-240, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    for (var i = 0; i < 5; i++) {
      await tester.drag(pager, const Offset(240, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
