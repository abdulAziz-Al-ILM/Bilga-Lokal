import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'purchase_panel.dart';
import 'agent_command.dart';
import 'voice/model_store.dart';
import 'voice/offline_voice.dart';
import 'voice/reading_controller.dart';
import 'voice/voice_languages.dart';
import 'voice/model_panel.dart';

class AgentPage extends StatefulWidget {
  const AgentPage({super.key});
  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> with WidgetsBindingObserver {
  final input = TextEditingController();
  OfflineVoice? _voice;
  ReadingController? _reading;
  bool _installingModels = false;
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
    language = voiceLanguages[AppSettings.instance.language]?.locale ?? 'en-US';
    unawaited(_initializeVoice());
    WidgetsBinding.instance.addObserver(this);
    unawaited(access.init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_voice?.cancelListening().catchError((Object _) {}));
    _reading?.removeListener(_readingChanged);
    _reading?.dispose();
    _voice?.store.cancel();
    _speechEpoch++;
    unawaited(AmbientAudio.instance?.duck(false));
    input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_voice?.cancelListening().catchError((Object _) {}));
      unawaited(_reading?.pause());
      unawaited(AmbientAudio.instance?.duck(false));
    }
  }

  void say(String text, {bool aloud = true}) {
    if (!mounted) return;
    setState(() {
      messages.add(text);
      if (messages.length > 30) messages.removeAt(0);
    });
    if (aloud && readAloud && _foreground) unawaited(speak(text));
  }

  Future<void> _initializeVoice() async {
    try {
      final store = await VoiceModelStore.open();
      if (!mounted) {
        store.dispose();
        return;
      }
      final service = OfflineVoice(store);
      setState(() {
        _voice = service;
        _reading = ReadingController(service)..addListener(_readingChanged);
      });
    } catch (_) {
      say(
        startText(
          'Offline ovozni tayyorlab bo‘lmadi.',
          'Could not initialize offline speech.',
          'Не удалось подготовить офлайн-речь.',
        ),
        aloud: false,
      );
    }
  }

  void _readingChanged() {
    if (mounted) setState(() {});
  }

  Future<void> pauseReading() async {
    await _reading?.pause();
    await AmbientAudio.instance?.duck(false);
  }

  Future<void> resumeReading() async {
    if (!_foreground || !access.allowed || listening) return;
    if (_reading?.active == true) await AmbientAudio.instance?.duck(true);
    await _reading?.resume();
  }

  Future<void> speak(String text) async {
    final reader = _reading;
    if (reader == null || !_foreground || !access.allowed) return;
    final epoch = ++_speechEpoch;
    await AmbientAudio.instance?.duck(true);
    await reader.read(text, language);
    if (epoch != _speechEpoch) return;
    await AmbientAudio.instance?.duck(false);
    if (reader.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            startText(
              '${reader.error}: offline TTS ovozi mavjud emas yoki ishlamadi. Modelni tekshiring. Matn saqlangan.',
              '${reader.error}: offline TTS is unavailable or failed. Check the model. Your text is preserved.',
              '${reader.error}: офлайн-голос недоступен или не работает. Проверьте модель. Текст сохранён.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> chooseVoiceLanguage(String value) async {
    await pauseReading();
    if (!mounted) return;
    setState(() => language = value);
    final service = _voice;
    if (service == null || !service.store.source.configured) return;
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          startText(
            'Offline modellarni olish',
            'Get offline models',
            'Загрузить офлайн-модели',
          ),
        ),
        content: Text(
          startText(
            'Tanlangan til uchun yetishmayotgan modellar ishonchli katalogdan avtomatik yuklansinmi? Internet faqat model olishga ishlatiladi. Yozuv va ovoz yuborilmaydi.',
            'Automatically download missing models for this language from the trusted catalog? Internet is used only to acquire models. Notes and audio are never sent.',
            'Автоматически загрузить недостающие модели языка из доверенного каталога? Интернет нужен только для моделей. Заметки и голос не отправляются.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(startText('Bekor qilish', 'Cancel', 'Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(startText('Yuklash', 'Download', 'Загрузить')),
          ),
        ],
      ),
    );
    if (consent != true || !mounted || !_foreground) return;
    setState(() => _installingModels = true);
    try {
      final missing = await service.downloadMissingModels(value);
      for (final kind in missing) {
        say(
          '${kind.toUpperCase()}: ${startText("bu til uchun mos offline model mavjud emas", "no compatible offline model for this language", "нет совместимой офлайн-модели языка")}',
          aloud: false,
        );
      }
    } on DownloadCancelled {
      say(
        startText(
          'Yuklash bekor qilindi. Keyin davom ettirish mumkin.',
          'Download cancelled. You can resume later.',
          'Загрузка отменена. Можно продолжить позже.',
        ),
        aloud: false,
      );
    } catch (_) {
      say(
        startText(
          'Model yuklash yoki tekshirish bajarilmadi. Qayta urinib ko‘ring.',
          'Model download or verification failed. Try again.',
          'Ошибка загрузки или проверки модели.',
        ),
        aloud: false,
      );
    } finally {
      service.invalidateCapabilities();
      if (mounted) setState(() => _installingModels = false);
    }
  }

  Future<void> listen() async {
    final service = _voice;
    if (!access.allowed || busy || service == null) return;
    if (listening) {
      await service.cancelListening();
      return;
    }
    setState(() => listening = true);
    try {
      await pauseReading();
      await AmbientAudio.instance?.duck(true);
      final text = await service.listen(language);
      if (mounted && _foreground && text != null && text.trim().isNotEmpty) {
        final command = parseAgentCommand(text, preferredLanguage: language);
        if (command.action == AgentAction.pauseReading) {
          await pauseReading();
        } else if (command.action == AgentAction.resumeReading) {
          // Recognition has ended; resume before leaving this method.
          setState(() => listening = false);
          await resumeReading();
        } else {
          input.text = text;
          say(
            startText(
              'Buyruq tayyor. Tekshirib, bajarish tugmasini bosing.',
              'Command ready. Review it and tap Run.',
              'Команда готова. Проверьте и нажмите Выполнить.',
            ),
            aloud: false,
          );
        }
      }
    } on PlatformException catch (e) {
      say(
        e.code == 'permission'
            ? startText(
                'Mikrofon ruxsati kerak. Sozlamalardan yoqing.',
                'Microphone permission is required. Enable it in Settings.',
                'Разрешите доступ к микрофону в настройках.',
              )
            : startText(
                'Bu tilning offline STT modeli mavjud emas yoki ovoz tanilmadi. Modelni tekshiring yoki matn va tugmalardan foydalaning.',
                'Offline STT is unavailable for this language or speech was not recognized. Check the model or use text and buttons.',
                'Офлайн-STT языка недоступно или речь не распознана. Проверьте модель или используйте текст и кнопки.',
              ),
        aloud: false,
      );
    } catch (_) {
      say(
        startText(
          'Offline ovoz xizmati ishlamadi.',
          'Offline voice service failed.',
          'Ошибка офлайн-речи.',
        ),
        aloud: false,
      );
    } finally {
      await AmbientAudio.instance?.duck(
        _reading?.active == true && _reading?.paused == false,
      );
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
    final command = parseAgentCommand(raw, preferredLanguage: language);
    final query = command.argument.toLowerCase();
    try {
      switch (command.action) {
        case AgentAction.pauseReading:
          await pauseReading();
        case AgentAction.resumeReading:
          await resumeReading();
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
            final text = '${note.title}\n\n${note.body}';
            say(text, aloud: false);
            unawaited(speak(text));
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
          say(
            startText(
              'Buyruq tanilmadi. Bilga Core faqat lokal buyruqlarni bajaradi.',
              'Command not recognized. Bilga Core handles local commands only.',
              'Команда не распознана. Bilga Core выполняет только локальные команды.',
            ),
            aloud: false,
          );
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
              onPressed: pauseReading,
              icon: const Icon(Icons.volume_off),
            ),
            IconButton(
              tooltip: startText(
                'Davom et',
                'Resume reading',
                'Продолжить чтение',
              ),
              onPressed: _reading?.paused == true && !listening
                  ? resumeReading
                  : null,
              icon: const Icon(Icons.play_arrow),
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
                      'Offline yordamchi: yozuv, vazifa, odat va musiqa. O‘qish vaqtida mikrofonni bosing, so‘ng “to‘xta” yoki “davom et” deng.',
                      'Offline assistant for notes, tasks, habits and music. While reading, tap the microphone, then say “stop” or “resume”.',
                      'Офлайн-помощник для заметок, задач, привычек и музыки. При чтении нажмите микрофон и скажите «стоп» или «продолжай».',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!access.allowed)
                    const PurchasePanel(product: AgentAccess.core),
                  if (access.error != null)
                    Text(
                      purchaseError(access.error!),
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
                    items: [
                      for (final entry in languages.entries)
                        DropdownMenuItem(
                          value: voiceLanguages[entry.key]!.locale,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: listening || busy || _installingModels
                        ? null
                        : (value) {
                            if (value != null) {
                              unawaited(chooseVoiceLanguage(value));
                            }
                          },
                  ),
                  if (_voice != null)
                    VoiceModelPanel(
                      key: ValueKey('models-$language-$_installingModels'),
                      voice: _voice!,
                      language: language,
                      onChanged: () {
                        if (mounted) setState(() {});
                      },
                    ),
                  if (_reading?.active == true)
                    Text(
                      '${_reading!.paused ? startText("To‘xtatilgan", "Paused", "Приостановлено") : startText("O‘qilmoqda", "Reading", "Чтение")} · ${_reading!.index + 1}/${_reading!.chunks.length}',
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
