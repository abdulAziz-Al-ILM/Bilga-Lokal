import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuideStep {
  final String id, target, text;
  final String? event;

  /// A confirmed write is a boundary: Back must never replay a saved action.
  final bool backBoundary;
  const GuideStep(
    this.id,
    this.target,
    this.text, {
    this.event,
    this.backBoundary = false,
  });
}

/// Deterministic local tutorial state. Events describe successful UI actions;
/// this controller never owns repositories, drafts or record identifiers.
class GuideController extends ChangeNotifier {
  final String id;
  final int version;
  final List<GuideStep> steps;
  final Future<SharedPreferences> Function() preferences;
  int _index = 0;
  bool _active = false, _disposed = false;
  final _satisfied = <String>{};
  Future<void> _writes = Future.value();
  GuideController({
    required this.id,
    required List<GuideStep> steps,
    this.version = 1,
    Future<SharedPreferences> Function()? preferences,
  }) : steps = List.unmodifiable(steps),
       preferences = preferences ?? SharedPreferences.getInstance {
    if (id.isEmpty ||
        version < 1 ||
        steps.isEmpty ||
        steps.map((s) => s.id).toSet().length != steps.length) {
      throw ArgumentError('guide_definition');
    }
  }
  bool get active => _active;
  int get index => _index;
  GuideStep get step => steps[_index];
  bool get canBack => _active && _index > 0 && !step.backBoundary;
  bool get canNext =>
      _active && (step.event == null || _satisfied.contains(step.id));
  String get _key => 'bilga.guide.$id';

  void start({int index = 0}) {
    if (index < 0 || index >= steps.length) {
      throw RangeError.index(index, steps);
    }
    _index = index;
    _satisfied.clear();
    _active = true;
    _changed();
  }

  /// Resume only an explicit user request. An editor without a restored draft
  /// restarts at its first field; it never silently repeats a save.
  Future<bool> hasPending() async {
    try {
      final raw = (await preferences()).getString(_key);
      if (raw == null) return false;
      final data = jsonDecode(raw);
      return data is Map &&
          data['version'] == version &&
          data['active'] == true &&
          steps.any((s) => s.id == data['step']);
    } catch (_) {
      return false;
    }
  }

  Future<void> resume({bool draftAvailable = false}) async {
    var index = 0;
    try {
      final raw = (await preferences()).getString(_key);
      final data = raw == null ? null : jsonDecode(raw);
      if (draftAvailable &&
          data is Map &&
          data['version'] == version &&
          data['active'] == true) {
        final found = steps.indexWhere((s) => s.id == data['step']);
        if (found >= 0 && !steps[found].backBoundary) index = found;
      }
    } catch (_) {
      /* Local help remains usable if preferences are unavailable. */
    }
    if (!_disposed) start(index: index);
  }

  void event(String event) {
    if (_active && step.event == event) {
      _satisfied.add(step.id);
      _advance();
    }
  }

  /// Text input becomes ready without moving the spotlight on the first key.
  /// The user confirms with Next; clearing the field removes that readiness.
  void satisfy(String event, {required bool valid}) {
    if (!_active || step.event != event) return;
    final changed = valid
        ? _satisfied.add(step.id)
        : _satisfied.remove(step.id);
    if (changed) _changed();
  }

  void next() {
    if (canNext) _advance();
  }

  void _advance() {
    if (_index == steps.length - 1) {
      exit();
      return;
    }
    _index++;
    _changed();
  }

  void back() {
    if (!canBack) return;
    _index--;
    _changed();
  }

  /// Skip and Exit end guidance only; neither operation touches user records.
  void exit() {
    _active = false;
    _changed();
  }

  void _changed() {
    if (_disposed) return;
    final snapshot = jsonEncode({
      'version': version,
      'step': step.id,
      'active': _active,
    });
    _writes = _writes.then((_) async {
      try {
        await (await preferences()).setString(_key, snapshot);
      } catch (_) {
        /* Help persistence is optional; saving user data is separate. */
      }
    });
    notifyListeners();
  }

  Future<void> flush() => _writes;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
