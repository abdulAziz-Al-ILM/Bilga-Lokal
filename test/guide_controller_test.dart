import 'dart:convert';

import 'package:bilga/features/guidance/guide_controller.dart';
import 'package:bilga/features/habits/habit_templates.dart';
import 'package:bilga/features/habits/habit_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GuideController controller({int version = 1}) => GuideController(
  id: 'test',
  version: version,
  steps: const [
    GuideStep('name', 'field', 'name', event: 'typed'),
    GuideStep('review', 'field', 'review'),
    GuideStep('save', 'save', 'save', event: 'persisted'),
    GuideStep('done', 'progress', 'done', backBoundary: true),
  ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Required actions cannot be bypassed by Next; saves are not replayed',
    () async {
      final c = controller();
      c.start();
      c.next();
      c.event('unrelated');
      expect(c.index, 0);
      c.event('typed');
      expect(c.index, 1);
      c.back();
      expect(c.index, 0);
      c.event('typed');
      c.next();
      expect(c.index, 2);
      c.next();
      expect(c.index, 2);
      c.event('persisted');
      expect(c.index, 3);
      c.back();
      expect(c.index, 3);
      c.event('persisted');
      expect(c.index, 3);
      c.next();
      expect(c.active, false);
      await c.flush();
      c.dispose();
    },
  );
  test('Ordered local progress resumes explicitly and resets without a restored draft', () async {
    final c = controller()..start();
    c.event('typed');
    c.next();
    await c.flush();
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('bilga.guide.test')!);
    expect(saved, {'version': 1, 'step': 'save', 'active': true});
    c.dispose();
    final resumed = controller();
    expect(resumed.active, false);
    expect(await resumed.hasPending(), true);
    await resumed.resume(draftAvailable: true);
    expect(resumed.index, 2);
    await resumed.resume();
    expect(resumed.index, 0);
    resumed.exit();
    await resumed.flush();
    expect(await resumed.hasPending(), false);
    resumed.dispose();
  });
  test(
    'Malformed and newer-version preferences cannot fabricate completion',
    () async {
      final prefs = await SharedPreferences.getInstance();
      for (final raw in [
        'broken',
        '[]',
        '{"version":9,"active":true,"step":"done"}',
      ]) {
        await prefs.setString('bilga.guide.test', raw);
        final c = controller();
        expect(await c.hasPending(), false);
        await c.resume(draftAvailable: true);
        expect(c.index, 0);
        c.exit();
        await c.flush();
        c.dispose();
      }
    },
  );
  test('22 bundled templates are valid independent drafts and cover requested habits', () {
    expect(habitTemplates.length, 22);
    expect(habitTemplates.map((t) => t.id).toSet().length, 22);
    for (final t in habitTemplates) {
      final a = t.plan((s) => s), b = t.plan((s) => s);
      HabitPlan.decode(a.encode());
      a.weekdays.clear();
      a.entries['mutated'] = true;
      expect(b.weekdays, isNotEmpty);
      expect(b.entries, isEmpty);
    }
    expect(
      habitTemplates.map((t) => t.id),
      containsAll([
        'water',
        'walk',
        'exercise',
        'sleep',
        'read',
        'math',
        'language',
        'lessons',
        'plan',
        'important',
        'distractions',
        'journal',
        'reflect',
        'skill',
      ]),
    );
  });
}
