import 'package:flutter/material.dart';

import '../../../core/dialogs.dart';
import '../../../core/strings.dart';
import '../../collections/collection_repository.dart';
import '../todo_changes.dart';
import 'todo_bridge.dart';

Future<void> showTodoReminder(
  BuildContext context,
  Map<String, Object?> task, {
  bool snoozeOnly = false,
  CollectionRepository? repository,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) =>
        _Actions(task: task, snoozeOnly: snoozeOnly, repository: repository),
  );
}

class _Actions extends StatefulWidget {
  final Map<String, Object?> task;
  final bool snoozeOnly;
  final CollectionRepository? repository;
  const _Actions({
    required this.task,
    required this.snoozeOnly,
    this.repository,
  });
  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool busy = false;
  Future<void> act(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showError(context);
      }
    }
  }

  Future<void> snooze(int minutes) async {
    final now = DateTime.now();
    DateTime? at;
    if (minutes == -2) {
      final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: DateTime(now.year + 10),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          now.add(const Duration(minutes: 10)),
        ),
      );
      if (time == null || !mounted) return;
      at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    } else {
      at = minutes == -1
          ? DateTime(
              now.year,
              now.month,
              now.day + 1,
              now.hour,
              now.minute,
              now.second,
            )
          : now.add(Duration(minutes: minutes));
    }
    if (!at.isAfter(DateTime.now())) {
      if (mounted) showError(context, 'reminderFuture');
      return;
    }
    await act(() async {
      final ok = await TodoBridge.channel.invokeMethod<bool>('snooze', {
        'id': widget.task['id'],
        'at': at!.toIso8601String(),
      });
      if (ok != true) throw StateError('no_reminder');
      TodoChanges.committed();
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.task['title'] as String? ?? context.tr('task'),
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          if (!widget.snoozeOnly)
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => act(() async {
                      await (widget.repository ??
                              CollectionRepository(CollectionKind.todos))
                          .setField(widget.task['id'] as String, 'is_done', 1);
                    }),
              icon: const Icon(Icons.check),
              label: Text(context.tr('reminderDone')),
            ),
          Text(context.tr('reminderSnooze')),
          Wrap(
            spacing: 8,
            children: [
              for (final pair in [
                (5, 'snooze5'),
                (10, 'snooze10'),
                (30, 'snooze30'),
                (60, 'snooze60'),
                (-1, 'tomorrow'),
                (-2, 'snoozeCustom'),
              ])
                OutlinedButton(
                  onPressed: busy ? null : () => snooze(pair.$1),
                  child: Text(context.tr(pair.$2)),
                ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );
}
