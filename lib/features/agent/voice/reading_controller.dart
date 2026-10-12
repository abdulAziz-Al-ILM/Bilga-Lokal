import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voice_languages.dart';

abstract class OfflineReadingOutput {
  Future<bool> speak(String text, String language);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
}

class ReadingChunk {
  final String text, language;
  final int start;
  const ReadingChunk(this.text, this.language, this.start);
}

List<ReadingChunk> readingChunks(
  String text,
  String preferred, {
  int limit = 1200,
}) {
  if (limit < 2) throw ArgumentError.value(limit);
  final result = <ReadingChunk>[];
  // Preserve every UTF-16 code unit, including line breaks and surrogate pairs.
  for (final sentence in RegExp(
    r'[^.!?。！？\n]+[.!?。！？\n]*|[.!?。！？\n]+',
  ).allMatches(text)) {
    var offset = sentence.start;
    while (offset < sentence.end) {
      var end = (offset + limit).clamp(offset, sentence.end);
      if (end < sentence.end) {
        final space = text.lastIndexOf(' ', end - 1);
        if (space > offset + limit ~/ 2) end = space + 1;
        if (end > offset &&
            text.codeUnitAt(end - 1) >= 0xd800 &&
            text.codeUnitAt(end - 1) <= 0xdbff) {
          end--;
        }
      }
      final part = text.substring(offset, end);
      result.add(ReadingChunk(part, textLanguage(part, preferred), offset));
      offset = end;
    }
  }
  return result;
}

/// Pause leaves the current audio future and position intact. Only a new text
/// or dispose invalidates the session; late completions cannot advance it.
class ReadingController extends ChangeNotifier {
  final OfflineReadingOutput output;
  ReadingController(this.output);
  List<ReadingChunk> chunks = [];
  int index = 0, _epoch = 0;
  bool active = false, paused = false;
  String? error;
  Completer<void>? _resume;
  Future<void> read(String text, String preferred) async {
    final epoch = ++_epoch;
    _releaseWait();
    active = false;
    paused = false;
    error = null;
    await output.stop();
    if (epoch != _epoch) return;
    chunks = readingChunks(text, preferred);
    index = 0;
    active = chunks.isNotEmpty;
    notifyListeners();
    try {
      while (index < chunks.length && epoch == _epoch) {
        if (paused) await (_resume ??= Completer<void>()).future;
        if (epoch != _epoch) return;
        final chunk = chunks[index];
        final completed =
            chunk.text.trim().isEmpty ||
            await output.speak(chunk.text, chunk.language);
        if (epoch != _epoch) return;
        if (!completed) break;
        index++;
        notifyListeners();
      }
    } catch (_) {
      if (epoch == _epoch) error = chunks[index].language;
    } finally {
      if (epoch == _epoch) {
        active = false;
        paused = false;
        notifyListeners();
      }
    }
  }

  Future<void> pause() async {
    if (!active) return;
    paused = true;
    notifyListeners();
    await output.pause();
  }

  Future<void> resume() async {
    if (!active || !paused) return;
    paused = false;
    _releaseWait();
    notifyListeners();
    await output.resume();
  }

  void _releaseWait() {
    _resume?.complete();
    _resume = null;
  }

  Future<void> stop() async {
    _epoch++;
    _releaseWait();
    active = false;
    paused = false;
    notifyListeners();
    await output.stop();
  }

  @override
  void dispose() {
    _epoch++;
    _releaseWait();
    unawaited(output.stop());
    super.dispose();
  }
}
