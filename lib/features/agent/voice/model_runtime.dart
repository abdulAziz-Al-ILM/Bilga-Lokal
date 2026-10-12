// Pure local inference. No HTTP client, platform channel or personal-data upload.
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'model_catalog.dart';

// Keep closures outside the microphone/playback session's lexical scope.
// Otherwise Isolate.run can also capture its unsendable Completer, recorder or
// platform-channel state, failing before the native decoder is initialized.
Future<String> recognizeModelInBackground(
  VoiceModel model,
  String dir,
  Float32List samples, {
  String? libraryPath,
}) => Isolate.run(
  () => recognizeModel(model, dir, samples, libraryPath: libraryPath),
  debugName: 'bilga-stt',
);

Future<void> synthesizeModelInBackground(
  VoiceModel model,
  String dir,
  String text,
  String file,
) => Isolate.run(
  () => synthesizeModel(model, dir, text, file),
  debugName: 'bilga-tts',
);

String _modelPath(VoiceModel model, String dir, String key) =>
    model.config[key] == null ? '' : p.join(dir, model.config[key] as String);

void synthesizeModel(VoiceModel model, String dir, String text, String file) {
  sherpa.initBindings();
  final tts = sherpa.OfflineTts(
    sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        numThreads: 2,
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: _modelPath(model, dir, 'model'),
          tokens: _modelPath(model, dir, 'tokens'),
          lexicon: _modelPath(model, dir, 'lexicon'),
          dataDir: _modelPath(model, dir, 'dataDir'),
        ),
      ),
    ),
  );
  try {
    final audio = tts.generate(text: text, sid: 0, speed: 1);
    if (audio.samples.isEmpty ||
        !sherpa.writeWave(
          filename: file,
          samples: audio.samples,
          sampleRate: audio.sampleRate,
        )) {
      throw StateError('offline_synthesis_failed');
    }
  } finally {
    tts.free();
  }
}

String recognizeModel(
  VoiceModel model,
  String dir,
  Float32List samples, {
  String? libraryPath,
}) {
  developer.log(
    'STT worker started; engine=${model.engine}',
    name: 'BilgaOfflineVoice',
  );
  sherpa.initBindings(libraryPath);
  developer.log('STT native bindings ready', name: 'BilgaOfflineVoice');
  if (model.engine == 'streaming_transducer') {
    return recognizeStreamingTransducer(
      encoder: _modelPath(model, dir, 'encoder'),
      decoder: _modelPath(model, dir, 'decoder'),
      joiner: _modelPath(model, dir, 'joiner'),
      tokens: _modelPath(model, dir, 'tokens'),
      samples: samples,
    );
  }
  final recognizer = sherpa.OfflineRecognizer(
    sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        numThreads: 2,
        tokens: _modelPath(model, dir, 'tokens'),
        whisper: model.engine == 'whisper'
            ? sherpa.OfflineWhisperModelConfig(
                encoder: _modelPath(model, dir, 'encoder'),
                decoder: _modelPath(model, dir, 'decoder'),
                // Auto-detect among the model's actual languages, rather than forcing UI language.
              )
            : const sherpa.OfflineWhisperModelConfig(),
        senseVoice: model.engine == 'sense_voice'
            ? sherpa.OfflineSenseVoiceModelConfig(
                model: _modelPath(model, dir, 'model'),
              )
            : const sherpa.OfflineSenseVoiceModelConfig(),
      ),
    ),
  );
  final stream = recognizer.createStream();
  try {
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    recognizer.decode(stream);
    return recognizer.getResult(stream).text;
  } finally {
    stream.free();
    recognizer.free();
  }
}

/// Sherpa's "Online" API means incremental local decoding, not internet STT.
/// This entry point also permits a host smoke test without asserting Android review.
String recognizeStreamingTransducer({
  required String encoder,
  required String decoder,
  required String joiner,
  required String tokens,
  required Float32List samples,
  String? libraryPath,
}) {
  sherpa.initBindings(libraryPath);
  final recognizer = sherpa.OnlineRecognizer(
    sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: encoder,
          decoder: decoder,
          joiner: joiner,
        ),
        tokens: tokens,
        numThreads: 2,
        provider: 'cpu',
        debug: false,
        modelType: 'zipformer2',
      ),
      enableEndpoint: false,
    ),
  );
  developer.log('STT streaming decoder ready', name: 'BilgaOfflineVoice');
  final stream = recognizer.createStream();
  try {
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    // Flush the last chunk and right context so the end of a command is retained.
    stream.acceptWaveform(samples: Float32List(16000), sampleRate: 16000);
    stream.inputFinished();
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    developer.log('STT decode completed', name: 'BilgaOfflineVoice');
    return recognizer.getResult(stream).text;
  } finally {
    stream.free();
    recognizer.free();
  }
}
