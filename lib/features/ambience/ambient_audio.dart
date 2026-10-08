import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AmbientAudio extends BaseAudioHandler {
  static AmbientAudio? instance;
  static Future<AmbientAudio>? _opening;
  static Future<AmbientAudio> open() =>
      _opening ??= _open().catchError((Object error) {
        _opening = null;
        throw error;
      });
  static Future<AmbientAudio> _open() async {
    final handler = await AudioService.init<AmbientAudio>(
      builder: AmbientAudio.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ilmmizan.bilga.ambience',
        androidNotificationChannelName: 'Bilga ambience',
        androidNotificationOngoing: true,
        androidNotificationIcon: 'drawable/ic_bilga_audio',
      ),
    );
    instance = handler;
    final prefs = await SharedPreferences.getInstance();
    handler.volume = (prefs.getDouble('bilga.ambientVolume') ?? .3).clamp(
      0.0,
      .65,
    );
    await (await AudioSession.instance).configure(
      const AudioSessionConfiguration.music(),
    );
    return handler;
  }

  final player = AudioPlayer();
  String? palette;
  double volume = .3;
  bool _ducked = false;
  Timer? _sleep;
  DateTime? sleepUntil;
  void sleepAfter(Duration? duration) {
    _sleep?.cancel();
    sleepUntil = duration == null ? null : DateTime.now().add(duration);
    if (duration != null) _sleep = Timer(duration, () => unawaited(stop()));
    _broadcast();
  }

  Future<void> _queue = Future.value();
  AmbientAudio() {
    player.playbackEventStream.listen(
      (event) => _broadcast(),
      onError: (Object error, StackTrace stack) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            playing: false,
            errorMessage: 'Audio unavailable',
          ),
        );
      },
    );
    player.playerStateStream.listen((_) => _broadcast());
  }
  void _broadcast() => playbackState.add(
    PlaybackState(
      controls: [
        player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
      ],
      androidCompactActionIndices: const [0, 1],
      processingState: switch (player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
    ),
  );
  Future<void> select(String key, String title) {
    final operation = _queue.then((_) async {
      if (key == palette && player.audioSource != null) return;
      final resume = player.playing;
      await player.pause();
      await player.setAsset('assets/ambience/$key.m4a');
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(_ducked ? volume * .15 : volume);
      palette = key;
      mediaItem.add(
        MediaItem(
          id: key,
          title: title,
          artist: 'Bilga',
          duration: player.duration,
        ),
      );
      if (resume) {
        unawaited(
          play().catchError((Object _) {
            playbackState.add(
              playbackState.value.copyWith(
                processingState: AudioProcessingState.error,
                playing: false,
                errorMessage: 'Audio unavailable',
              ),
            );
          }),
        );
      }
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> setVolume(double value, {bool persist = true}) async {
    volume = value.clamp(0.0, .65);
    await player.setVolume(_ducked ? volume * .15 : volume);
    if (persist) {
      await (await SharedPreferences.getInstance()).setDouble(
        'bilga.ambientVolume',
        volume,
      );
    }
  }

  Future<void> duck(bool value) async {
    _ducked = value;
    await player.setVolume(value ? volume * .15 : volume);
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> stop() async {
    _sleep?.cancel();
    sleepUntil = null;
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() => stop();
}
