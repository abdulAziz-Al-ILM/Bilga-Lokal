import 'package:flutter/material.dart';

import 'strings.dart';

void failure(BuildContext c) {
  ScaffoldMessenger.of(c)
      .showSnackBar(SnackBar(content: Text(c.tr('saveError'))));
}

Future<bool> consent(BuildContext c, String text) async =>
    await showDialog<bool>(
      context: c,
      builder: (c) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr('continue')),
          ),
        ],
      ),
    ) ??
    false;
Future<Map<String, String>?> editFields(
  BuildContext c,
  String title,
  Map<String, String> labels, {
  Map<String, String> initial = const {},
  Set<String> multiline = const {},
  Future<void> Function(Map<String, String>)? onSave,
  Set<String> requiredFields = const {},
  Set<String> weekdayFields = const {},
  Set<String> dateFields = const {},
  Set<String> numberFields = const {},
}) => Navigator.push(
  c,
  MaterialPageRoute(
    builder: (_) => _FormPage(
      title,
      labels,
      initial,
      multiline,
      onSave,
      requiredFields,
      weekdayFields,
      dateFields,
      numberFields,
    ),
  ),
);

class _FormPage extends StatefulWidget {
  final String title;
  final Map<String, String> labels, initial;
  final Set<String> multiline;
  final Future<void> Function(Map<String, String>)? onSave;
  final Set<String> requiredFields, weekdayFields, dateFields, numberFields;
  const _FormPage(
    this.title,
    this.labels,
    this.initial,
    this.multiline,
    this.onSave,
    this.requiredFields,
    this.weekdayFields,
    this.dateFields,
    this.numberFields,
  );
  @override
  State<_FormPage> createState() => _FormState();
}

class _FormState extends State<_FormPage> {
  late final controllers = {
    for (final k in widget.labels.keys)
      k: TextEditingController(text: widget.initial[k] ?? ''),
  };
  bool leaving = false, saving = false;
  String? error;
  bool get dirty => controllers.entries.any(
    (e) => e.value.text != (widget.initial[e.key] ?? ''),
  );
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && (leaving || !dirty),
    onPopInvokedWithResult: (did, _) async {
      if (!did &&
          !saving &&
          await consent(context, context.tr('discardChanges')) &&
          mounted) {
        setState(() => leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: saving
                ? null
                : () async {
                    final values = {
                      for (final e in controllers.entries) e.key: e.value.text,
                    };
                    if (widget.requiredFields.any(
                      (k) => (values[k] ?? "").trim().isEmpty,
                    )) {
                      failure(context);
                      return;
                    }
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await widget.onSave?.call(values);
                    } catch (_) {
                      if (mounted) {
                        setState(() {
                          saving = false;
                          error = context.tr('saveError');
                        });
                      }
                      return;
                    }
                    if (!mounted) return;
                    setState(() {
                      saving = false;
                      leaving = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) Navigator.pop(context, values);
                    });
                  },
            child: Text(context.tr('save')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (saving) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          for (final e in controllers.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: widget.weekdayFields.contains(e.key)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.labels[e.key]!),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: List.generate(7, (i) {
                            final days = e.value.text
                                .split(',')
                                .map(int.tryParse)
                                .whereType<int>()
                                .toSet();
                            return FilterChip(
                              label: Text(
                                MaterialLocalizations.of(context)
                                    .narrowWeekdays[(i + 1) % 7],
                              ),
                              selected: days.contains(i + 1),
                              onSelected: saving
                                  ? null
                                  : (selected) {
                                      if (selected) {
                                        days.add(i + 1);
                                      } else if (days.length > 1) {
                                        days.remove(i + 1);
                                      }
                                      setState(
                                        () => e.value.text =
                                            (days.toList()..sort()).join(','),
                                      );
                                    },
                            );
                          }),
                        ),
                      ],
                    )
                  : TextField(
                      controller: e.value,
                      keyboardType: widget.numberFields.contains(e.key)
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : null,
                      readOnly: widget.dateFields.contains(e.key),
                      onTap: !widget.dateFields.contains(e.key)
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate:
                                    DateTime.tryParse(e.value.text) ??
                                    DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2200),
                              );
                              if (date != null && mounted) {
                                setState(
                                  () => e.value.text = date
                                      .toIso8601String()
                                      .substring(0, 10),
                                );
                              }
                            },
                      enabled: !saving,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      onChanged: (_) => setState(() {}),
                      minLines: widget.multiline.contains(e.key) ? 6 : 1,
                      maxLines: widget.multiline.contains(e.key) ? null : 1,
                      maxLength: widget.multiline.contains(e.key)
                          ? 100000
                          : 200,
                      decoration: InputDecoration(
                        labelText: widget.labels[e.key],
                        border: const OutlineInputBorder(),
                      ),
                    ),
            ),
        ],
      ),
    ),
  );
}
