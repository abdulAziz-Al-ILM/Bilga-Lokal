import '../../core/app_lock.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import 'voice_command.dart';
import 'voice_actions.dart';
import 'speech_bridge.dart';

class VoicePage extends StatefulWidget {
  final SpeechBridge? speech;
  final VoiceActions? actions;
  const VoicePage({super.key, this.speech, this.actions});
  @override
  State<VoicePage> createState() => _VoiceState();
}

class _VoiceState extends State<VoicePage> with WidgetsBindingObserver {
  late final speech = widget.speech ?? SpeechBridge();
  late final actions = widget.actions ?? VoiceActions();
  final text = TextEditingController();
  Map<String, dynamic>? state;
  VoiceCommand? command;
  VoiceAnswer? answer;
  String language = 'uz-UZ', partial = '', status = '', error = '';
  String? outputError;
  bool deviceOnly = true, listening = false, acting = false;
  bool conversation = false, speaking = false, authorizing = false;
  bool conversationPaused = false;
  int generation = 0;
  bool get canListen =>
      !acting &&
      !authorizing &&
      state != null &&
      (deviceOnly ? state!['onDevice'] == true : state!['available'] == true);
  bool get screenReady {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return mounted &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        !AppLockScope.isLocked(context) &&
        ModalRoute.isCurrentOf(context) != false;
  }

