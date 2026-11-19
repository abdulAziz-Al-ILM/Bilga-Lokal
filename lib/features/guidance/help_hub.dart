import '../voice/voice_page.dart';
import '../voice/voice_screen_host.dart';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../collections/collection_page.dart';
import '../collections/collection_repository.dart';
import '../habits/habits_page.dart';
import '../finance/finance_page.dart';
import '../experiences/experiences_page.dart';
import '../books/book_library_page.dart';
import 'module_help.dart';

/// Offline help routes to the existing module controls; it has no write API.
class HelpHubPage extends StatefulWidget {
  final Widget Function(String module, bool tutorial)? openModule;
  const HelpHubPage({super.key, this.openModule});
  @override
  State<HelpHubPage> createState() => _HelpHubState();
}

class _HelpHubState extends State<HelpHubPage> {
  final search = TextEditingController();
  String query = '';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Widget module(String id, bool tutorial) =>
      widget.openModule?.call(id, tutorial) ??
      switch (id) {
        'notes' => CollectionPage(
          kind: CollectionKind.notes,
          tutorial: tutorial,
        ),
        'tasks' => CollectionPage(
          kind: CollectionKind.todos,
          tutorial: tutorial,
        ),
        'habits' => HabitsPage(tutorial: tutorial),
        'finance' => FinancePage(tutorial: tutorial),
        'experiences' => ExperiencesPage(tutorial: tutorial),
        'books' => BookLibraryPage(tutorial: tutorial),
        _ => throw ArgumentError.value(id),
      };
  Future<void> open(ModuleHelp info, bool tutorial) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => module(info.id, tutorial)),
    );
    if (mounted) setState(() {});
  }

  Future<void> article(ModuleHelp info) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (c) => Scaffold(
          appBar: AppBar(title: Text(c.tr(info.title))),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.tr(info.purpose),
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  c.tr('tpl_templates'),
                  style: Theme.of(c).textTheme.titleMedium,
                ),
                Text(c.tr(info.examples)),
                const SizedBox(height: 16),
                Text(
                  c.tr('helpStart'),
                  style: Theme.of(c).textTheme.titleMedium,
                ),
                Text(c.tr(info.start)),
                const SizedBox(height: 16),
                Text(
                  c.tr('helpResults'),
                  style: Theme.of(c).textTheme.titleMedium,
                ),
                Text(c.tr(info.results)),
                const SizedBox(height: 16),
                Text(c.tr('helpPrivacy')),
                FilledButton(
                  key: Key('help-open-${info.id}'),
                  onPressed: () => Navigator.push<void>(
                    c,
                    MaterialPageRoute(builder: (_) => module(info.id, false)),
                  ),
                  child: Text(c.tr('helpOpenModule')),
                ),
                OutlinedButton(
                  key: Key('help-guide-${info.id}'),
                  onPressed: () => Navigator.push<void>(
                    c,
                    MaterialPageRoute(builder: (_) => module(info.id, true)),
                  ),
                  child: Text(c.tr('gShowMe')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty);
    final matches = moduleHelp.where((m) {
      final text = [
        m.id,
        c.tr(m.title),
        c.tr(m.purpose),
        c.tr(m.examples),
        c.tr(m.start),
        c.tr(m.results),
      ].join(' ').toLowerCase();
      return terms.every(text.contains);
    }).toList();
    final voiceText = [
      c.tr('voiceTitle'),
      c.tr('voicePurpose'),
      c.tr('voiceExamplesText'),
    ].join(' ').toLowerCase();
    final voiceMatch = terms.every(voiceText.contains);
    return Scaffold(
      appBar: AppBar(title: Text(c.tr('helpHub'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('help-search'),
              controller: search,
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                labelText: c.tr('helpSearch'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: c.tr('helpClearSearch'),
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          search.clear();
                          setState(() => query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: matches.isEmpty && !voiceMatch
                ? Center(child: Text(c.tr('helpNoResults')))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      Text(c.tr('helpIntro')),
                      if (voiceMatch)
                        Card(
                          child: ListTile(
                            key: const Key('help-voice-open'),
                            leading: const Icon(Icons.mic_none),
                            title: Text(c.tr('voiceTitle')),
                            subtitle: Text(c.tr('voiceShortcut')),
                            onTap: () => Navigator.push<void>(
                              c,
                              MaterialPageRoute(
                                settings: const RouteSettings(
                                  name: VoiceScreenNavigator.assistantRoute,
                                ),
                                builder: (_) => const VoicePage(),
                              ),
                            ),
                          ),
                        ),
                      for (final info in matches)
                        Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListTile(
                                key: Key('help-article-${info.id}'),
                                leading: Icon(info.icon),
                                title: Text(c.tr(info.title)),
                                subtitle: Text(c.tr(info.purpose)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => article(info),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    TextButton(
                                      key: Key('help-start-${info.id}'),
                                      onPressed: () => open(info, false),
                                      child: Text(c.tr('helpOpenModule')),
                                    ),
                                    TextButton(
                                      key: Key('help-tutorial-${info.id}'),
                                      onPressed: () => open(info, true),
                                      child: Text(c.tr('gShowMe')),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
