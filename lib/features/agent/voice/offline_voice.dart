import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'model_store.dart';
import 'model_runtime.dart';
import 'reading_controller.dart';

class VoiceCapabilities {
  final int sdk;
  final List<String> abis;
  final String stt;
  final bool tts;
  const VoiceCapabilities(this.sdk, this.abis, this.stt, this.tts);
}

class OfflineVoice implements OfflineReadingOutput {
  static const channel = MethodChannel('bilga/voice');
  final VoiceModelStore store;
  OfflineVoice(this.store);
  bool _paused = false;
  int _epoch = 0, _listenEpoch = 0;
  final _deviceCapabilities = <String, Map<String, dynamic>>{};
  void invalidateCapabilities() => _deviceCapabilities.clear();
  Future<void> openTtsSettings() => channel.invokeMethod<void>('ttsSettings');
  Future<void> refreshSystemTts() async {
    await channel.invokeMethod<void>('refreshTts');
    invalidateCapabilities();
  }

  /// Called only after explicit model-download consent; never from listen/speak.
  /// Availability stays independent for STT and TTS and for each catalog language.
  Future<List<String>> downloadMissingModels(String language) async {
    await store.refresh();
    invalidateCapabilities();
    final cap = await capabilities(language);
    final missing = <String>[];
    for (final kind in ['stt', 'tts']) {
      if ((kind == 'stt' && {'available', 'model'}.contains(cap.stt)) ||
          (kind == 'tts' && cap.tts)) {
        continue;
      }
      final candidates = store.catalog!.models.where(
        (m) =>
            m.kind == kind &&
            m.languages.contains(language.split('-').first) &&
            m.compatible(cap.sdk, cap.abis),
      );
      if (candidates.isEmpty) {
        missing.add(kind);
      } else {
        await store.install(candidates.first, sdk: cap.sdk, abis: cap.abis);
      }
    }
    invalidateCapabilities();
    return missing;
  }

  AudioRecorder? _recorder;
  Completer<void>? _recordDone;
  Future<VoiceCapabilities> capabilities(String language) async {
    final data =
        _deviceCapabilities[language] ??
        await channel.invokeMapMethod<String, dynamic>('capabilities', {
          'language': language,
        });
    if (data != null) _deviceCapabilities[language] = data;
    final sdk = data?['sdk'] as int? ?? 0;
    final abis = List<String>.from(data?['abis'] as List? ?? []);
    final sttModel = await store.find(language, 'stt', sdk, abis);
    final ttsModel = await store.find(language, 'tts', sdk, abis);
    return VoiceCapabilities(
      sdk,
      abis,
      sttModel != null ? 'model' : data?['stt'] as String? ?? 'unavailable',
      ttsModel != null || data?['tts'] == true,
    );
  }

  @override
  Future<bool> speak(String text, String language) async {
    final epoch = _epoch;
    final cap = await capabilities(language);
    if (epoch != _epoch) return false;
    final model = await store.find(language, 'tts', cap.sdk, cap.abis);
    if (epoch != _epoch) return false;
    if (model == null) {
      return await channel.invokeMethod<bool>('speak', {
            'text': text,
            'language': language,
            'paused': _paused,
          }) ??
          false;
    }
    final dir = store.directory(model).path;
    final cache = await getTemporaryDirectory();
    final file = p.join(
      cache.path,
      'bilga-local-voice-$epoch-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    try {
      // FFI generation stays off the UI isolate so Stop remains responsive.
      await synthesizeModelInBackground(model, dir, text, file);
      if (epoch != _epoch) return false;
      return await channel.invokeMethod<bool>('playFile', {
            'path': file,
            'paused': _paused,
          }) ??
          false;
    } finally {
      final audio = File(file);
      if (await audio.exists()) await audio.delete();
    }
  }

  @override
  Future<void> pause() async {
    _paused = true;
    await channel.invokeMethod<void>('pause');
  }

