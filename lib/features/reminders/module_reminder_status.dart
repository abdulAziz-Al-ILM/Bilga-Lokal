import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import 'module_reminder_sync.dart';

class ModuleReminderStatus extends StatefulWidget {
  const ModuleReminderStatus({super.key});
  @override
  State<ModuleReminderStatus> createState() => _ModuleReminderStatusState();
}

class _ModuleReminderStatusState extends State<ModuleReminderStatus>
    with WidgetsBindingObserver {
  Map<String, dynamic>? status;
  ModuleReminderSync? sync;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sync = ModuleReminderSync.active;
    sync?.addListener(changed);
    load();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    try {
      final result = await ModuleReminderBridge.state();
      if (mounted) setState(() => status = result);
    } catch (_) {
      if (mounted) setState(() => status = {'available': false});
    }
  }

  Future<void> action(String name) async {
    try {
      await ModuleReminderBridge.action(name);
      await load();
    } catch (_) {
      if (mounted) failure(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sync?.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final available = status?['available'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c.tr('moduleReminderLimits')),
        if (sync?.failed == true)
          Text(
            c.tr('moduleReminderSyncError'),
            style: TextStyle(color: Theme.of(c).colorScheme.error),
          ),
        if (status != null && !available)
          Text(c.tr('moduleReminderUnavailable')),
        if (available)
          Text(
            c.tr(
              status!['notifications'] == true
                  ? 'moduleReminderAllowed'
                  : 'moduleReminderBlocked',
            ),
          ),
        if (available && status!['exact'] != true)
          Text(c.tr('moduleReminderApproximate')),
        if (available && status!['batteryRestricted'] == true)
          Text(c.tr('moduleReminderBattery')),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (available && status!['notifications'] != true)
              TextButton(
                onPressed: () => action('notifications'),
                child: Text(c.tr('moduleReminderPermission')),
              ),
            if (available && status!['exact'] != true)
              TextButton(
                onPressed: () => action('exact'),
                child: Text(c.tr('moduleReminderExact')),
              ),
            if (available)
              TextButton(
                onPressed: () => action('settings'),
                child: Text(c.tr('moduleReminderSettings')),
              ),
            TextButton(
              onPressed: () async {
                await sync?.refresh();
                await load();
              },
              child: Text(c.tr('retry')),
            ),
          ],
        ),
      ],
    );
  }
}
