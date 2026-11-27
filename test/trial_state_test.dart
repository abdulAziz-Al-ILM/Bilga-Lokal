import 'dart:convert';

import 'package:bilga/features/agent/trial_state.dart';
import 'package:bilga/features/agent/trial_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const install = '0123456789abcdef0123456789abcdef';
const day = Duration.millisecondsPerDay;
const start = 1791705600000;
TrialState initial() =>
    TrialState.start(const TrialClock(start, 1000, 10), install);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('First launch gives exactly 40 days, never paid ownership', () {
    final trial = initial();
    expect(trial.active, isTrue);
    expect(trial.remainingDays, 40);
    expect(trial.remainingMillis, 40 * day);
    expect(trial.introduced, isFalse);
  });
  test('Boundary: access ends at 40 days, not at the start of day 40', () {
    final trial = initial().advance(
      const TrialClock(start + 40 * day - 1, 1001, 10),
    );
    expect(trial.active, isTrue);
    expect(trial.remainingDays, 1);
    expect(
      trial.advance(const TrialClock(start + 40 * day, 1002, 10)).active,
      isFalse,
    );
  });
  test('Updating/reopening preserves start, introduction and installation', () {
    final trial = initial().advance(
      const TrialClock(start + day, 1000 + day, 10),
      introduced: true,
    );
    final restored = TrialState.fromJson(
      jsonDecode(jsonEncode(trial.toJson())),
    );
    expect(restored.started, start);
    expect(restored.installation, install);
    expect(restored.introduced, isTrue);
    expect(restored.remainingDays, 39);
  });
  test('Wall clock rollback cannot extend same-boot trial; sleep counts', () {
    var trial = initial().advance(
      const TrialClock(start + 10 * day, 1000 + 10 * day, 10),
    );
    trial = trial.advance(const TrialClock(start - day, 1000 + 11 * day, 10));
    expect(trial.remainingDays, 29);
    expect(trial.active, isTrue);
    trial = trial.advance(const TrialClock(start - day, 1000 + 40 * day, 10));
    expect(trial.active, isFalse);
  });
  test(
    'Rollback across reboot requires corrected clock; no silent renewal',
    () {
      var trial = initial().advance(
        const TrialClock(start + 10 * day, 1000 + 10 * day, 10),
      );
      trial = trial.advance(const TrialClock(start, 2000, 11));
      expect(trial.clockBlocked, isTrue);
      expect(trial.active, isFalse);
      trial = trial.advance(const TrialClock(start + 10 * day, 3000, 11));
      expect(trial.clockBlocked, isFalse);
      expect(trial.remainingMillis, lessThanOrEqualTo(30 * day));
      expect(trial.started, start);
    },
  );
  test('Reboot with correct date accounts for days app was closed', () {
    final trial = initial().advance(
      const TrialClock(start + 41 * day, 1000, 11),
    );
    expect(trial.active, isFalse);
    expect(trial.remainingDays, 0);
  });
  test('Forward clock then rollback cannot resurrect expired access', () {
    final trial = initial().advance(
      const TrialClock(start + 50 * day, 2000, 10),
    );
    expect(trial.advance(const TrialClock(start, 3000, 10)).active, isFalse);
  });
  test('Unsupported/corrupt trial schema fails instead of resetting start', () {
    expect(
      () => TrialState.fromJson(initial().toJson()..['version'] = 2),
      throwsFormatException,
    );
    expect(
      () => TrialState.fromJson(initial().toJson()..['effective'] = 0),
      throwsFormatException,
    );
    expect(
      () => TrialState.fromJson(initial().toJson()..['installation'] = ''),
      throwsFormatException,
    );
  });

  group('Android trial store contract', () {
    String? saved;
    bool failWrite = false;
    int wall = start, elapsed = 1000;
    setUp(() {
      saved = null;
      failWrite = false;
      wall = start;
      elapsed = 1000;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidTrialStore.channel, (call) async {
            if (call.method == 'read') {
              return {
                'state': saved,
                'wall': wall,
                'elapsed': elapsed,
                'boot': 10,
                'debug': true,
              };
            }
            if (failWrite) throw PlatformException(code: 'trial_storage');
            saved = call.arguments as String;
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidTrialStore.channel, null),
    );
    test(
      'First launch persists before access, later updates do not renew it',
      () async {
        final (first, debug) = await AndroidTrialStore().load(
          acknowledge: true,
        );
        expect(saved, isNotNull);
        expect(debug, isTrue);
        wall += day;
        elapsed += day;
        final (next, _) = await AndroidTrialStore().load();
        expect(next.started, first.started);
        expect(next.installation, first.installation);
        expect(next.introduced, isTrue);
        expect(next.remainingDays, 39);
      },
    );
    test('Write failure never returns a new active trial', () async {
      failWrite = true;
      await expectLater(
        AndroidTrialStore().load(),
        throwsA(isA<PlatformException>()),
      );
    });
    test('Corrupted state is not overwritten', () async {
      saved = '{broken';
      await expectLater(AndroidTrialStore().load(), throwsFormatException);
      expect(saved, '{broken');
    });
  });
}
