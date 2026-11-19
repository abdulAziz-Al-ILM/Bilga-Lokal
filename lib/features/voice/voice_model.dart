import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/private_database.dart';
import 'voice_command.dart';

typedef VoiceInterpretation = ({VoiceCommand? command, String? reply});

/// The model receives the utterance only. It cannot access Bilga's stores or UI.
class VoiceModel {
  static const filename = 'bilga-voice-qwen3-0.6b-q4.gguf';
  static const size = 428970080;
  static const sha =
      'da2572f16c06133561ce56accaa822216f2391ef4d37fba427801cd6736417d4';
  static final source = Uri.parse(
    'https://huggingface.co/ggml-org/Qwen3-0.6B-GGUF/resolve/'
    'afe8ad3577aa22500b3cd1c880f153b3b0e1cae8/Qwen3-0.6B-Q4_0.gguf',
  );
  static bool _busy = false;
  HttpClient? _download;
  LlamaController? _runtime;
  bool _cancelled = false, _verified = false;
  int _generation = 0;

  Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/$filename');

  Future<bool> supported({bool downloading = false}) async {
    if (!Platform.isAndroid) return false;
    final device = await PrivateDatabase.channel
        .invokeMapMethod<String, dynamic>('device');
    return device?['arm64'] == true &&
        device?['lowMemory'] != true &&
        (device?['available'] as num? ?? 0) >= 1000000000 &&
        (!downloading || (device?['disk'] as num? ?? 0) >= size + 100000000);
  }

  Future<bool> installed() async {
    if (!Platform.isAndroid) return false;
    final model = await _file();
    return await model.exists() && await model.length() == size;
  }

  Future<bool> _valid(File file) async =>
      await file.exists() &&
      await file.length() == size &&
      (await crypto.sha256.bind(file.openRead()).first).toString() == sha;

  Future<void> download(void Function(double) onProgress) async {
    final attempt = _generation;
    if (_download != null || !await supported(downloading: true)) {
      throw StateError('voice_model_device');
    }
    final target = await _file();
    if (await _valid(target)) return;
    if (attempt != _generation || _download != null) return;
    final partial = File('${target.path}.part');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    _download = client;
    IOSink? output;
    try {
      final response = await (await client.getUrl(source))
          .close()
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != HttpStatus.ok ||
          (response.contentLength >= 0 && response.contentLength != size)) {
        throw const FormatException('voice_model_download');
      }
      output = partial.openWrite();
      var bytes = 0;
      var percent = 0;
      await output.addStream(
        response.timeout(const Duration(seconds: 45)).map((chunk) {
          bytes += chunk.length;
          if (bytes > size) throw const FormatException('voice_model_size');
          final next = bytes * 100 ~/ size;
          if (next > percent) {
            percent = next;
            onProgress(bytes / size);
          }
          return chunk;
        }),
      );
      await output.close();
      output = null;
      if (!await _valid(partial) || attempt != _generation) {
        throw const FormatException('voice_model_hash');
      }
      await partial.rename(target.path);
      _verified = true;
    } finally {
      await output?.close();
      client.close(force: true);
      _download = null;
      if (await partial.exists()) await partial.delete();
    }
  }

  void cancel() {
    _generation++;
    _cancelled = true;
    _download?.close(force: true);
    final runtime = _runtime;
    if (runtime != null) unawaited(runtime.stop().catchError((Object _) {}));
  }

  static VoiceInterpretation? decode(String generated) {
    final text = generated
        .replaceFirst(RegExp(r'^\s*<think>[\s\S]*?</think>\s*'), '')
        .trim();
    final action = RegExp(
      r'^ACTION:\s*(\w+)$',
      caseSensitive: false,
    ).firstMatch(text)?[1];
    final command = switch (action?.toLowerCase()) {
      'today' => const VoiceCommand(VoiceAction.today, ''),
      'habits_left' => const VoiceCommand(VoiceAction.pendingHabits, ''),
      'last_friday' => const VoiceCommand(VoiceAction.lastFriday, ''),
      'weekly_spending' => const VoiceCommand(VoiceAction.weeklySpending, ''),
      final name? when VoiceSection.values.any((s) => s.name == name) =>
        VoiceCommand(VoiceAction.openSection, name),
      _ => null,
    };
    if (command != null) return (command: command, reply: null);
    if (text.toUpperCase().startsWith('ACTION:') ||
        text.startsWith('<think>')) {
      return null;
    }
    final reply = text.toUpperCase().startsWith('SAY:')
        ? text.substring(4).trim()
        : text;
    return reply.isEmpty
        ? null
        : (command: null, reply: String.fromCharCodes(reply.runes.take(1100)));
  }

  Future<VoiceInterpretation?> interpret(
    String utterance,
    String language,
  ) async {
    final attempt = _generation;
    if (_busy ||
        !await supported() ||
        !await installed() ||
        _busy ||
        attempt != _generation) {
      return null;
    }
    _busy = true;
    _cancelled = false;
    try {
      final file = await _file();
      if (!_verified && !await _valid(file)) return null;
      _verified = true;
      if (_cancelled) return null;
      final runtime = _runtime = LlamaController();
      await runtime.loadModel(
        modelPath: file.path,
        threads: 4,
        contextSize: 2048,
        gpuLayers: 0,
      );
      if (_cancelled) return null;
      final target = switch (language) {
        'en-US' => 'English',
        'ru-RU' => 'Russian',
        _ => 'Uzbek Latin',
      };
      final safe = utterance.replaceAll('<|', '‹|').replaceAll('|>', '|›');
      final input = jsonEncode(String.fromCharCodes(safe.runes.take(1200)));
      final result = StringBuffer();
      final prompt =
          '<|im_start|>system\nYou are Bilga, a private assistant. '
          'The user message is spoken text in $target. '
          'If the user wants their plan for today, incomplete habits today, writing from LAST FRIDAY, '
          'or total spending THIS WEEK, reply with exactly ACTION: today, ACTION: habits_left, '
          'ACTION: last_friday, or ACTION: weekly_spending respectively. For requests to open '
          'a screen, use ACTION: with exactly one of notes, tasks, habits, finance, experiences, '
          'books, help, alerts, profile. Never claim that you took an action. '
          'Never invent personal information or handle other dates '
          'as today. If an action is not allowed, explain briefly how to use the app. Otherwise '
          'answer simple general questions concisely in $target, prefixing your reply with SAY:. '
          'No other formats.\n<|im_end|>\n<|im_start|>user\n$input /no_think<|im_end|>\n'
          '<|im_start|>assistant\n<think>\n\n</think>\n\n';
      await for (final token
          in runtime
              .generate(prompt: prompt, maxTokens: 144, temperature: .24)
              .timeout(const Duration(seconds: 20))) {
        if (_cancelled) break;
        result.write(token);
      }
      return _cancelled ? null : decode(result.toString());
    } finally {
      try {
        await _runtime?.dispose();
      } finally {
        _runtime = null;
        _busy = false;
      }
    }
  }
}
