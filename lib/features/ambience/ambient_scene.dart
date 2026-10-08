import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'ambient_audio.dart';

class AmbientScene extends StatefulWidget {
  final String palette;
  final bool active;
  const AmbientScene({super.key, required this.palette, this.active = true});
  @override
  State<AmbientScene> createState() => _AmbientSceneState();
}

class _AmbientSceneState extends State<AmbientScene> {
  bool busy = false;
  String? error;
  @override
  void didUpdateWidget(covariant AmbientScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.palette != widget.palette && AmbientAudio.instance != null) {
      unawaited(change());
    }
  }

  Future<void> change({bool toggle = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final audio = await AmbientAudio.open();
      if (!mounted) return;
      await audio.select(widget.palette, context.tr(widget.palette));
      if (toggle) {
        if (audio.player.playing) {
          await audio.pause();
        } else {
          unawaited(
            audio.play().catchError((Object _) {
              if (mounted) {
                setState(() => error = context.tr('ambientUnavailable'));
              }
            }),
          );
        }
      }
    } catch (_) {
      if (mounted) error = context.tr('ambientUnavailable');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        // A swipe during loading must end on the latest selected scene.
        if (error == null && AmbientAudio.instance?.palette != widget.palette) {
          unawaited(change());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = AmbientAudio.instance;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1.08,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/ambience/${widget.palette}.jpg',
              fit: BoxFit.cover,
              cacheWidth:
                  (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round()
                      .clamp(320, 1440),
              errorBuilder: (_, _, _) => ColoredBox(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Colors.transparent,
                    Color(0xDD000000),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Text(
                context.tr(widget.palette),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: StreamBuilder(
                stream: audio?.playbackState,
                builder: (context, snapshot) {
                  final playing = audio?.player.playing ?? false;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (audio != null)
                        Slider(
                          value: audio.volume,
                          max: .65,
                          activeColor: Colors.white,
                          onChangeEnd: (value) => audio.setVolume(value),
                          onChanged: (value) async {
                            await audio.setVolume(value, persist: false);
                            if (mounted) setState(() {});
                          },
                        ),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: context.tr(
                              playing ? 'ambientMute' : 'ambientUnmute',
                            ),
                            onPressed: busy ? null : () => change(toggle: true),
                            icon: busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    playing ? Icons.pause : Icons.play_arrow,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              error ?? context.tr('quietMoment'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          if (audio != null)
                            PopupMenuButton<int>(
                              tooltip: context.tr('hPause'),
                              icon: Icon(
                                Icons.bedtime_outlined,
                                color: audio.sleepUntil == null
                                    ? Colors.white
                                    : Colors.amber,
                              ),
                              onSelected: (n) {
                                audio.sleepAfter(
                                  n == 0 ? null : Duration(minutes: n),
                                );
                                setState(() {});
                              },
                              itemBuilder: (c) => [
                                for (final n in [0, 15, 30, 60, 90])
                                  PopupMenuItem(
                                    value: n,
                                    child: Text(
                                      n == 0
                                          ? c.tr('cancel')
                                          : Duration(minutes: n)
                                                .toString()
                                                .split('.')
                                                .first,
                                    ),
                                  ),
                              ],
                            ),
                          if (playing)
                            IconButton(
                              tooltip: context.tr('xStop'),
                              onPressed: () => audio?.stop(),
                              icon: const Icon(Icons.stop, color: Colors.white),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
