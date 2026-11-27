import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_lock.dart';
import '../../../core/strings.dart';
import '../../agent/agent_access.dart';
import '../../collections/collection_page.dart';
import '../../collections/collection_repository.dart';
import '../note_database.dart';
import '../note_editor_page.dart';
import 'notes_widget_bridge.dart';
import 'notes_widget_config_page.dart';
import 'notes_widget_data.dart';
import 'notes_widget_sync.dart';

/// Inside the existing app-lock/access gates and the app's Navigator.
class NotesWidgetHost extends StatefulWidget {
  final Widget child;
  const NotesWidgetHost({super.key, required this.child});
  @override
  State<NotesWidgetHost> createState() => _NotesWidgetHostState();
}

class _NotesWidgetHostState extends State<NotesWidgetHost>
    with WidgetsBindingObserver {
  late final NotesWidgetSync sync;
  final pending = <Map<String, dynamic>>[];
  bool locked = true, opening = false;
  bool get allowed {
    final access = AgentAccess.instance;
    return mounted &&
        !locked &&
        (!access.initialized ||
            (access.coreAllowed &&
                !(access.trialActive &&
                    !access.corePurchased &&
                    access.trial?.introduced == false)));
  }

  @override
  void initState() {
    super.initState();
    sync = NotesWidgetSync(canRead: () => allowed)..start();
    WidgetsBinding.instance.addObserver(this);
    AgentAccess.instance.addListener(changed);
    NotesWidgetBridge.channel.setMethodCallHandler((call) async {
      if (call.method == 'launch') await consume();
      if (call.method == 'refresh') {
        await sync.refresh();
        await consume();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => consume());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    locked = AppLockScope.isLocked(context);
    changed();
  }

  void changed() {
    if (!mounted) return;
    unawaited(sync.refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => drain());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      changed();
      unawaited(consume());
    }
  }

  Future<void> consume() async {
    try {
      final launch = await NotesWidgetBridge.channel
          .invokeMapMethod<String, dynamic>('consumeLaunch');
      if (launch != null) pending.add(launch);
      await drain();
    } on MissingPluginException {
      // Widget launch intents are available only on Android.
    }
  }

  Future<void> drain() async {
    if (!allowed || opening || pending.isEmpty) return;
    opening = true;
    final launch = pending.removeAt(0);
    try {
      Widget page;
      switch (launch['action']) {
        case 'configure':
          page = NotesWidgetConfigPage(
            widgetId: launch['id'] as int,
            sync: sync,
            canRead: () => allowed,
          );
        case 'create':
          page = const NoteEditorPage();
        case 'search':
          page = const CollectionPage(
            kind: CollectionKind.notes,
            initialSearch: true,
          );
        case 'open':
          final id = launch['noteId'] as String?;
          if (id == null || id.isEmpty) return;
          final notes = await NotesWidgetData(await NoteDatabase.database)
              .available(
                NotesWidgetConfig(
                  id: launch['id'] as int,
                  source: WidgetSource.pinned,
                  pinnedIds: [id],
                ),
              );
          if (!allowed) {
            pending.insert(0, launch);
            return;
          }
          if (notes.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(context.tr('empty'))));
            }
            page = const CollectionPage(kind: CollectionKind.notes);
          } else {
            page = NoteEditorPage(note: notes.single);
          }
        case 'list':
          page = const CollectionPage(kind: CollectionKind.notes);
        default:
          return;
      }
      if (!mounted || !allowed) return;
      final closed = Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => page));
      // A warm widget intent may open another note while an earlier editor is
      // still on the navigation stack. Preserve that editor and its autosave.
      unawaited(closed.then((_) => sync.refresh()));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('error'))));
      }
    } finally {
      opening = false;
      if (mounted) {
        await sync.refresh();
        unawaited(drain());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AgentAccess.instance.removeListener(changed);
    NotesWidgetBridge.channel.setMethodCallHandler(null);
    sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
