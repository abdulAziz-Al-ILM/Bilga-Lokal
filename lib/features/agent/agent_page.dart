import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/settings.dart';
import '../../core/start_strings.dart';
import '../../core/strings.dart';
import '../notes/note_model.dart';
import '../notes/note_service.dart';
import '../todo/todo_model.dart';
import '../todo/todo_service.dart';
import '../collections/collection_repository.dart';
import '../habits/habit_store.dart';
import '../ambience/ambient_audio.dart';
import 'agent_access.dart';
import 'agent_command.dart';

class AgentPage extends StatefulWidget {
  const AgentPage({super.key});
  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> with WidgetsBindingObserver {
  static const voice = MethodChannel('bilga/voice');
  final input = TextEditingController();
  final tts = FlutterTts();
  final access = AgentAccess.instance;
  final notes = NoteService();
  final tasks = TodoService();
  final habits = HabitStore();
  final messages = <String>[];
  String language = 'en-US';
  bool listening = false, busy = false, readAloud = false;
  int _speechEpoch = 0;
  bool _foreground = true;
  String get hint => startText(
    'yozuv yarat: G‘oyalar | Yangi loyiha',
    'create note: Ideas | My next project',
    'создай заметку: Идеи | Мой проект',
  );
  @override
  void initState() {
    super.initState();
    language = switch (AppSettings.instance.language) {
      'uz' => 'uz-UZ',
      'ru' => 'ru-RU',
      _ => 'en-US',
    };
    WidgetsBinding.instance.addObserver(this);
    unawaited(access.init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(voice.invokeMethod<void>('cancel').catchError((Object _) {}));
    _speechEpoch++;
    unawaited(tts.stop());
    unawaited(AmbientAudio.instance?.duck(false));
    input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(voice.invokeMethod<void>('cancel').catchError((Object _) {}));
      _speechEpoch++;
    unawaited(tts.stop());
      unawaited(AmbientAudio.instance?.duck(false));
    }
  }

  void say(String text) {
    if (!mounted) return;
    setState(() {
      messages.add(text);
      if (messages.length > 30) messages.removeAt(0);
    });
    if (readAloud && _foreground) unawaited(speak(text));
  }

  Future<void> speak(String text) async {
    try {
      await tts.stop();
      final available = await tts.isLanguageAvailable(language);
      if (available != true && available != 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                startText(
                  'Bu tilning ovozi telefonda o‘rnatilmagan.',
                  'This voice is not installed on your phone.',
                  'Этот голос не установлен на телефоне.',
                ),
              ),
            ),
          );
        }
        return;
      }
      final voices = (await tts.getVoices as List)
          .whereType<Map>()
          .where(
            (v) =>
                '${v['locale']}'
                    .replaceAll('_', '-')
                    .startsWith(language.split('-').first) &&
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
      final epoch = ++_speechEpoch;
      // Chunking avoids TTS engines truncating long private notes.
      final chunks = RegExp(r'[\s\S]{1,2800}').allMatches(text);
      for (final match in chunks) {
        if (epoch != _speechEpoch || !_foreground || !mounted) break;
        await tts.speak(match.group(0)!);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Voice unavailable')));
      }
    } finally {
      await AmbientAudio.instance?.duck(false);
    }
  }

  Future<void> listen() async {
    if (!access.allowed || busy) return;
    if (listening) {
      await voice.invokeMethod<void>('cancel');
      return;
    }
    setState(() => listening = true);
    try {
      _speechEpoch++;
      await tts.stop();
      await AmbientAudio.instance?.duck(true);
      final text = await voice.invokeMethod<String>('listen', {
        'language': language,
        'online': false,
      });
      if (mounted && text != null && text.trim().isNotEmpty) {
        input.text = text;
        say(
          startText(
            'Buyruq tayyor. Tekshirib, bajarish tugmasini bosing.',
            'Command ready. Review it and tap Run.',
            'Команда готова. Проверьте и нажмите Выполнить.',
          ),
        );
      }
    } on PlatformException catch (e) {
      say(switch (e.code) {
        'permission' => startText(
          'Mikrofon ruxsati kerak. Sozlamalardan yoqing.',
          'Microphone permission is required. Enable it in Settings.',
          'Разрешите доступ к микрофону в настройках.',
        ),
        'offline_unavailable' => startText(
          'Lokal ovoz tanish mavjud emas. Matn yozing yoki onlayn ovozni yoqing.',
          'On-device speech is unavailable. Type or enable online speech.',
          'Локальное распознавание недоступно. Введите текст или включите онлайн-режим.',
        ),
        'cancelled' => startText(
          'Tinglash to‘xtatildi.',
          'Listening stopped.',
          'Прослушивание остановлено.',
        ),
        _ => startText(
          'Ovoz tanilmadi. Til modelini tekshiring yoki matn yozing.',
          'Speech was not recognized. Check the language model or type instead.',
          'Речь не распознана. Проверьте языковую модель или введите текст.',
        ),
      });
    } catch (_) {
      say(
        startText(
          'Ovoz xizmati mavjud emas.',
          'Voice service unavailable.',
          'Голосовой сервис недоступен.',
        ),
      );
    } finally {
      await AmbientAudio.instance?.duck(false);
      if (mounted) setState(() => listening = false);
    }
  }

  Future<bool> confirm(String title, String body) async {
    if (!mounted || !_foreground) return false;
    return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(title),
                content: SingleChildScrollView(child: Text(body)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(startText('Bekor qilish', 'Cancel', 'Отмена')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      startText('Tasdiqlash', 'Confirm', 'Подтвердить'),
                    ),
                  ),
                ],
              ),
            ) ==
            true &&
        mounted &&
        _foreground &&
        access.allowed;
  }

  Future<T?> pick<T>(
    String title,
    List<T> values,
    String Function(T) label,
  ) async {
    if (values.isEmpty) {
      say(
        startText(
          'Hech narsa topilmadi.',
          'No matches found.',
          'Ничего не найдено.',
        ),
      );
      return null;
    }
    if (!mounted) return null;
    return showDialog<T>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final item in values.take(40))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Text(label(item)),
            ),
        ],
      ),
    );
  }

  Future<String?> editText(
    String title,
    String initial, {
    bool multiline = false,
  }) async {
    var edited = initial;
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: edited,
          onChanged: (value) => edited = value,
          autofocus: true,
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 8 : 2,
          maxLength: multiline ? 10000 : 200,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(startText('Bekor qilish', 'Cancel', 'Отмена')),
          ),
          FilledButton(
            onPressed: () {
              if (edited.trim().isNotEmpty) {
                Navigator.pop(context, edited.trim());
              }
            },
            child: Text(startText('Saqlash', 'Save', 'Сохранить')),
          ),
        ],
      ),
    );
  }

  Future<void> launch(Uri uri) async {
    if (!mounted || !_foreground || !access.allowed) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('no_handler');
    }
  }

  Future<void> execute([String? supplied]) async {
    if (busy || listening || !access.allowed || !_foreground) return;
    final raw = supplied ?? input.text;
    if (raw.trim().isEmpty) return;
    setState(() => busy = true);
    input.clear();
    final command = parseAgentCommand(raw);
    final query = command.argument.toLowerCase();
    try {
      switch (command.action) {
        case AgentAction.note:
          final split = command.argument.split('|');
          final title = split.first.trim().isEmpty
              ? await editText(
                  startText('Yozuv nomi', 'Note title', 'Название заметки'),
                  '',
                )
              : split.first.trim();
          if (title == null) break;
          final body = split.length > 1
              ? split.skip(1).join('|').trim()
              : title;
          if (await confirm(
            startText('Yozuv yaratish', 'Create note', 'Создать заметку'),
            '$title\n\n$body',
          )) {
            final now = DateTime.now();
            await notes.addNote(
              Note(
                id: newLocalId(),
                title: title,
                body: body,
                createdAt: now,
                updatedAt: now,
              ),
            );
            say(
              startText(
                'Yozuv saqlandi: $title',
                'Note saved: $title',
                'Заметка сохранена: $title',
              ),
            );
          }
        case AgentAction.task:
          final title = command.argument.isEmpty
              ? await editText(startText('Vazifa', 'Task', 'Задача'), '')
              : command.argument;
          if (title == null) break;
          if (await confirm(
            startText('Vazifa yaratish', 'Create task', 'Создать задачу'),
            title,
          )) {
            final now = DateTime.now();
            await tasks.addTodo(
              Todo(
                id: newLocalId(),
                title: title,
                isDone: false,
                createdAt: now,
                updatedAt: now,
              ),
            );
            say(
              startText(
                'Vazifa qo‘shildi: $title',
                'Task added: $title',
                'Задача добавлена: $title',
              ),
            );
          }
        case AgentAction.findNotes:
        case AgentAction.editNote:
          final found = (await notes.getAllActiveNotes())
              .where(
                (n) => '${n.title} ${n.body}'.toLowerCase().contains(query),
              )
              .toList();
          final note = await pick(
            startText('Yozuvni tanlang', 'Choose a note', 'Выберите заметку'),
            found,
            (n) => n.title,
          );
          if (note == null) break;
          if (command.action == AgentAction.findNotes) {
            say('${note.title}\n\n${note.body}');
          } else {
            final body = await editText(note.title, note.body, multiline: true);
            if (body != null && mounted && _foreground && access.allowed) {
              await notes.updateNote(
                note.copyWith(body: body, updatedAt: DateTime.now()),
              );
              say(
                startText(
                  'Yozuv yangilandi. Oldingi nusxa tarixda.',
                  'Note updated. The previous version is in history.',
                  'Заметка обновлена. Предыдущая версия в истории.',
                ),
              );
            }
          }
        case AgentAction.tasks:
          final list = (await tasks.getTodos())
              .where((t) => !t.isDone && t.title.toLowerCase().contains(query))
              .take(30)
              .toList();
          say(
            list.isEmpty
                ? startText(
                    'Ochiq vazifalar yo‘q.',
                    'No open tasks.',
                    'Нет незавершённых задач.',
                  )
                : list.map((t) => '• ${t.title}').join('\n'),
          );
        case AgentAction.completeTask:
        case AgentAction.editTask:
          final list = (await tasks.getTodos())
              .where(
                (t) =>
                    t.title.toLowerCase().contains(query) &&
                    (command.action == AgentAction.editTask || !t.isDone),
              )
              .toList();
          final task = await pick(
            startText('Vazifani tanlang', 'Choose a task', 'Выберите задачу'),
            list,
            (t) => t.title,
          );
          if (task == null) break;
          if (command.action == AgentAction.completeTask) {
            if (await confirm(
              startText(
                'Bajarildi deb belgilash',
                'Mark as completed',
                'Отметить выполненной',
              ),
              task.title,
            )) {
              await CollectionRepository(CollectionKind.todos)
                  .setField(task.id, 'is_done', 1);
              say(
                startText(
                  'Vazifa bajarildi.',
                  'Task completed.',
                  'Задача выполнена.',
                ),
              );
            }
          } else {
            final title = await editText(
              startText('Vazifa', 'Task', 'Задача'),
              task.title,
            );
            if (title != null && mounted && _foreground && access.allowed) {
              await tasks.updateTodo(
                task.copyWith(title: title, updatedAt: DateTime.now()),
              );
              say(
                startText(
                  'Vazifa yangilandi.',
                  'Task updated.',
                  'Задача обновлена.',
                ),
              );
            }
          }
        case AgentAction.habit:
          final title = command.argument.isEmpty
              ? await editText(startText('Odat', 'Habit', 'Привычка'), '')
              : command.argument;
          if (title != null &&
              await confirm(
                startText('Odat yaratish', 'Create habit', 'Создать привычку'),
                title,
              )) {
            await habits.create(title);
            say(
              startText(
                'Odat qo‘shildi.',
                'Habit added.',
                'Привычка добавлена.',
              ),
            );
          }
        case AgentAction.habits:
          final list = await habits.all();
          say(
            list.isEmpty
                ? startText(
                    'Odatlar hali yo‘q.',
                    'No habits yet.',
                    'Привычек пока нет.',
                  )
                : list
                      .map(
                        (h) =>
                            '${h.days.contains(dayKey(DateTime.now())) ? '✓' : '○'} ${h.title} • ${habitStreak(h.days, DateTime.now())} 🔥',
                      )
                      .join('\n'),
          );
        case AgentAction.checkHabit:
          final list = (await habits.all())
              .where((h) => h.title.toLowerCase().contains(query))
              .toList();
          final habit = await pick(
            startText('Odatni tanlang', 'Choose a habit', 'Выберите привычку'),
            list,
            (h) => h.title,
          );
          if (habit != null &&
              await confirm(
                startText(
                  'Bugun bajarildi',
                  'Completed today',
                  'Выполнено сегодня',
                ),
                habit.title,
              )) {
            await habits.mark(habit.id, DateTime.now(), true);
            say(startText('Belgilandi.', 'Checked in.', 'Отмечено.'));
          }
        case AgentAction.web:
        case AgentAction.unknown:
          final question = command.argument.isEmpty
              ? await editText(
                  startText(
                    'Nimani qidiramiz?',
                    'What shall we search?',
                    'Что искать?',
                  ),
                  '',
                )
              : command.argument;
          if (question != null &&
              await confirm(
                startText(
                  'Internetda qidirish',
                  'Search the web',
                  'Поиск в интернете',
                ),
                startText(
                  'Bu so‘rov brauzerdagi qidiruv xizmatiga yuboriladi:\n$question',
                  'This query will be sent to the search engine in your browser:\n$question',
                  'Этот запрос будет отправлен поисковику в браузере:\n$question',
                ),
              )) {
            await launch(
              Uri.https('www.google.com', '/search', {'q': question}),
            );
            say(
              startText(
                'Qidiruv brauzerda ochildi.',
                'Search opened in your browser.',
                'Поиск открыт в браузере.',
              ),
            );
          }
        case AgentAction.call:
        case AgentAction.sms:
          final parts = command.argument.split('|');
          final phone = safePhone(parts.first);
          if (phone == null) {
            say(
              startText(
                'Telefon raqamini yozing: +998901234567. SMS: raqam | matn',
                'Enter a phone number: +998901234567. SMS: number | message',
                'Введите номер: +998901234567. SMS: номер | текст',
              ),
            );
            break;
          }
          final sms = command.action == AgentAction.sms;
          final body = parts.skip(1).join('|').trim();
          if (sms && body.isEmpty) {
            say(
              startText(
                'SMS matnini | dan keyin yozing.',
                'Write the SMS after |.',
                'Напишите текст SMS после |.',
              ),
            );
            break;
          }
          if (await confirm(
            sms ? 'SMS' : startText('Qo‘ng‘iroq', 'Call', 'Звонок'),
            '$phone${sms ? '\n$body' : ''}',
          )) {
            await launch(
              sms
                  ? Uri(
                      scheme: 'sms',
                      path: phone,
                      query: 'body=${Uri.encodeComponent(body)}',
                    )
                  : Uri(scheme: 'tel', path: phone),
            );
            say(
              startText(
                'Telefon oynasida yakunlang.',
                'Finish in the phone app.',
                'Завершите действие в приложении телефона.',
              ),
            );
          }
        case AgentAction.music:
          final key = palettes.containsKey(query)
              ? query
              : AppSettings.instance.palette;
          final audio = await AmbientAudio.open();
          await audio.select(
            key,
            Strings.get(AppSettings.instance.language, key),
          );
          unawaited(
            audio.play().catchError((Object _) {
              say('Audio unavailable');
            }),
          );
          say(
            startText('Musiqa yoqildi.', 'Music started.', 'Музыка включена.'),
          );
        case AgentAction.stopMusic:
          await AmbientAudio.instance?.pause();
          say(
            startText(
              'Musiqa to‘xtatildi.',
              'Music paused.',
              'Музыка приостановлена.',
            ),
          );
      }
    } catch (_) {
      say(
        startText(
          'Amal bajarilmadi. Ma’lumotni tekshirib qayta urining.',
          'Action failed. Check the details and try again.',
          'Не удалось выполнить действие. Проверьте данные и повторите.',
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: access,
    builder: (context, _) {
      final examples = <(IconData, String, String)>[
        (
          Icons.edit_note,
          startText('Yozuv', 'Note', 'Заметка'),
          startText('yozuv yarat: ', 'create note: ', 'создай заметку: '),
        ),
        (
          Icons.add_task,
          startText('Vazifa', 'Task', 'Задача'),
          startText('vazifa yarat: ', 'create task: ', 'создай задачу: '),
        ),
        (
          Icons.search,
          startText('Yozuvni topish', 'Find notes', 'Найти заметку'),
          startText('yozuvni top: ', 'find note: ', 'найди заметку: '),
        ),
        (
          Icons.checklist,
          startText('Vazifalarni o‘qish', 'Read tasks', 'Прочитать задачи'),
          startText("vazifalarni o'qi", 'read tasks', 'прочитай задачи'),
        ),
        (
          Icons.done_all,
          startText('Vazifani tugatish', 'Complete task', 'Завершить задачу'),
          startText('vazifani tugat: ', 'complete task: ', 'заверши задачу: '),
        ),
        (
          Icons.edit,
          startText('Yozuvni tahrirlash', 'Edit note', 'Изменить заметку'),
          startText('yozuvni tahrirla: ', 'edit note: ', 'измени заметку: '),
        ),
        (
          Icons.edit_calendar,
          startText('Vazifani tahrirlash', 'Edit task', 'Изменить задачу'),
          startText('vazifani tahrirla: ', 'edit task: ', 'измени задачу: '),
        ),
        (
          Icons.local_fire_department,
          startText('Yangi odat', 'New habit', 'Новая привычка'),
          startText('odat yarat: ', 'create habit: ', 'создай привычку: '),
        ),
        (
          Icons.today,
          startText('Odatni belgilash', 'Check in', 'Отметить привычку'),
          startText(
            'odatni bajarildi: ',
            'complete habit: ',
            'отметь привычку: ',
          ),
        ),
        (
          Icons.insights,
          startText('Odatlarim', 'My habits', 'Мои привычки'),
          startText('odatlarim', 'my habits', 'мои привычки'),
        ),
        (
          Icons.public,
          startText('Internet qidiruvi', 'Web search', 'Поиск в интернете'),
          startText(
            'internetdan qidir: ',
            'search web: ',
            'найди в интернете: ',
          ),
        ),
        (
          Icons.call,
          startText('Qo‘ng‘iroq', 'Call', 'Звонок'),
          startText("qo'ng'iroq qil: ", 'call: ', 'позвони: '),
        ),
        (Icons.sms, 'SMS', 'sms: '),
        (
          Icons.music_note,
          startText('Musiqa', 'Music', 'Музыка'),
          startText('musiqani yoq', 'play music', 'включи музыку'),
        ),
        (
          Icons.pause,
          startText('Musiqani to‘xtatish', 'Pause music', 'Остановить музыку'),
          startText("musiqani to'xtat", 'stop music', 'выключи музыку'),
        ),
      ];
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bilga Core'),
          actions: [
            IconButton(
              tooltip: startText(
                'O‘qishni to‘xtatish',
                'Stop reading',
                'Остановить чтение',
              ),
              onPressed: () async {
                _speechEpoch++;
                await tts.stop();
                await AmbientAudio.instance?.duck(false);
              },
              icon: const Icon(Icons.volume_off),
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    startText(
                      'Buyruq bering. Ishni yengillashtiring.',
                      'Say it. Get things done.',
                      'Скажите — и действуйте.',
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    startText(
                      'Lokal buyruqlar yordamchisi: yozuv, vazifa, odat va musiqa. Internet qidiruvi brauzerda ochiladi.',
                      'Local command assistant for notes, tasks, habits and music. Web searches open in your browser.',
                      'Локальный помощник для заметок, задач, привычек и музыки. Интернет-поиск открывается в браузере.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!access.allowed)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start • ${access.product?.price ?? context.tr('xUnavailable')}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              startText(
                                'Bir martalik xarid. Quyidagi agent amallarini ochadi. Notes, to-do va odatlar bepul qoladi.',
                                'One-time purchase unlocks the agent tools below. Notes, tasks and habits remain free.',
                                'Разовая покупка открывает функции помощника ниже. Заметки, задачи и привычки остаются бесплатными.',
                              ),
                            ),
                            if (access.product == null ||
                                AgentAccess.licenseKey.isEmpty)
                              Text(
                                startText(
                                  'Xarid hozir mavjud emas.',
                                  'Purchase currently unavailable.',
                                  'Покупка пока недоступна.',
                                ),
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed:
                                      access.pending ||
                                          access.product == null ||
                                          AgentAccess.licenseKey.isEmpty
                                      ? null
                                      : access.buy,
                                  child: Text(
                                    access.pending
                                        ? startText(
                                            'Kutilmoqda…',
                                            'Pending…',
                                            'Ожидание…',
                                          )
                                        : startText(
                                            'Start paketini olish',
                                            'Get Start',
                                            'Купить Start',
                                          ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: access.loading
                                      ? null
                                      : access.restore,
                                  child: Text(
                                    startText(
                                      'Xaridni tiklash',
                                      'Restore purchases',
                                      'Восстановить покупку',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (AgentAccess.preview)
                    const Text('Developer preview • No payment'),
                  if (access.error != null)
                    Text(
                      access.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (access.loading) const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in examples)
                        ActionChip(
                          avatar: Icon(e.$1, size: 18),
                          label: Text(e.$2),
                          onPressed: access.allowed && !busy && !listening
                              ? () => setState(() => input.text = e.$3)
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: language,
                    decoration: InputDecoration(
                      labelText: startText(
                        'Ovoz tili',
                        'Voice language',
                        'Язык голоса',
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'uz-UZ',
                        child: Text('O‘zbekcha'),
                      ),
                      DropdownMenuItem(value: 'en-US', child: Text('English')),
                      DropdownMenuItem(value: 'ru-RU', child: Text('Русский')),
                    ],
                    onChanged: listening || busy
                        ? null
                        : (value) => setState(() => language = value!),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      startText(
                        'Javobni ovozda o‘qish',
                        'Read responses aloud',
                        'Читать ответы вслух',
                      ),
                    ),
                    value: readAloud,
                    onChanged: (value) => setState(() => readAloud = value),
                  ),
                  TextField(
                    controller: input,
                    enabled: access.allowed && !busy && !listening,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 10000,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: access.allowed && !busy && !listening
                            ? () => execute()
                            : null,
                        icon: const Icon(Icons.arrow_upward),
                        label: Text(startText('Bajarish', 'Run', 'Выполнить')),
                      ),
                      OutlinedButton.icon(
                        onPressed: access.allowed && !busy ? listen : null,
                        icon: Icon(listening ? Icons.stop : Icons.mic),
                        label: Text(
                          listening
                              ? startText('To‘xtatish', 'Stop', 'Стоп')
                              : startText('Gapirish', 'Speak', 'Говорить'),
                        ),
                      ),
                    ],
                  ),
                  if (busy || listening)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(),
                    ),
                  const SizedBox(height: 18),
                  for (final message in messages.reversed)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(message),
                            IconButton(
                              tooltip: startText(
                                'O‘qib berish',
                                'Read aloud',
                                'Прочитать',
                              ),
                              onPressed: access.allowed
                                  ? () => speak(message)
                                  : null,
                              icon: const Icon(Icons.volume_up_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    startText(
                      'Vidjet: telefon bosh ekranini bosib turing → Vidjetlar → Bilga Core. Vidjet agentni ochadi; gapirish uchun mikrofonni bosing.',
                      'Widget: long-press your home screen → Widgets → Bilga Core. Tap the widget to open the agent, then tap the microphone.',
                      'Виджет: удерживайте главный экран → Виджеты → Bilga Core. Откройте помощника виджетом и нажмите микрофон.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
