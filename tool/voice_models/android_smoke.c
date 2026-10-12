/* Local native compatibility probe, no microphone, network, app data or keys.
 * Build against the exact sherpa-onnx 1.13.8 c-api.h and Android arm64 library.
 * This silence probe alone does not qualify recognition accuracy or all devices.
 */
#include "c-api.h"
#include <stdio.h>
#include <string.h>
#include <sys/resource.h>
#include <time.h>
#include <stdlib.h>

int main(int argc, char **argv) {
  // Optional address-space ceiling for a reproducible constrained-memory probe.
  if (argc > 2) {
    struct rlimit limit = {strtoull(argv[2], NULL, 10) * 1024 * 1024, RLIM_INFINITY};
    if (setrlimit(RLIMIT_AS, &limit)) { perror("setrlimit"); return 4; }
  }
  const clock_t start = clock();
  SherpaOnnxOnlineRecognizerConfig config = {0};
  config.feat_config.sample_rate = 16000;
  config.feat_config.feature_dim = 80;
  config.model_config.transducer.encoder = "vosk-uz-060-encoder.onnx";
  config.model_config.transducer.decoder = "vosk-uz-060-decoder.onnx";
  config.model_config.transducer.joiner = "vosk-uz-060-joiner.onnx";
  config.model_config.tokens = "vosk-uz-060-tokens.txt";
  config.model_config.num_threads = 2;
  config.model_config.provider = "cpu";
  config.model_config.model_type = "zipformer2";
  config.decoding_method = "greedy_search";
  const SherpaOnnxOnlineRecognizer *recognizer = SherpaOnnxCreateOnlineRecognizer(&config);
  if (!recognizer) { fprintf(stderr, "FAIL: create recognizer\n"); return 1; }
  const SherpaOnnxOnlineStream *stream = SherpaOnnxCreateOnlineStream(recognizer);
  if (!stream) { SherpaOnnxDestroyOnlineRecognizer(recognizer); return 2; }
  float silence[16000] = {0};
  const SherpaOnnxWave *wave = argc > 1 ? SherpaOnnxReadWave(argv[1]) : NULL;
  if (argc > 1 && (!wave || wave->sample_rate != 16000)) {
    fprintf(stderr, "FAIL: expected mono 16kHz WAV\n"); return 5;
  }
  if (wave) SherpaOnnxOnlineStreamAcceptWaveform(stream, 16000, wave->samples, wave->num_samples);
  else {
    SherpaOnnxOnlineStreamAcceptWaveform(stream, 16000, silence, 16000);
    SherpaOnnxOnlineStreamAcceptWaveform(stream, 16000, silence, 16000);
  }
  SherpaOnnxOnlineStreamAcceptWaveform(stream, 16000, silence, 16000);
  SherpaOnnxOnlineStreamInputFinished(stream);
  while (SherpaOnnxIsOnlineStreamReady(recognizer, stream))
    SherpaOnnxDecodeOnlineStream(recognizer, stream);
  const SherpaOnnxOnlineRecognizerResult *result = SherpaOnnxGetOnlineStreamResult(recognizer, stream);
  const int failed = !result || !result->text || (wave ? !strlen(result->text) : strlen(result->text) != 0);
  struct rusage usage;
  getrusage(RUSAGE_SELF, &usage);
  printf("%s: local decoding. text='%s', CPU=%.3fs, peakRSS=%ld KiB\n",
         failed ? "FAIL" : "PASS", result ? result->text : "null",
         (double)(clock() - start) / CLOCKS_PER_SEC, usage.ru_maxrss);
  if (result) SherpaOnnxDestroyOnlineRecognizerResult(result);
  if (wave) SherpaOnnxFreeWave(wave);
  SherpaOnnxDestroyOnlineStream(stream);
  SherpaOnnxDestroyOnlineRecognizer(recognizer);
  return failed ? 3 : 0;
}