  bool get controlsBusy =>
      listening ||
      acting ||
      authorizing ||
      (conversation && !conversationPaused);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SpeechBridge.channel.setMethodCallHandler((call) async {
      if (!mounted || !listening) return;
      if (call.method == 'partial') {
        setState(() => partial = call.arguments as String? ?? '');
      }
      if (call.method == 'status') {
        setState(() => status = call.arguments as String? ?? '');
      }
    });
    actions.access.addListener(accessChanged);
    load();
  }

  void accessChanged() {
    if (actions.access.initialized && !actions.access.coreAllowed) cancel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locked = AppLockScope.isLocked(context);
    final visible = ModalRoute.isCurrentOf(context) != false;
    if ((listening || conversation) && (locked || !visible)) {
      cancel();
    }
  }

  Future<void> stop() async {
    try {
      await speech.stop();
    } catch (_) {
      cancel();
      if (mounted) setState(() => error = 'voiceUnavailable');
    }
  }

  Future<void> load() async {
    try {
      final value = await speech.state();
      if (mounted) {
        setState(() {
          state = value;
          deviceOnly = value['onDevice'] == true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => state = {'available': false, 'onDevice': false});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.paused ||
        value == AppLifecycleState.hidden ||
        value == AppLifecycleState.detached) {
      cancel();
    }
  }

  void cancel() {
    generation++;
    unawaited(speech.cancel());
    if (speaking) unawaited(SpeechOutput.stop());
    if (mounted) {
      setState(() {
        conversation = false;
        conversationPaused = false;
        speaking = false;
        listening = false;
        partial = '';
        status = '';
      });
    }
  }

  Future<bool> confirmCapture({required bool handsFree}) async {
    if (!canListen || controlsBusy || !screenReady) return false;
    if (deviceOnly) return true;
    final attempt = generation;
    setState(() => authorizing = true);
    try {
      final privacy = context.tr('voiceSystemPrivacy');
      final prompt = handsFree
          ? '${context.tr('voiceConversationHint')}\n\n$privacy'
          : privacy;
      return await consent(context, prompt) &&
          screenReady &&
          attempt == generation;
    } finally {
      if (mounted) setState(() => authorizing = false);
    }
  }

  Future<void> listen() async {
    if (!await confirmCapture(handsFree: false) ||
        !screenReady ||
        controlsBusy) {
      return;
    }
    await capture(++generation);
  }

  Future<String?> listenForFollowUp(int attempt) async {
    var expired = false;
    final deadline = Timer(const Duration(seconds: 15), () {
      expired = true;
      if (mounted && attempt == generation) unawaited(speech.cancel());
    });
    try {
      for (var retry = 0; retry < 2; retry++) {
        // Give the recognizer and speaker time to release the previous turn.
        await Future<void>.delayed(Duration(milliseconds: 700 + retry * 300));
        if (!screenReady || attempt != generation) return null;
        if (expired) break;
        final opening = Stopwatch()..start();
        try {
          final result = await speech.listen(
            language: language,
            onDevice: deviceOnly,
            followUp: true,
          );
          if (expired) break;
          return result;
        } on PlatformException catch (e) {
          if (expired) break;
          // Recover a failed startup once. A miss after readiness is the end
          // of this listening turn, so background sounds cannot reopen it.
          if (retry != 0 ||
              opening.elapsed >= const Duration(seconds: 2) ||
              status.isNotEmpty ||
              partial.isNotEmpty ||
              !const {'no_match', 'no_speech', 'busy'}.contains(e.code)) {
            rethrow;
          }
        }
        if (!screenReady || attempt != generation) return null;
      }
      throw PlatformException(code: 'timeout');
    } finally {
      deadline.cancel();
    }
  }

  Future<String?> capture(int attempt, {bool followUp = false}) async {
    setState(() {
      listening = true;
      partial = '';
      status = '';
      error = '';
      command = null;
    });
    try {
      final result = followUp
          ? await listenForFollowUp(attempt)
          : await speech.listen(language: language, onDevice: deviceOnly);
      if (!mounted || attempt != generation) return null;
      if (result != null && result.trim().isNotEmpty) {
        setState(() => text.text = result);
        return result;
      }
      if (conversation) setState(() => conversationPaused = true);
    } on PlatformException catch (e) {
      if (mounted && attempt == generation && e.code != 'cancelled') {
        setState(() {
          if (conversation &&
              const {'no_match', 'no_speech', 'timeout'}.contains(e.code)) {
            conversationPaused = true;
            return;
          }
          error = switch (e.code) {
            'permission' => 'voicePermission',
            'language' => 'voiceLanguageUnavailable',
            'network' => 'voiceNetwork',
            'no_match' || 'no_speech' || 'timeout' => 'voiceNoSpeech',
            _ => 'voiceUnavailable',
          };
        });
      }
    } catch (_) {
      if (mounted && attempt == generation) {
        setState(() => error = 'voiceUnavailable');
      }
    } finally {
      if (mounted && attempt == generation) {
        setState(() {
          listening = false;
          partial = '';
          status = '';
        });
      }
    }
    return null;
  }

  Future<void> startConversation() async {
    if (!await confirmCapture(handsFree: true) ||
        !screenReady ||
        controlsBusy) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      conversation = true;
      answer = null;
      outputError = null;
    });
    await runConversation();
  }

  Future<void> resumeConversation() async {
    if (!conversationPaused || !screenReady || controlsBusy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => conversationPaused = false);
    await runConversation(followUp: true);
  }

  Future<void> runConversation({bool followUp = false}) async {
    final attempt = ++generation;
    try {
      while (screenReady && attempt == generation) {
        final result = await capture(attempt, followUp: followUp);
        if (!mounted ||
            result == null ||
            !screenReady ||
            attempt != generation) {
          break;
        }
        final question = VoiceCommand.parse(result);
        if (!question.isConversationQuestion) {
          setState(() {
            command = question;
            conversationPaused = question.action == VoiceAction.unknown;
            if (!conversationPaused) {
              answer = null;
              outputError = null;
            }
          });
          break;
        }
        final reply = await actions.personalAnswer(context, question, language);
        if (reply == null || !screenReady || attempt != generation) break;
        setState(() {
          answer = reply;
          outputError = null;
          speaking = true;
        });
        try {
          await SpeechOutput.speak(reply.excerpts.join('\n\n'), language);
        } on PlatformException catch (e) {
          if (!mounted || attempt != generation || e.code == 'cancelled') break;
          setState(
            () => outputError = e.code == 'language'
                ? 'vaNoVoice'
                : 'vaUnavailable',
          );
        } catch (_) {
          if (!mounted || attempt != generation) break;
          setState(() => outputError = 'vaUnavailable');
        }
        if (!screenReady || attempt != generation) break;
        setState(() => speaking = false);
        followUp = true;
      }
    } catch (_) {
      if (mounted && attempt == generation && screenReady) {
        setState(() => error = 'voiceUnavailable');
      }
    } finally {
      if (mounted && attempt == generation) {
        setState(() {
          conversation = conversationPaused;
          speaking = false;
        });
      }
    }
  }

  Future<void> execute() async {
    final value = command;
    if (value == null || value.action == VoiceAction.unknown || acting) return;
    if (conversation) cancel();
    setState(() => acting = true);
    try {
      await actions.execute(context, value, language: language);
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    SpeechBridge.channel.setMethodCallHandler(null);
    unawaited(speech.cancel());
    if (speaking) unawaited(SpeechOutput.stop());
    actions.access.removeListener(accessChanged);
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(c.tr('voiceTitle'))),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(c.tr('voicePurpose')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('voice-language'),
            initialValue: language,
            isExpanded: true,
            decoration: InputDecoration(labelText: c.tr('voiceLanguage')),
            items: [
              for (final item in {
                'uz-UZ': 'O‘zbekcha',
                'ru-RU': 'Русский',
                'en-US': 'English',
              }.entries)
                DropdownMenuItem(value: item.key, child: Text(item.value)),
            ],
            onChanged: controlsBusy || conversation
                ? null
                : (v) => setState(() => language = v!),
          ),
          if (state?['onDevice'] == true)
            SwitchListTile(
              key: const Key('voice-device-only'),
              title: Text(c.tr('voiceDeviceOnly')),
              subtitle: Text(c.tr('voiceDeviceLimit')),
              value: deviceOnly,
              onChanged: controlsBusy || conversation
                  ? null
                  : (v) => setState(() => deviceOnly = v),
            ),
          if (state != null &&
              state?['available'] != true &&
              state?['onDevice'] != true)
            Text(c.tr('voiceUnavailable')),
          Text(c.tr(deviceOnly ? 'voiceDeviceLimit' : 'voiceSystemPrivacy')),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!conversation)
                FilledButton.icon(
                  key: const Key('voice-listen'),
                  onPressed: !canListen
                      ? null
                      : listening
                      ? stop
                      : listen,
                  icon: Icon(listening ? Icons.stop : Icons.mic_none),
                  label: Text(c.tr(listening ? 'voiceStop' : 'voiceSpeak')),
                ),
              if (conversationPaused)
                FilledButton.icon(
                  key: const Key('voice-resume-conversation'),
                  onPressed: resumeConversation,
                  icon: const Icon(Icons.mic_none),
                  label: Text(c.tr('voiceConversationResume')),
                ),
              FilledButton.tonalIcon(
                key: const Key('voice-conversation'),
                onPressed: conversation
                    ? cancel
                    : canListen && !controlsBusy
                    ? startConversation
                    : null,
                icon: Icon(
                  conversation
                      ? Icons.stop_circle_outlined
                      : Icons.record_voice_over_outlined,
                ),
                label: Text(
                  c.tr(
                    conversation
                        ? 'voiceConversationStop'
                        : 'voiceConversationStart',
                  ),
                ),
              ),
              if (listening && !conversation)
                OutlinedButton(
                  key: const Key('voice-cancel-listen'),
                  onPressed: cancel,
                  child: Text(c.tr('cancel')),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.tr('voiceConversationHint')),
          if (conversationPaused)
            Semantics(
              liveRegion: true,
              child: Text(c.tr('voiceConversationPaused')),
            ),
          if (listening)
            Semantics(
              liveRegion: true,
              child: Text(
                c.tr(switch (status) {
                  'processing' => 'voiceProcessing',
                  'ready' || 'listening' => 'voiceListening',
                  _ => 'voiceMicPreparing',
                }),
              ),
            ),
          if (speaking)
            Semantics(
              liveRegion: true,
              child: Text(c.tr('voiceConversationSpeaking')),
            ),
          if (partial.isNotEmpty) Text(partial),
          if (error == 'voicePermission')
            TextButton(
              key: const Key('voice-permission-settings'),
              onPressed: () =>
                  SpeechBridge.channel.invokeMethod<void>('settings'),
              child: Text(c.tr('voicePermissionSettings')),
            ),
          if (error.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: Text(
                c.tr(error),
                style: TextStyle(color: Theme.of(c).colorScheme.error),
              ),
            ),
          if (answer case final reply?)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(reply.title, style: Theme.of(c).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SelectableText(reply.excerpts.join('\n\n')),
                    if (outputError case final message?) ...[
                      const SizedBox(height: 8),
                      Text(c.tr(message)),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('voice-transcript'),
            controller: text,
            readOnly: controlsBusy,
            minLines: 2,
            maxLines: 6,
            maxLength: 4000,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(labelText: c.tr('voicePreview')),
            onChanged: (_) => setState(() => command = null),
          ),
          FilledButton(
            key: const Key('voice-review'),
            onPressed: controlsBusy
                ? null
                : () {
                    setState(() => command = VoiceCommand.parse(text.text));
                  },
            child: Text(c.tr('voiceReview')),
          ),
          if (command != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      c.tr('voiceAction${command!.action.name}'),
                      style: Theme.of(c).textTheme.titleMedium,
                    ),
                    if (command!.argument.isNotEmpty) Text(command!.argument),
                    Text(
                      c.tr(
                        command!.action == VoiceAction.unknown
                            ? 'voiceUnknown'
                            : 'voiceConfirmFlow',
                      ),
                    ),
                    if (command!.action != VoiceAction.unknown)
                      FilledButton(
                        key: const Key('voice-execute'),
                        onPressed: acting ? null : execute,
                        child: Text(c.tr('continue')),
                      ),
                    TextButton(
                      key: const Key('voice-cancel-command'),
                      onPressed: acting
                          ? null
                          : () => setState(() => command = null),
                      child: Text(c.tr('cancel')),
                    ),
                  ],
                ),
              ),
            ),
          ExpansionTile(
            key: const Key('voice-examples'),
            title: Text(c.tr('voiceExamples')),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(c.tr('voiceExamplesText')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