  @override
  Future<void> resume() async {
    _paused = false;
    await channel.invokeMethod<void>('resume');
  }

  @override
  Future<void> stop() async {
    _epoch++;
    _paused = false;
    await channel.invokeMethod<void>('stop');
  }

  Future<String?> listen(String language) async {
    final epoch = ++_listenEpoch;
    final cap = await capabilities(language);
    if (epoch != _listenEpoch) return null;
    final model = await store.find(language, 'stt', cap.sdk, cap.abis);
    if (epoch != _listenEpoch) return null;
    if (model == null) {
      if (cap.stt == 'unavailable') {
        throw PlatformException(code: 'offline_unavailable');
      }
      return channel.invokeMethod<String>('listen', {'language': language});
    }
    final recorder = AudioRecorder();
    _recorder = recorder;
    final done = Completer<void>();
    _recordDone = done;
    StreamSubscription<Uint8List>? subscription;
    Timer? timeout;
    final pcm = BytesBuilder(copy: false);
    var quietSamples = 0, heard = false;
    var stage = 'microphone_permission';
    try {
      if (!await recorder.hasPermission()) {
        throw PlatformException(code: 'permission');
      }
      if (epoch != _listenEpoch) return null;
      stage = 'microphone_start';
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      subscription = stream.listen(
        (bytes) {
          if (done.isCompleted) return;
          pcm.add(bytes);
          final view = ByteData.sublistView(bytes);
          var peak = 0;
          for (var i = 0; i + 1 < bytes.length; i += 2) {
            final amplitude = view.getInt16(i, Endian.little).abs();
            if (amplitude > peak) peak = amplitude;
          }
          if (peak > 600) {
            heard = true;
            quietSamples = 0;
          } else {
            quietSamples += bytes.length ~/ 2;
          }
          if ((heard && quietSamples > 16000) || pcm.length >= 16000 * 2 * 20) {
            done.complete();
          }
        },
        onError: (Object error) {
          if (!done.isCompleted) done.completeError(error);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      timeout = Timer(const Duration(seconds: 20), () {
        if (!done.isCompleted) done.complete();
      });
      stage = 'microphone_capture';
      await done.future;
      stage = 'microphone_stop';
      await recorder.stop();
      await subscription.cancel();
      subscription = null;
      if (epoch != _listenEpoch || !heard) return null;
      final data = pcm.takeBytes();
      final samples = Float32List(data.length ~/ 2);
      final view = ByteData.sublistView(data);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = view.getInt16(i * 2, Endian.little) / 32768;
      }
      final dir = store.directory(model).path;
      stage = 'model_worker';
      if (kDebugMode) debugPrint('BilgaOfflineVoice: STT worker starting');
      final result = await recognizeModelInBackground(model, dir, samples);
      if (kDebugMode) debugPrint('BilgaOfflineVoice: STT decode completed');
      return epoch == _listenEpoch ? result : null;
    } catch (error, stack) {
      // Never log raw exceptions (which can contain captured state), audio,
      // recognized words or note text. Keep useful stage/type diagnostics local.
      if (kDebugMode) {
        debugPrint(
          'BilgaOfflineVoice: STT failed; stage=$stage; type=${error.runtimeType}',
        );
      }
      developer.log(
        'STT failed; stage=$stage; type=${error.runtimeType}',
        name: 'BilgaOfflineVoice',
        level: 1000,
        stackTrace: stack,
      );
      rethrow;
    } finally {
      timeout?.cancel();
      await subscription?.cancel();
      await recorder.dispose();
      if (identical(_recorder, recorder)) {
        _recorder = null;
        _recordDone = null;
      }
    }
  }

  Future<void> cancelListening() async {
    _listenEpoch++;
    final done = _recordDone;
    if (done != null && !done.isCompleted) done.complete();
    await _recorder?.cancel();
    await channel.invokeMethod<void>('cancel');
  }
}
