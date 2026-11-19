import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_lock.dart';
import '../../core/strings.dart';
import 'speech_bridge.dart';

class VoiceAnswerPage extends StatefulWidget {
  final String title, language;
  final List<String> excerpts;
  const VoiceAnswerPage({
    super.key,
    required this.title,
    required this.language,
    required this.excerpts,
  });

  @override
  State<VoiceAnswerPage> createState() => _AnswerState();
}

class _AnswerState extends State<VoiceAnswerPage> with WidgetsBindingObserver {
  int current = 0, generation = 0;
  bool speaking = false;
  double rate = 1;
  String? error;
  String get text => widget.excerpts[current];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (speaking &&
        (AppLockScope.isLocked(context) ||
            ModalRoute.isCurrentOf(context) == false)) {
      stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && speaking) stop();
  }

  Future<void> speak() async {
    if (AppLockScope.isLocked(context)) return;
    final attempt = ++generation;
    setState(() {
      speaking = true;
      error = null;
    });
    try {
      await SpeechOutput.speak(text, widget.language, rate: rate);
    } on PlatformException catch (e) {
      if (mounted && attempt == generation && e.code != 'cancelled') {
        setState(
          () => error = e.code == 'language' ? 'vaNoVoice' : 'vaUnavailable',
        );
      }
    } catch (_) {
      if (mounted && attempt == generation) {
        setState(() => error = 'vaUnavailable');
      }
    } finally {
      if (mounted && attempt == generation) setState(() => speaking = false);
    }
  }

  Future<void> stop() async {
    generation++;
    if (mounted) setState(() => speaking = false);
    await SpeechOutput.stop();
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    SpeechOutput.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SelectableText(text, style: Theme.of(context).textTheme.titleMedium),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(context.tr(error!)),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: speaking ? stop : speak,
              icon: Icon(speaking ? Icons.stop : Icons.volume_up_outlined),
              label: Text(context.tr(speaking ? 'voiceStop' : 'vaRepeat')),
            ),
            if (widget.excerpts.length > 1) ...[
              OutlinedButton(
                onPressed: current == 0 ? null : () => change(-1),
                child: Text(context.tr('previous')),
              ),
              OutlinedButton(
                onPressed: current == widget.excerpts.length - 1
                    ? null
                    : () => change(1),
                child: Text(context.tr('continue')),
              ),
            ],
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('vaRate')),
          trailing: DropdownButton<double>(
            value: rate,
            items: [
              for (final value in [0.75, 1.0, 1.25, 1.5])
                DropdownMenuItem(value: value, child: Text('$value×')),
            ],
            onChanged: speaking ? null : (v) => setState(() => rate = v!),
          ),
        ),
        if (widget.excerpts.length > 1)
          Text('${current + 1} / ${widget.excerpts.length}'),
      ],
    ),
  );

  Future<void> change(int delta) async {
    await stop();
    if (!mounted) return;
    setState(() => current += delta);
    await speak();
  }
}
