import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import 'trial_state.dart';

abstract interface class TrialStore {
  Future<(TrialState, bool)> load({bool acknowledge = false});
}

class AndroidTrialStore implements TrialStore {
  static const channel = MethodChannel('bilga/trial');
  @override
  Future<(TrialState, bool)> load({bool acknowledge = false}) async {
    final response = await channel.invokeMapMethod<Object?, Object?>('read');
    if (response == null) throw StateError('trial_unavailable');
    final clock = TrialClock.fromJson(response);
    final raw = response['state'] as String?;
    final state = raw == null
        ? TrialState.start(
            clock,
            List.generate(
              16,
              (_) => Random.secure().nextInt(256),
            ).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
          )
        : TrialState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final next = state.advance(clock, introduced: acknowledge ? true : null);
    // Only expose access after persistence succeeded.
    await channel.invokeMethod<void>('write', jsonEncode(next.toJson()));
    return (next, response['debug'] == true);
  }
}
