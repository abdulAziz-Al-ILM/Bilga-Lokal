import 'voice/voice_languages.dart';

enum AgentAction {
  pauseReading,
  resumeReading,
  note,
  task,
  findNotes,
  tasks,
  completeTask,
  editNote,
  editTask,
  habit,
  habits,
  checkHabit,
  web,
  call,
  sms,
  music,
  stopMusic,
  unknown,
}

class AgentCommand {
  final AgentAction action;
  final String argument;
  const AgentCommand(this.action, [this.argument = '']);
}

/// Offline command grammar. Deliberately never treats retrieved note text as an
/// instruction and never guesses which record to overwrite.
AgentCommand parseAgentCommand(
  String input, {
  String preferredLanguage = 'en',
}) {
  final reading = parseReadingCommand(
    input,
    preferredLanguage: preferredLanguage,
  );
  if (reading != null && reading.intent != ReadingIntent.read) {
    return AgentCommand(switch (reading.intent) {
      ReadingIntent.pause => AgentAction.pauseReading,
      ReadingIntent.resume => AgentAction.resumeReading,
      ReadingIntent.read => AgentAction.findNotes,
    }, reading.argument);
  }
  final text = input.trim().replaceAll(RegExp('[‘’ʻʼ`´]'), "'");
  final rules = <AgentAction, List<String>>{
    AgentAction.stopMusic: [
      'stop music',
      'pause music',
      "musiqani to'xtat",
      'musiqani o‘chir',
      'выключи музыку',
    ],
    AgentAction.music: [
      'play music',
      'start music',
      'musiqani yoq',
      'включи музыку',
    ],
    AgentAction.completeTask: [
      'complete task',
      'finish task',
      'vazifani bajarildi',
      'vazifani tugat',
      'заверши задачу',
    ],
    AgentAction.editNote: [
      'edit note',
      'update note',
      'yozuvni tahrirla',
      'измени заметку',
    ],
    AgentAction.editTask: [
      'edit task',
      'update task',
      'vazifani tahrirla',
      'измени задачу',
    ],
    AgentAction.findNotes: [
      'find notes',
      'find note',
      'read note',
      'read notes',
      'yozuvni top',
      "yozuvni o'qi",
      "yozuvlarni o'qi",
      'найди заметку',
      'прочитай заметку',
      'заметки',
    ],
    AgentAction.tasks: [
      'read tasks',
      'list tasks',
      'my tasks',
      "vazifalarni o'qi",
      'vazifalarim',
      'прочитай задачи',
      'мои задачи',
    ],
    AgentAction.checkHabit: [
      'complete habit',
      'check habit',
      'odatni bajarildi',
      'отметь привычку',
    ],
    AgentAction.habits: [
      'my habits',
      'list habits',
      'odatlarim',
      'мои привычки',
    ],
    AgentAction.habit: [
      'create habit',
      'add habit',
      'new habit',
      'odat yarat',
      'odat qo\'sh',
      'создай привычку',
      'добавь привычку',
    ],
    AgentAction.note: [
      'create note',
      'add note',
      'new note',
      'take a note',
      'note',
      'yozuv yarat',
      "yozuv qo'sh",
      'eslatma yoz',
      'создай заметку',
      'запиши заметку',
    ],
    AgentAction.task: [
      'create task',
      'add task',
      'new task',
      'task',
      'vazifa yarat',
      "vazifa qo'sh",
      'создай задачу',
      'добавь задачу',
    ],
    AgentAction.web: [
      'search web',
      'search for',
      'search',
      'internetdan qidir',
      'qidir',
      'найди в интернете',
      'поиск',
    ],
    AgentAction.call: [
      'call',
      'dial',
      "qo'ng'iroq qil",
      'telefon qil',
      'позвони',
    ],
    AgentAction.sms: ['send sms', 'sms yubor', 'sms', 'отправь смс'],
  };
  final lower = text.toLowerCase();
  for (final entry in rules.entries) {
    for (final raw in entry.value) {
      final prefix = raw.replaceAll(RegExp('[‘’ʻʼ]'), "'");
      if (lower == prefix ||
          lower.startsWith('$prefix ') ||
          lower.startsWith('$prefix:')) {
        return AgentCommand(
          entry.key,
          text
              .substring(prefix.length)
              .replaceFirst(RegExp(r'^\s*:\s*'), '')
              .trim(),
        );
      }
    }
  }
  // Uzbek naturally puts the action after its object.
  for (final entry in <String, AgentAction>{
    ' deb yozuv yarat': AgentAction.note,
    ' deb vazifa yarat': AgentAction.task,
    ' deb odat yarat': AgentAction.habit,
    ' haqida internetdan qidir': AgentAction.web,
  }.entries) {
    if (lower.endsWith(entry.key)) {
      return AgentCommand(
        entry.value,
        text.substring(0, text.length - entry.key.length).trim(),
      );
    }
  }
  if (reading != null) {
    return AgentCommand(AgentAction.findNotes, reading.argument);
  }
  return AgentCommand(AgentAction.unknown, text);
}

String? safePhone(String input) {
  final value = input.trim().replaceAll(RegExp(r'[\s()\-]'), '');
  // Reject USSD/service codes, URI injection and accidental prose.
  return RegExp(r'^\+?[0-9]{3,15}$').hasMatch(value) ? value : null;
}
