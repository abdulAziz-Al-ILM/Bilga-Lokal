import 'package:flutter/material.dart';

import '../../../core/dialogs.dart';
import '../../../core/strings.dart';
import '../todo_changes.dart';
import 'todo_bridge.dart';

class TodoSettingsPage extends StatefulWidget {
  const TodoSettingsPage({super.key});
  @override
  State<TodoSettingsPage> createState() => _TodoSettingsPageState();
}

class _TodoSettingsPageState extends State<TodoSettingsPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? state;
  Map<String, dynamic> options = {};
  bool busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    try {
      final s = await TodoBridge.state();
      if (!mounted) return;
      setState(() {
        state = s;
        options = Map<String, dynamic>.from(s['settings'] as Map? ?? {});
      });
    } catch (_) {
      if (mounted) showError(context);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> save(String key, Object value) async {
    if (busy) return;
    if (value == true && key == 'overlay') {
      if (!await confirm(
        context,
        context.tr('reminderOverlayInfo'),
        title: context.tr('reminderOverlay'),
      )) {
        return;
      }
    }
    if (!mounted) return;
    if (value == true && key == 'showTitles') {
      if (!await confirm(
        context,
        context.tr('reminderPrivacy'),
        title: context.tr('reminderTitles'),
      )) {
        return;
      }
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      options[key] = value;
      await TodoBridge.channel.invokeMethod<void>('settings', options);
      TodoChanges.committed();
      if (key == 'overlay' && value == true && state?['overlay'] != true) {
        await TodoBridge.channel.invokeMethod<void>('permission', 'overlay');
      }
      await load();
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('reminderSettings'))),
    body: state == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final spec in [
                ('enabled', 'reminder', true),
                ('sound', 'reminderSound', true),
                ('overlay', 'reminderOverlay', false),
                ('showTitles', 'reminderTitles', false),
              ])
                SwitchListTile(
                  title: Text(context.tr(spec.$2)),
                  value: options[spec.$1] as bool? ?? spec.$3,
                  onChanged: busy ? null : (v) => save(spec.$1, v),
                ),
              Text(
                context.tr('reminderLimits'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final spec in [
                ('notifications', 'reminderNotifications'),
                ('exact', 'reminderExact'),
                ('overlay', 'reminderOverlay'),
                ('battery', 'reminderBattery'),
                ('channels', 'reminderSound'),
              ])
                ListTile(
                  title: Text(context.tr(spec.$2)),
                  subtitle:
                      spec.$1 == 'battery' &&
                          state!['batteryRestricted'] == true
                      ? Text(context.tr('reminderLimits'))
                      : null,
                  trailing: Icon(
                    spec.$1 == 'channels'
                        ? Icons.settings_outlined
                        : (state![spec.$1] == true
                              ? Icons.check_circle_outline
                              : Icons.settings_outlined),
                  ),
                  onTap: busy
                      ? null
                      : () async {
                          if (spec.$1 == 'overlay' &&
                              options['overlay'] != true) {
                            await save('overlay', true);
                            return;
                          }
                          if ((spec.$1 == 'exact' || spec.$1 == 'overlay') &&
                              !await confirm(
                                context,
                                context.tr(
                                  spec.$1 == 'overlay'
                                      ? 'reminderOverlayInfo'
                                      : 'reminderLimits',
                                ),
                              )) {
                            return;
                          }
                          await TodoBridge.channel.invokeMethod<void>(
                            'permission',
                            spec.$1,
                          );
                        },
                ),
            ],
          ),
  );
}
