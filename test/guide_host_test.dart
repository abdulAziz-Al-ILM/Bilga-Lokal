import 'package:bilga/core/strings.dart';
import 'package:bilga/features/guidance/guide_controller.dart';
import 'package:bilga/features/guidance/guide_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Strings.load();
  });
  testWidgets(
    'Actual target accepts taps while outside actions are blocked; rotation relocates spotlight',
    (t) async {
      final anchor = GlobalKey();
      final c = GuideController(
        id: 'tap',
        steps: const [GuideStep('action', 'real', 'hgTitle', event: 'success')],
      );
      var inside = 0, outside = 0;
      await t.pumpWidget(
        MaterialApp(
          home: GuideHost(
            controller: c,
            targets: {'real': anchor},
            child: Scaffold(
              body: Column(
                children: [
                  FilledButton(
                    key: anchor,
                    onPressed: () => inside++,
                    child: const Text('Real target'),
                  ),
                  FilledButton(
                    key: const Key('outside'),
                    onPressed: () => outside++,
                    child: const Text('Outside'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      c.start();
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.tapAt(t.getCenter(find.byKey(const Key('outside'))));
      expect(outside, 0);
      await t.tap(find.text('Real target'));
      expect(inside, 1);
      t.view.physicalSize = const Size(1000, 500);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text('Real target'));
      expect(inside, 2);
      c.event('success');
      await t.pump();
      await t.tap(find.byKey(const Key('outside')));
      expect(outside, 1);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await c.flush();
      c.dispose();
    },
  );
  testWidgets(
    'Missing target gives accessible fallback and Exit with large RTL text and keyboard insets',
    (t) async {
      final c = GuideController(
        id: 'missing',
        steps: const [GuideStep('read', 'missing', 'hgTitle')],
      );
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 300),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          home: GuideHost(
            controller: c,
            targets: const {},
            child: const Scaffold(),
          ),
        ),
      );
      c.start();
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text(Strings.get('en', 'gMissing')), findsOneWidget);
      final exit = find.byKey(const Key('guide-exit'));
      await t.ensureVisible(exit);
      await t.tap(exit);
      await t.pump();
      expect(c.active, false);
      expect(t.takeException(), isNull);
      semantics.dispose();
      await t.pumpWidget(const SizedBox());
      await c.flush();
      c.dispose();
    },
  );
}
