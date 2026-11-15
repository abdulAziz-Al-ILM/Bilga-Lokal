import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import '../private_space/record_store.dart';
import 'attachment_store.dart';

class AttachmentsPage extends StatefulWidget {
  final String kind, owner, title;
  final RecordStore? store;
  const AttachmentsPage({
    super.key,
    required this.kind,
    required this.owner,
    required this.title,
    this.store,
  });
  @override
  State<AttachmentsPage> createState() => _AttachmentsState();
}

class _AttachmentsState extends State<AttachmentsPage> {
  List<PrivateRecord> rows = [];
  bool busy = false;
  @override
  void initState() {
    super.initState();
    run(reload);
  }

  Future<void> reload() async {
    final r = await Attachments.all(
      widget.kind,
      widget.owner,
      store: widget.store,
    );
    if (mounted) {
      setState(
        () => rows = r
            .where(
              (r) => !{
                'bookSource',
                'bookCover',
                'bookIndex',
              }.contains(r.data['role']),
            )
            .toList(),
      );
    }
  }

  Future<void> run(Future<void> Function() f) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await f();
      await reload();
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(PrivateRecord r) async {
    if (r.data['text'] is String) {
      final text = r.data['text'] as String;
      final uri = Uri.tryParse(text.trim());
      if (uri != null &&
          {'https', 'http'}.contains(uri.scheme) &&
          uri.host.isNotEmpty) {
        if (await consent(context, context.tr('xExternal'))) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (c) => AlertDialog(
              content: SingleChildScrollView(child: SelectableText(text)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text(c.tr('cancel')),
                ),
              ],
            ),
          );
        }
      }
      return;
    }
    final mime = r.data['mime'] as String;
    if (mime.startsWith('image/') ||
        mime.startsWith('video/') ||
        mime.startsWith('audio/')) {
      final d = await Directory(
        '${(await getTemporaryDirectory()).path}/private-preview',
      ).create(recursive: true);
      final f = File('${d.path}/${localId()}');
      try {
        final sink = f.openWrite();
        try {
          await sink.addStream(Attachments.read(r.data['blob']));
        } finally {
          await sink.close();
        }
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _Preview(f, mime)),
          );
        }
      } finally {
        if (await f.exists()) await f.delete();
      }
    } else {
      if (await consent(context, context.tr('xPlainExport'))) {
        await Attachments.export(
          r.data['title'],
          mime,
          Attachments.read(r.data['blob']),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        if (busy) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        for (final item in await Attachments.pick()) {
                          await Attachments.add(
                            widget.kind,
                            widget.owner,
                            item,
                            store: widget.store,
                          );
                        }
                      }),
                icon: const Icon(Icons.attach_file),
                label: Text(context.tr('xAttach')),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        await editFields(
                          context,
                          context.tr('xLink'),
                          {'text': context.tr('xLink')},
                          multiline: {'text'},
                          requiredFields: {'text'},
                          onSave: (v) => Attachments.text(
                            widget.kind,
                            widget.owner,
                            v['text']!,
                            store: widget.store,
                          ),
                        );
                      }),
                child: Text(context.tr('xLink')),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final r in rows)
                ListTile(
                  title: Text(
                    r.data['title'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    r.data['blob'] == null
                        ? ''
                        : '${((r.data['size'] as int) / 1048576).toStringAsFixed(1)} MB',
                  ),
                  onTap: busy ? null : () => run(() => open(r)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed:
                        busy ||
                            {
                              'bookSource',
                              'bookCover',
                              'bookIndex',
                            }.contains(r.data['role'])
                        ? null
                        : () => run(() async {
                            if (await consent(
                              context,
                              context.tr('deleteForever'),
                            )) {
                              await Attachments.remove(r, store: widget.store);
                            }
                          }),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Preview extends StatefulWidget {
  final File file;
  final String mime;
  const _Preview(this.file, this.mime);
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  VideoPlayerController? player;
  String? error;
  @override
  void initState() {
    super.initState();
    if (!widget.mime.startsWith('image/')) {
      player = VideoPlayerController.file(widget.file);
      player!
          .initialize()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((Object _) {
            if (mounted) setState(() => error = 'Playback unavailable');
          });
    }
  }

  @override
  void dispose() {
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: widget.mime.startsWith('image/')
          ? InteractiveViewer(
              child: Image.file(
                widget.file,
                cacheWidth: 1600,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
              ),
            )
          : error != null
          ? Text(error!)
          : player?.value.isInitialized != true
          ? const CircularProgressIndicator()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AspectRatio(
                  aspectRatio: player!.value.aspectRatio > 0
                      ? player!.value.aspectRatio
                      : 1,
                  child: VideoPlayer(player!),
                ),
                IconButton(
                  icon: Icon(
                    player!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: () async {
                    if (player!.value.isPlaying) {
                      await player!.pause();
                    } else {
                      await player!.play();
                    }
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
    ),
  );
}
