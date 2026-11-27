import 'dart:ui' show SemanticsAction;

import 'voice_command.dart';

class VoiceScreenCommand {
  final SemanticsAction action;
  final String target;
  final String? text;

  const VoiceScreenCommand(this.action, this.target, [this.text]);

  static String words(String value) =>
      VoiceCommand.normalize(value)
          .toLowerCase()
          .replaceAll(RegExp(r"[^\p{L}\p{N}']+", unicode: true), ' ')
          .trim();

  static VoiceScreenCommand? parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final uzbekDictation = RegExp(
      r'^(.+?)(?: maydoniga|ga)\s+(.+?)(?:\s+deb)?\s+yoz[.!?]*$',
      caseSensitive: false,
    ).firstMatch(text);
    final englishDictation = RegExp(
      r'^(?:type|dictate) (.+?) into (?:the )?(.+?)(?: field)?[.!?]*$',
      caseSensitive: false,
    ).firstMatch(text);
    final russianDictation = RegExp(
      r'^(?:введи|напиши) в поле (\S+) (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    final targetField =
        uzbekDictation?[1] ?? englishDictation?[2] ?? russianDictation?[1];
    final dictatedText =
        uzbekDictation?[2] ?? englishDictation?[1] ?? russianDictation?[2];
    if (targetField != null &&
        dictatedText != null &&
        dictatedText.length <= 4000) {
      return VoiceScreenCommand(
        SemanticsAction.setText,
        words(targetField),
        dictatedText,
      );
    }
    final colon = text.indexOf(':');
    if (colon != -1) {
      final request = words(text.substring(0, colon));
      final body = text.substring(colon + 1).trim();
      final target = RegExp(r"^(?:yoz|matn yoz|type|dictate|введи)(?: (.+))?$")
          .firstMatch(request);
      if (target != null && body.isNotEmpty && body.length <= 4000) {
        return VoiceScreenCommand(
          SemanticsAction.setText,
          target[1] ?? '',
          body,
        );
      }
    }
    var name = words(text).replaceAll(
      RegExp(r'\b(?:iltimos|please|пожалуйста|tugmasini|tugmani|bandini)\b'),
      '',
    );
    name = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    const directions = {
      'pastga': SemanticsAction.scrollUp,
      'pastga tush': SemanticsAction.scrollUp,
      'scroll down': SemanticsAction.scrollUp,
      'вниз': SemanticsAction.scrollUp,
      'прокрути вниз': SemanticsAction.scrollUp,
      'yuqoriga': SemanticsAction.scrollDown,
      'yuqoriga chiq': SemanticsAction.scrollDown,
      'scroll up': SemanticsAction.scrollDown,
      'вверх': SemanticsAction.scrollDown,
      'прокрути вверх': SemanticsAction.scrollDown,
      'chapga': SemanticsAction.scrollRight,
      'scroll left': SemanticsAction.scrollRight,
      'влево': SemanticsAction.scrollRight,
      'o\'ngga': SemanticsAction.scrollLeft,
      'scroll right': SemanticsAction.scrollLeft,
      'вправо': SemanticsAction.scrollLeft,
    };
    final direction = directions[name.replaceFirst(RegExp(r' sur$'), '')];
    if (direction != null) return VoiceScreenCommand(direction, '');
    for (final entry in {
      SemanticsAction.longPress: r'^(?:bosib tur|long press|удерживай) (.+)$',
      SemanticsAction.increase: r'^(?:oshir|increase|увеличь) (.+)$',
      SemanticsAction.decrease: r'^(?:kamaytir|decrease|уменьши) (.+)$',
    }.entries) {
      final match = RegExp(entry.value).firstMatch(name);
      if (match != null) return VoiceScreenCommand(entry.key, match[1]!);
    }
    const back = {'go back', 'orqaga qayt', 'ortga qayt', 'вернись назад'};
    if (back.contains(name)) {
      return const VoiceScreenCommand(SemanticsAction.tap, 'back');
    }
    name = name
        .replaceFirst(
          RegExp(r'^(?:bos|och|tanla|tap|open|select|нажми|открой|выбери) '),
          '',
        )
        .replaceFirst(RegExp(r' (?:bos|och|tanla|tugmasiga bos)$'), '');
    return name.isEmpty ? null : VoiceScreenCommand(SemanticsAction.tap, name);
  }

  static int? option(String input) {
    final value = input.replaceFirst(RegExp(r"^(?:raqam|number|номер) "), '');
    const spoken = {
      'bir': 1,
      'birinchi': 1,
      'ikki': 2,
      'ikkinchi': 2,
      'uch': 3,
      'uchinchi': 3,
      'to\'rt': 4,
      'besh': 5,
      'olti': 6,
      'yetti': 7,
      'sakkiz': 8,
      'to\'qqiz': 9,
      'o\'n': 10,
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'один': 1,
      'два': 2,
      'три': 3,
      'четыре': 4,
      'пять': 5,
    };
    return int.tryParse(value) ?? spoken[value];
  }

  static Set<String> terms(String input) => words(input)
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(
        (word) => switch (word) {
          'saqla' ||
          'saqlash' ||
          'saqlashni' ||
          'saqlang' ||
          'save' ||
          'сохрани' ||
          'сохранить' => 'save',
          'ortga' || 'orqaga' || 'back' || 'назад' => 'back',
          'yop' || 'yopish' || 'close' || 'закрой' || 'закрыть' => 'close',
          'qo\'sh' || 'qo\'shish' || 'add' || 'добавь' || 'добавить' => 'add',
          _ => word,
        },
      )
      .toSet();
}
