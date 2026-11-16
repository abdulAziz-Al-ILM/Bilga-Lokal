import 'package:flutter/material.dart';

import '../../core/editor_form.dart';
import '../../core/strings.dart';
import '../guidance/guide_controller.dart';
import '../guidance/guide_host.dart';
import '../private_space/record_store.dart';
import 'experience_model.dart';

class ExperienceEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final Map<String, String> categories;
  final Future<PrivateRecord> Function(Map<String, dynamic>) onSave;
  final bool editing;
  final GuideController? guide;
  final Map<String, GlobalKey> anchors;
  const ExperienceEditor({
    super.key,
    required this.initial,
    required this.categories,
    required this.onSave,
    this.editing = false,
    this.guide,
    this.anchors = const {},
  });
  @override
  State<ExperienceEditor> createState() => _ExperienceEditorState();
}

class _ExperienceEditorState extends State<ExperienceEditor> {
  final form = GlobalKey<FormState>();
  late final controls = {
    for (final k in ['title', 'tags', ...ExperienceModel.fields])
      k: TextEditingController(
        text: k == 'tags'
            ? (widget.initial[k] as List? ?? []).join(', ')
            : widget.initial[k] as String? ?? '',
      ),
  };
  late String category = widget.initial['category'] ?? 'life',
      status = widget.initial['status'] ?? 'active',
      mode = widget.initial['mode'] ?? 'reflection',
      date = widget.initial['date'] ?? ExperienceModel.day(DateTime.now());
  bool busy = false, leaving = false;
  Map<String, dynamic> value() => {
    ...widget.initial,
    'experienceVersion': 1,
    for (final e in controls.entries)
      if (e.key != 'tags') e.key: e.value.text.trim(),
    'tags': controls['tags']!.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList(),
    'category': category,
    'status': status,
    'mode': mode,
    'date': date,
    'favorite': widget.initial['favorite'] ?? false,
  };
  bool get dirty =>
      controls.entries.any(
        (e) =>
            e.value.text !=
            (e.key == 'tags'
                ? (widget.initial[e.key] as List? ?? []).join(', ')
                : widget.initial[e.key] as String? ?? ''),
      ) ||
      category != (widget.initial['category'] ?? 'life') ||
      status != (widget.initial['status'] ?? 'active') ||
      mode != (widget.initial['mode'] ?? 'reflection') ||
      date != (widget.initial['date'] ?? ExperienceModel.day(DateTime.now()));
  @override
  void dispose() {
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final data = value();
      ExperienceModel.validate(data);
      final record = await widget.onSave(data);
      widget.guide?.event('saved');
      if (mounted) {
        setState(() => leaving = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, record);
      }
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final body = PopScope(
      canPop: !busy && (leaving || !dirty),
      onPopInvokedWithResult: (did, _) async {
        if (!did &&
            !busy &&
            await consent(c, c.tr('discardChanges')) &&
            mounted) {
          setState(() => leaving = true);
          await WidgetsBinding.instance.endOfFrame;
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(c.tr(widget.editing ? 'edit' : 'eNew')),
          actions: [
            Container(
              key: widget.anchors['save'],
              child: TextButton(
                key: const Key('experience-save'),
                onPressed: busy ? null : save,
                child: Text(c.tr('save')),
              ),
            ),
          ],
        ),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (widget.initial['template'] is String)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    c.tr('eTemplateHint_${widget.initial['template']}'),
                  ),
                ),
              Container(
                key: widget.anchors['title'],
                child: TextFormField(
                  key: const Key('experience-title'),
                  controller: controls['title'],
                  onChanged: (v) => widget.guide?.satisfy(
                    'titleEntered',
                    valid: v.trim().isNotEmpty,
                  ),
                  maxLength: 200,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  decoration: InputDecoration(labelText: c.tr('title')),
                  validator: (s) =>
                      s == null || s.trim().isEmpty ? c.tr('required') : null,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final k in ['reflection', 'experiment'])
                    ChoiceChip(
                      label: Text(
                        c.tr(k == 'reflection' ? 'eReflection' : 'eExperiment'),
                      ),
                      selected: mode == k,
                      onSelected: busy ? null : (_) => setState(() => mode = k),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('experience-date'),
                onPressed: busy
                    ? null
                    : () async {
                        final now = DateTime.parse(date),
                            picked = await showDatePicker(
                              context: c,
                              initialDate: now,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2200),
                            );
                        if (picked != null && mounted) {
                          setState(() => date = ExperienceModel.day(picked));
                        }
                      },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  MaterialLocalizations.of(c)
                      .formatFullDate(DateTime.parse(date)),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: category,
                isExpanded: true,
                decoration: InputDecoration(labelText: c.tr('eCategory')),
                items: [
                  for (final k in {
                    ...ExperienceModel.categories,
                    ...widget.categories.keys,
                    category,
                  })
                    DropdownMenuItem(
                      value: k,
                      child: Text(
                        widget.categories[k] ??
                            (ExperienceModel.categories.contains(k)
                                ? c.tr('x$k')
                                : c.tr('eCategoryUnavailable')),
                      ),
                    ),
                ],
                onChanged: busy ? null : (v) => setState(() => category = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: status,
                isExpanded: true,
                decoration: InputDecoration(labelText: c.tr('eStatus')),
                items: [
                  for (final k in ExperienceModel.states)
                    DropdownMenuItem(value: k, child: Text(c.tr('eStatus_$k'))),
                ],
                onChanged: busy ? null : (v) => setState(() => status = v!),
              ),
              TextFormField(
                key: const Key('experience-tags'),
                controller: controls['tags'],
                maxLength: 2400,
                decoration: InputDecoration(
                  labelText: c.tr('eTags'),
                  helperText: c.tr('eTagsHint'),
                ),
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
              ),
              for (final key in ExperienceModel.fields)
                if (mode == 'experiment' ||
                    ![
                      'hypothesis',
                      'method',
                      'observations',
                      'evidence',
                      'result',
                      'conclusions',
                    ].contains(key) ||
                    controls[key]!.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      key: key == 'body' ? widget.anchors['body'] : null,
                      child: TextFormField(
                        key: Key('experience-$key'),
                        controller: controls[key],
                        minLines: 3,
                        maxLines: 8,
                        maxLength: 100000,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableIMEPersonalizedLearning: false,
                        decoration: InputDecoration(
                          labelText: c.tr('eField_$key'),
                          hintText: c.tr('ePrompt_$key'),
                        ),
                        onChanged: key == 'body'
                            ? (v) => widget.guide?.satisfy(
                                'reflected',
                                valid: v.trim().isNotEmpty,
                              )
                            : null,
                      ),
                    ),
                  ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
    return widget.guide == null
        ? body
        : GuideHost(
            controller: widget.guide!,
            targets: widget.anchors,
            child: body,
          );
  }
}
