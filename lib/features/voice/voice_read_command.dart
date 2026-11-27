import 'voice_screen_command.dart';

enum VoiceReadCommand {
  read,
  pause,
  resume,
  stop;

  static VoiceReadCommand? parse(String utterance) {
    final words = VoiceScreenCommand.words(utterance)
        .replaceAll("'", '')
        .replaceAll(RegExp(r'\b(iltimos|please|пожалуйста)\b'), '')
        .trim();
    if (RegExp(
      r'^(?:(?:(?:shu |bu |joriy )?(?:ekran|bolim|matn|yozuv|qayd|kitob|bob|sahifa|hujjat)(?:ni|dagi matn(?:lar)?ni)? |hammasini )?o[qk]i(?:b ber(?:ing|a olasanmi)?|ng)?|read(?: aloud)?(?: (?:this|the|current|this screen|the current))?(?: (?:screen|section|text|note|page|chapter|book|document|out loud))*(?: aloud)?|(?:прочитай|прочтите|прочитать|озвучь)(?: (?:этот|эту|текущий|текущую|весь|вслух))?(?: (?:экран|раздел|текст|заметку|страницу|главу|книгу|документ))?(?: вслух)?)$',
    ).hasMatch(words)) {
      return read;
    }
    return switch (words) {
      'oqishni pauza qil' || 'pause reading' || 'приостанови чтение' => pause,
      'oqishni davom ettir' ||
      'continue reading aloud' ||
      'resume reading aloud' ||
      'продолжи чтение вслух' => resume,
      'oqishni toxtat' || 'stop reading' || 'останови чтение' => stop,
      _ => null,
    };
  }
}
