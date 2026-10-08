import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import '../notes/note_model.dart';
import '../notes/note_service.dart';
import '../todo/todo_model.dart';
import '../todo/todo_service.dart';
import '../private_space/record_store.dart';
import '../ambience/ambient_audio.dart';
import 'agent_access.dart';
import 'purchase_panel.dart';
import 'turbo_engine.dart';

class TurboPage extends StatefulWidget {
  const TurboPage({super.key});
  @override
  State<TurboPage> createState() => _TurboState();
}

class _TurboState extends State<TurboPage> with WidgetsBindingObserver {
  final engine = TurboEngine(),
      input = TextEditingController(),
      tts = FlutterTts();
  final history = <(String, String)>[];
  String partial = '', source = '';
  bool foreground = true, listening = false;
  static const voice = MethodChannel('bilga/voice');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(engine.inspect().catchError((Object _) {}));
  }

  Future<void> pause() async {
    await tts.stop();
    await voice.invokeMethod<void>('cancel').catchError((Object _) {});
    await engine.stop();
    await AmbientAudio.instance?.duck(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused) unawaited(pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(pause());
    unawaited(engine.unload());
    history.clear();
    source = '';
    input.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {
      if (mounted) failure(context);
    }
    if (mounted) setState(() {});
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty ||
        text.length > 1500 ||
        engine.working ||
        !AgentAccess.instance.has(AgentAccess.turbo)) {
      return;
    }
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      input.clear();
      history.add(('user', text));
      partial = '';
    });
    await run(() async {
      final answer = await engine.generate(
        history,
        source: source,
        language: lang,
        onText: (s) {
          if (mounted) setState(() => partial = s);
        },
      );
      if (mounted) {
        setState(() {
          if (answer.isNotEmpty) history.add(('assistant', answer));
          partial = '';
          while (history.length > 30) {
            history.removeAt(0);
          }
        });
      }
    });
  }

  Future<void> listen() async {
    final lang = Localizations.localeOf(context).toLanguageTag();
    setState(() => listening = true);
    await run(() async {
      await AmbientAudio.instance?.duck(true);
      try {
        final text = await voice.invokeMethod<String>('listen', {
          'language': lang,
          'online': false,
        });
        if (mounted && foreground && text != null) input.text = text;
      } finally {
        await AmbientAudio.instance?.duck(false);
      }
    });
    if (mounted) setState(() => listening = false);
  }

  Future<void> speak(String text) async {
    final lang = Localizations.localeOf(context).languageCode;
    await run(() async {
      final voices = (await tts.getVoices as List)
          .whereType<Map>()
          .where(
            (v) =>
                '${v['locale']}'.startsWith(lang) &&
                v['network_required'] == false,
          )
          .toList();
      if (voices.isEmpty) throw StateError('offline_voice');
      await tts.setVoice({
        'name': '${voices.first['name']}',
        'locale': '${voices.first['locale']}',
      });
      await tts.awaitSpeakCompletion(true);
      await AmbientAudio.instance?.duck(true);
      try {
        await tts.speak(text);
      } finally {
        await AmbientAudio.instance?.duck(false);
      }
    });
  }

  Future<void> save(String body, bool todo) async {
    final v = await editFields(
      context,
      context.tr(todo ? 'todos' : 'notes'),
      {'title': context.tr('title'), 'body': context.tr('notes')},
      initial: {
        'title': body.substring(0, body.length.clamp(0, 80)),
        'body': body,
      },
      multiline: {'body'},
    );
    if (v == null) return;
    final now = DateTime.now();
    if (todo) {
      await TodoService().addTodo(
        Todo(
          id: localId(),
          title: '${v['title']}\n${v['body']}',
          isDone: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await NoteService().addNote(
        Note(
          id: localId(),
          title: v['title']!,
          body: v['body']!,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('saved'))));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([engine, AgentAccess.instance]),
    builder: (c, _) => Scaffold(
      appBar: AppBar(
        title: Text(c.tr('xTurbo')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: engine.working
                ? null
                : () => run(() async {
                    if (await consent(c, c.tr('deleteForever')) && mounted) {
                      setState(() {
                        history.clear();
                        partial = '';
                        source = '';
                      });
                    }
                  }),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(c.tr('xModelInfo')),
          Text(engine.requirements),
          DropdownButton<LocalModel>(
            value: engine.model,
            items: [
              for (final m in models)
                DropdownMenuItem(
                  value: m,
                  child: Text(
                    'Qwen3 ${m.name} · ${(m.bytes / 1073741824).toStringAsFixed(2)} GiB',
                  ),
                ),
            ],
            onChanged: engine.working || engine.loaded
                ? null
                : (m) => run(() async {
                    engine.model = m!;
                    await engine.inspect();
                  }),
          ),
          if (!engine.compatible && !engine.loaded) Text(c.tr('xUnsupported')),
          if (engine.working)
            LinearProgressIndicator(
              value: engine.progress > 0 && engine.progress < 1
                  ? engine.progress
                  : null,
            ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: engine.working ? null : () => run(engine.download),
                child: Text(c.tr('xDownload')),
              ),
              OutlinedButton(
                onPressed: engine.working ? null : () => run(engine.test),
                child: Text(c.tr('xTest')),
              ),
              IconButton(
                onPressed: engine.working
                    ? () => run(engine.stop)
                    : () => run(() async {
                        if (await consent(c, c.tr('xDeleteModel'))) {
                          await engine.delete();
                        }
                      }),
                icon: Icon(engine.working ? Icons.stop : Icons.delete_forever),
              ),
            ],
          ),
          if (engine.tested) Text(c.tr('xReady')),
          if (!AgentAccess.instance.has(AgentAccess.turbo))
            PurchasePanel(
              product: AgentAccess.turbo,
              canBuy: engine.tested && engine.compatible,
            ),
          Text(c.tr('xChatInfo')),
          for (final m in history)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(m.$2),
                    if (m.$1 == 'assistant')
                      Wrap(
                        children: [
                          IconButton(
                            tooltip: c.tr('xSpeak'),
                            onPressed: () => speak(m.$2),
                            icon: const Icon(Icons.volume_up),
                          ),
                          TextButton(
                            onPressed: () => run(() => save(m.$2, false)),
                            child: Text(c.tr('notes')),
                          ),
                          TextButton(
                            onPressed: () => run(() => save(m.$2, true)),
                            child: Text(c.tr('todos')),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (partial.isNotEmpty) SelectableText(partial),
          if (source.isNotEmpty)
            InputChip(
              label: Text(c.tr('xSource')),
              onDeleted: () => setState(() => source = ''),
            ),
          TextField(
            controller: input,
            maxLength: 1500,
            minLines: 1,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: c.tr('xQuestion'),
              border: const OutlineInputBorder(),
            ),
          ),
          Wrap(
            children: [
              IconButton(
                tooltip: c.tr('xSource'),
                icon: const Icon(Icons.note_add_outlined),
                onPressed: engine.working
                    ? null
                    : () => run(() async {
                        final notes = await NoteService().getAllActiveNotes();
                        if (!mounted) return;
                        final picked = await showDialog<Note>(
                          context: this.context,
                          builder: (d) => SimpleDialog(
                            title: Text(d.tr('xSource')),
                            children: [
                              for (final n in notes)
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(d, n),
                                  child: Text(n.title),
                                ),
                            ],
                          ),
                        );
                        if (picked != null && mounted) {
                          setState(
                            () => source = '${picked.title}\n${picked.body}',
                          );
                        }
                      }),
              ),
              IconButton(
                tooltip: c.tr('xVoice'),
                onPressed: engine.working || listening ? null : listen,
                icon: const Icon(Icons.mic),
              ),
              FilledButton(
                onPressed:
                    engine.working ||
                        !AgentAccess.instance.has(AgentAccess.turbo)
                    ? null
                    : send,
                child: Text(c.tr('xSend')),
              ),
              TextButton(
                onPressed: () => run(() async {
                  final query = input.text.trim();
                  if (query.isNotEmpty && await consent(c, c.tr('xExternal'))) {
                    await launchUrl(
                      Uri.https('www.google.com', '/search', {'q': query}),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                }),
                child: Text(c.tr('xWeb')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
