import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/settings.dart';
import '../../../core/strings.dart';
import '../note_database.dart';
import '../notes_changes.dart';
import 'notes_widget_bridge.dart';
import 'notes_widget_data.dart';
import 'notes_widget_loading.dart';

class NotesWidgetSync {
  final bool Function() canRead;
  final Future<Database> Function() database;
  NotesWidgetSync({
    required this.canRead,
    Future<Database> Function()? database,
  }) : database = database ?? (() => NoteDatabase.database);
  StreamSubscription<void>? _changes;
  Timer? _timer;
  Future<void>? _work;
  bool _dirty = false, _disposed = false;

  void start() {
    _changes = NotesChanges.events.listen((_) => schedule());
    AppSettings.instance.addListener(schedule);
    unawaited(refresh());
  }

  void schedule() {
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 120),
      () => unawaited(refresh()),
    );
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    _dirty = true;
    return _work ??= _run().whenComplete(() => _work = null);
  }

  Future<void> _run() async {
    while (_dirty && !_disposed) {
      _dirty = false;
      try {
        if (!canRead()) {
          await NotesWidgetBridge.channel.invokeMethod<void>('redact');
          continue;
        }
        final configs = (await NotesWidgetLoading.step(
          'sync.store',
          NotesWidgetBridge.configs,
        )).map(NotesWidgetConfig.fromMap).toList();
        if (configs.isEmpty || _disposed) continue;
        final settings = AppSettings.instance;
        final labels = {
          for (final key in [
            'notes',
            'note',
            'untitled',
            'newNote',
            'search',
            'profile',
            'empty',
            'widgetHidden',
          ])
            key: Strings.get(settings.language, key),
        };
        final scheme = bilgaTheme(
          settings.palette,
          settings.brightness,
        ).colorScheme;
        final data = NotesWidgetData(
          await NotesWidgetLoading.step('sync.database', database),
        );
        final widgets = <Map<String, Object?>>[];
        for (final config in configs) {
          widgets.add({
            'id': config.id,
            'revision': config.revision,
            'permissionEpoch': config.permissionEpoch,
            'rows': await NotesWidgetLoading.step(
              'sync.snapshot',
              () =>
                  data.snapshot(config, labels, forceHidden: settings.appLock),
            ),
          });
        }
        if (!canRead() || _disposed) {
          if (!_disposed) {
            await NotesWidgetBridge.channel.invokeMethod<void>('redact');
          }
          continue;
        }
        await NotesWidgetBridge.channel.invokeMethod<void>('publish', {
          'widgets': widgets,
          'language': settings.language,
          'labels': labels,
          'forceHidden': settings.appLock,
          'background': scheme.surface.toARGB32(),
          'foreground': scheme.onSurface.toARGB32(),
          'accent': scheme.primary.toARGB32(),
        });
      } on MissingPluginException {
        // Android-only integration. No alternate plaintext persistence.
      } catch (_) {
        try {
          await NotesWidgetBridge.channel.invokeMethod<void>('redact');
        } catch (_) {
          /* Fail closed on native side too. */
        }
      }
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_changes?.cancel());
    AppSettings.instance.removeListener(schedule);
  }
}
