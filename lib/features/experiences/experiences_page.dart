import '../organization/folders_page.dart';
import '../organization/organization_store.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import '../../core/widgets/activity_calendar.dart';
import '../agent/agent_access.dart';
import '../agent/purchase_panel.dart';
import '../guidance/guide_controller.dart';
import '../guidance/guide_host.dart';
import '../private_space/record_store.dart';
import 'experience_model.dart';
import 'experience_store.dart';
import 'experience_templates.dart';
import 'experience_editor.dart';
import 'experience_page.dart';

class ExperiencesPage extends StatefulWidget {
  final RecordStore? records;
  final ExperienceStore? store;
  final AgentAccess? access;
  final bool tutorial;
  const ExperiencesPage({
    super.key,
    this.records,
    this.store,
    this.access,
    this.tutorial = false,
  });
  @override
  State<ExperiencesPage> createState() => _ExperiencesState();
}

class _ExperiencesState extends State<ExperiencesPage> {
  late final store = widget.store ?? ExperienceStore(records: widget.records);
  AgentAccess get access => widget.access ?? AgentAccess.instance;
  final search = TextEditingController();
  final anchors = {
    for (final k in ['create', 'title', 'body', 'save', 'results'])
      k: GlobalKey(),
  };
  late final guide = GuideController(
    id: 'experience.create',
    steps: const [
      GuideStep('create', 'create', 'egCreate', event: 'createOpened'),
      // The first editor step is a route boundary; Android Back handles draft cancellation.
      GuideStep(
        'title',
        'title',
        'egTitle',
        event: 'titleEntered',
        backBoundary: true,
      ),
      GuideStep('body', 'body', 'egBody', event: 'reflected'),
      GuideStep('save', 'save', 'egSave', event: 'saved'),
      GuideStep('results', 'results', 'egResults', backBoundary: true),
    ],
  );
  List<Map<String, Object?>> rows = [];
  Map<String, String> categories = {};
  Map<String, int> summary = {}, activity = {};
  List<String> tags = [];
  String category = '', tag = '', status = '';
  bool favorite = false,
      calendar = false,
      busy = false,
      more = false,
      failed = false;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String? selected;
  Timer? debounce;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
    if (widget.tutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) guide.start();
      });
    }
  }

  @override
  void dispose() {
    search.dispose();
    debounce?.cancel();
    guide.dispose();
    super.dispose();
  }

  Future<void> load({bool append = false}) async {
    final request = ++generation;
    setState(() => busy = true);
    try {
      final data = await store.page(
        query: search.text,
        category: category,
        tag: tag,
        status: status,
        favorites: favorite,
        from: selected,
        until: selected == null
            ? null
            : ExperienceModel.day(
                DateTime(
                  DateTime.parse(selected!).year,
                  DateTime.parse(selected!).month,
                  DateTime.parse(selected!).day + 1,
                ),
              ),
        offset: append ? rows.length : 0,
      );
      final cats = await store.categories(),
          total = await store.summary(),
          days = await store.month(month),
          allTags = await store.tags();
      if (mounted && request == generation) {
        setState(() {
          rows = append ? [...rows, ...data] : data;
          categories = cats;
          summary = total;
          activity = days;
          tags = allTags;
          more = data.length == 50;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted && request == generation) setState(() => failed = true);
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  Future<bool> allowed() async {
    if (access.has(AgentAccess.core)) return true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PurchasePanel(product: AgentAccess.core, access: access),
    );
    return access.has(AgentAccess.core);
  }

  Future<void> create([ExperienceTemplate? template]) async {
    if (!await allowed() || !mounted) return;
    guide.event('createOpened');
    final record = await Navigator.push<PrivateRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => ExperienceEditor(
          initial: {
            'category': template?.id == 'gratitude' ? 'gratitude' : 'life',
            'mode': template?.experiment == true ? 'experiment' : 'reflection',
            if (template != null) 'template': template.id,
          },
          categories: categories,
          guide: guide.active ? guide : null,
          anchors: anchors,
          onSave: (data) async {
            if (!access.has(AgentAccess.core)) {
              throw StateError('access_expired');
            }
            return store.records.save('experience', data);
          },
        ),
      ),
    );
    if (!mounted) return;
    if (record != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExperiencePage(
            record: record,
            store: store,
            access: access,
            guide: guide.active ? guide : null,
            anchors: anchors,
          ),
        ),
      );
    }
    if (guide.active) guide.exit();
    if (mounted) await load();
  }

  Future<void> templates() async {
    final chosen = await showModalBottomSheet<ExperienceTemplate>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * .8,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const Key('experience-template-close'),
                  tooltip: c.tr('close'),
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.close),
                ),
              ),
              Text(
                c.tr('eTemplates'),
                style: Theme.of(c).textTheme.headlineSmall,
              ),
              Text(c.tr('eTemplateSafe')),
              for (final t in experienceTemplates)
                ListTile(
                  title: Text(c.tr('eTemplate_${t.id}')),
                  subtitle: Text(
                    c.tr(t.experiment ? 'eExperiment' : 'eReflection'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final ok = await consent(
                      c,
                      '${c.tr('eTemplate_${t.id}')}\n\n${c.tr('eTemplateHint_${t.id}')}\n\n${t.fields.map((f) => '${c.tr('eField_$f')}: ${c.tr('ePrompt_$f')}').join('\n\n')}\n\n${c.tr('eTemplateSafe')}',
                    );
                    if (ok && c.mounted) Navigator.pop(c, t);
                  },
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) await create(chosen);
  }

  Future<void> help() async {
    if (await consent(
          context,
          '${context.tr('ePurpose')}\n\n${context.tr('eHelp')}',
        ) &&
        mounted) {
      guide.start();
    }
  }

  Future<void> addCategory() async {
    if (!await allowed() || !mounted) return;
    await editFields(
      context,
      context.tr('eAddCategory'),
      {'name': context.tr('title')},
      requiredFields: {'name'},
      onSave: (v) async {
        if (!access.has(AgentAccess.core)) throw StateError('access_expired');
        await store.addCategory(v['name']!);
      },
    );
    if (mounted) await load();
  }

  Future<void> filters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, change) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.tr('eFilters'), style: Theme.of(c).textTheme.titleLarge),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: c.tr('eCategory')),
                  items: [
                    DropdownMenuItem(value: '', child: Text(c.tr('all'))),
                    for (final k in {
                      ...ExperienceModel.categories,
                      ...categories.keys,
                    })
                      DropdownMenuItem(
                        value: k,
                        child: Text(categories[k] ?? c.tr('x$k')),
                      ),
                  ],
                  onChanged: (v) => change(() => category = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: c.tr('eStatus')),
                  items: [
                    DropdownMenuItem(value: '', child: Text(c.tr('all'))),
                    for (final k in ExperienceModel.states)
                      DropdownMenuItem(
                        value: k,
                        child: Text(c.tr('eStatus_$k')),
                      ),
                  ],
                  onChanged: (v) => change(() => status = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: tag,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: c.tr('eTags')),
                  items: [
                    DropdownMenuItem(value: '', child: Text(c.tr('all'))),
                    for (final t in tags)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => change(() => tag = v!),
                ),
                SwitchListTile(
                  title: Text(c.tr('favorites')),
                  value: favorite,
                  onChanged: (v) => change(() => favorite = v),
                ),
                TextButton(
                  onPressed: () {
                    change(() {
                      category = tag = status = '';
                      favorite = false;
                      selected = null;
                    });
                  },
                  child: Text(c.tr('eReset')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text(c.tr('continue')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> folders() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => FoldersPage(
          store: OrganizationStore(
            'experience',
            provided: store.records.database,
          ),
          allowed: () => access.has(AgentAccess.core),
          open: (item) async {
            try {
              final record = await store.records.get(item.id);
              if (!mounted) return;
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ExperiencePage(
                    record: record,
                    store: store,
                    access: access,
                  ),
                ),
              );
            } catch (_) {
              if (mounted) failure(context);
            }
          },
        ),
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext c) => GuideHost(
    controller: guide,
    targets: anchors,
    child: Scaffold(
      appBar: AppBar(
        title: Text(c.tr('xExperience')),
        actions: [
          IconButton(
            tooltip: c.tr('orgFolders'),
            onPressed: folders,
            icon: const Icon(Icons.folder_outlined),
          ),
          IconButton(
            key: const Key('experience-help'),
            tooltip: c.tr('gHelp'),
            onPressed: help,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: c.tr('eFilters'),
            onPressed: filters,
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.tr('ePurpose'),
                      style: Theme.of(c).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          key: anchors['create'],
                          child: FilledButton.icon(
                            key: const Key('experience-create'),
                            onPressed: busy ? null : create,
                            icon: const Icon(Icons.add),
                            label: Text(c.tr('eNew')),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const Key('experience-templates'),
                          onPressed: templates,
                          icon: const Icon(Icons.auto_awesome_mosaic_outlined),
                          label: Text(c.tr('eTemplates')),
                        ),
                        OutlinedButton.icon(
                          key: const Key('experience-calendar'),
                          onPressed: () => setState(() => calendar = !calendar),
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            c.tr(calendar ? 'eTimeline' : 'eCalendar'),
                          ),
                        ),
                        TextButton(
                          onPressed: addCategory,
                          child: Text(c.tr('eAddCategory')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (summary.isNotEmpty)
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          for (final k in [
                            'total',
                            'completed',
                            'reflections',
                            'experiments',
                            'days',
                          ])
                            Chip(
                              label: Text(
                                '${c.tr('eSummary_$k')}: ${summary[k] ?? 0}',
                              ),
                            ),
                        ],
                      ),
                    Text(c.tr('eSummaryHint')),
                    if (calendar)
                      ActivityCalendar(
                        month: month,
                        values: activity,
                        selected: selected,
                        onMonth: (v) {
                          month = v;
                          load();
                        },
                        onDay: (v) {
                          selected = ExperienceModel.day(v);
                          load();
                        },
                      ),
                    if (selected != null)
                      TextButton.icon(
                        onPressed: () {
                          selected = null;
                          load();
                        },
                        icon: const Icon(Icons.clear),
                        label: Text(selected!),
                      ),
                    TextField(
                      key: const Key('experience-search'),
                      controller: search,
                      decoration: InputDecoration(
                        labelText: c.tr('search'),
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (_) {
                        generation++;
                        debounce?.cancel();
                        debounce = Timer(
                          const Duration(milliseconds: 250),
                          load,
                        );
                      },
                    ),
                    if (busy) const LinearProgressIndicator(),
                    if (failed)
                      TextButton(onPressed: load, child: Text(c.tr('retry'))),
                    if (!busy && !failed && rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(c.tr('eEmpty')),
                      ),
                  ],
                ),
              ),
            ),
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (c, i) {
                final row = rows[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Card(
                    child: ListTile(
                      isThreeLine: true,
                      leading: Icon(
                        row['favorite'] == 1
                            ? Icons.star
                            : Icons.history_edu_outlined,
                      ),
                      title: Text(row['title'] as String),
                      subtitle: Text(
                        '${row['date']} · ${categories[row['category']] ?? (ExperienceModel.categories.contains(row['category']) ? c.tr('x${row['category']}') : c.tr('eCategoryUnavailable'))}\n${row['excerpt']}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        try {
                          final record = await store.records.get(
                            row['id'] as String,
                          );
                          if (!c.mounted) return;
                          await Navigator.push(
                            c,
                            MaterialPageRoute(
                              builder: (_) => ExperiencePage(
                                record: record,
                                store: store,
                                access: access,
                              ),
                            ),
                          );
                          if (mounted) await load();
                        } catch (_) {
                          if (c.mounted) failure(c);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: more
                    ? TextButton(
                        onPressed: busy ? null : () => load(append: true),
                        child: Text(c.tr('continue')),
                      )
                    : const SizedBox(height: 40),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
