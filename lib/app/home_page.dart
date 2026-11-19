import '../features/reminders/notification_center.dart';
import '../features/voice/voice_page.dart';
import '../features/guidance/help_hub.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../features/search/library_page.dart';
import '../features/planning/today_page.dart';

import 'package:flutter/services.dart';

import '../core/settings.dart';
import '../core/strings.dart';
import '../core/start_strings.dart';
import '../core/loop_carousel.dart';
import '../features/ambience/ambient_scene.dart';
import '../features/notes/notes_page.dart';
import '../features/todo/todo_page.dart';
import '../features/settings/profile_page.dart';
import '../features/habits/habits_page.dart';
import '../features/agent/agent_hub.dart';
import '../features/private_space/space_page.dart';
import '../features/finance/finance_page.dart';
import '../features/attachments/share_page.dart';
import '../features/attachments/attachment_store.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const bridge = MethodChannel('bilga/assistant');
  bool agentOpen = false, shareOpen = false;
  Future<void> consumeShare() async {
    if (!mounted || shareOpen) return;
    try {
      final payload = Map<String, dynamic>.from(
        await Attachments.bridge.invokeMethod<Map>('consume') ?? {},
      );
      if (!mounted ||
          ((payload['text'] ?? '') == '' &&
              (payload['files'] as List? ?? []).isEmpty)) {
        return;
      }
      shareOpen = true;
      await open(SharePage(payload));
      shareOpen = false;
      if (mounted) await consumeShare();
    } on MissingPluginException {
      // Share intents are available only on the Android host.
    } catch (_) {
      shareOpen = false;
    }
  }

  Timer? paletteSave;
  @override
  void initState() {
    super.initState();
    Attachments.bridge.setMethodCallHandler((call) async {
      if (call.method == 'incoming') await consumeShare();
    });
    bridge.setMethodCallHandler((call) async {
      if (call.method == 'openAgent') await openAgent();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await consumeShare();
      try {
        if (await bridge.invokeMethod<bool>('consumeAgentLaunch') == true) {
          await openAgent();
        }
      } on MissingPluginException {
        /* Desktop and widget tests. */
      }
    });
  }

  @override
  void dispose() {
    paletteSave?.cancel();
    Attachments.bridge.setMethodCallHandler(null);
    bridge.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> openAgent() async {
    if (!mounted || agentOpen) return;
    agentOpen = true;
    await open(const AgentHub());
    agentOpen = false;
  }

  Future<void> open(Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) setState(() {});
  }

  void selectPalette(String key) {
    final settings = AppSettings.instance;
    if (settings.palette == key) return;
    setState(() => settings.palette = key);
    paletteSave?.cancel();
    paletteSave = Timer(const Duration(milliseconds: 300), () async {
      try {
        await settings.save();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(context.tr('saveError'))));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final scheme = Theme.of(context).colorScheme;
    final palette = palettes.containsKey(settings.palette)
        ? settings.palette
        : 'forest';
    final keys = palettes.keys.toList();
    final entries = <(String, String, IconData, Widget)>[
      (
        context.tr('notes'),
        startText('Fikrlarni saqlang', 'Capture your ideas', 'Сохраняйте идеи'),
        Icons.edit_note_rounded,
        const NotesPage(),
      ),
      (
        context.tr('todos'),
        startText(
          'Rejadan natijaga',
          'Turn plans into progress',
          'От плана к результату',
        ),
        Icons.task_alt_rounded,
        const TodoPage(),
      ),
      (
        context.tr('xHabits'),
        startText('Har kuni bir qadam', 'One step every day', 'Шаг за шагом'),
        Icons.local_fire_department_outlined,
        const HabitsPage(),
      ),
      (
        context.tr('textAssistant'),
        context.tr('searchAssistantShort'),
        Icons.auto_awesome_rounded,
        const AgentHub(),
      ),
      (
        context.tr('xFinance'),
        context.tr('xReport'),
        Icons.account_balance_wallet_outlined,
        const FinancePage(),
      ),
      (
        context.tr('xExperience'),
        context.tr('xFeelings'),
        Icons.auto_stories_outlined,
        const SpacePage(kind: 'experience'),
      ),
      (
        context.tr('xBooks'),
        context.tr('xChapters'),
        Icons.menu_book,
        const SpacePage(kind: 'book'),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, width) {
            final logo = ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/brand/bilga.png',
                width: 40,
                height: 40,
                semanticLabel: 'Bilga',
              ),
            );
            if (width.maxWidth < 64) {
              return Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  width: width.maxWidth.clamp(0.0, 36.0),
                  height: 36,
                  child: logo,
                ),
              );
            }
            return Row(
              children: [
                logo,
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'Bilga',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            key: const Key('home-voice-open'),
            tooltip: context.tr('voiceTitle'),
            onPressed: () => open(const VoicePage()),
            icon: const Icon(Icons.mic_none),
          ),
          IconButton(
            key: const Key('home-notification-center'),
            tooltip: context.tr('ncTitle'),
            onPressed: () => open(const NotificationCenter()),
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            key: const Key('home-help-hub'),
            tooltip: context.tr('helpHub'),
            onPressed: () => open(const HelpHubPage()),
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: context.tr('search'),
            onPressed: () => open(const LibraryPage()),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: context.tr('profile'),
            onPressed: () => open(const ProfilePage()),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.today_outlined),
                      title: Text(context.tr('todayPlan')),
                      subtitle: Text(context.tr('weekAhead')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(const TodayPage()),
                    ),
                  ),
                ),
                if (settings.nickname.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '${settings.avatar} ${settings.nickname}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Text(
                    startText(
                      'Fikr. Reja. Harakat.',
                      'Ideas. Plans. Progress.',
                      'Идеи. Планы. Действия.',
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                LoopCarousel(
                  count: entries.length,
                  height:
                      220 +
                      ((MediaQuery.textScalerOf(context).scale(16) / 16 - 1) *
                              120)
                          .clamp(0, 300)
                          .toDouble(),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Card(
                      color: index == 3
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHigh,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => index == 3 ? openAgent() : open(entry.$4),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    entry.$3,
                                    size: 36,
                                    color: scheme.primary,
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.north_east_rounded),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                entry.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                entry.$2,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Text(
                    context.tr('yourSpace'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AmbientScene(palette: palette),
                ),
                const SizedBox(height: 12),
                LoopCarousel(
                  count: keys.length,
                  initialIndex: keys.indexOf(palette),
                  height: 126,
                  onSelected: (index) => selectPalette(keys[index]),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/ambience/${keys[index]}.jpg',
                          fit: BoxFit.cover,
                        ),
                        const ColoredBox(color: Color(0x55000000)),
                        Center(
                          child: Text(
                            context.tr(keys[index]),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
