import '../../core/app_lock.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import '../../core/settings.dart';
import 'voice_command.dart';
import 'voice_actions.dart';
import 'voice_read_command.dart';
import 'voice_screen_host.dart';
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
  StreamSubscription<MethodCall>? speechEvents;
  Map<String, dynamic>? state;
  VoiceCommand? command;
  VoiceAnswer? answer;
  List<String> recognitionChoices = const [];
  String language = AppSettings.instance.voiceLanguage;
  String partial = '', status = '', error = '';
  String? outputError;
  bool deviceOnly = true, listening = false, acting = false;
  bool conversation = false, speaking = false, authorizing = false;
  bool conversationPaused = false, awaitingSpokenConfirmation = false;
  bool navoiySampleAvailable = false, previewingNavoiy = false;
  bool get showNavoiyComparison => navoiySampleAvailable && language == 'uz-UZ';
  int generation = 0;
  bool get canListen =>
      !acting &&
      !speaking &&
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
      speaking ||
      authorizing ||
      (conversation && !conversationPaused);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    speechEvents = SpeechBridge.events.listen((call) {
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
    unawaited(loadNavoiySample());
  }

  Future<void> loadNavoiySample() async {
    final available = await SpeechOutput.hasNavoiySample();
    if (mounted && available) setState(() => navoiySampleAvailable = true);
  }

  void accessChanged() {
    if (actions.access.initialized && !actions.access.coreAllowed) cancel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locked = AppLockScope.isLocked(context);
    final visible = ModalRoute.isCurrentOf(context) != false;
    if ((listening || conversation || speaking) && (locked || !visible)) {
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
        final selected = language;
        final preferDevice = await speech.prefersDeviceRecognizer(selected);
        if (!mounted) return;
        setState(() {
          state = value;
          if (language == selected) {
            deviceOnly = value['onDevice'] == true && preferDevice;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => state = {'available': false, 'onDevice': false});
      }
    }
  }

  Future<void> selectLanguage(String? selected) async {
    if (selected == null || selected == language || controlsBusy) return;
    final settings = AppSettings.instance;
    final previous = language;
    final previousMode = deviceOnly;
    setState(() => authorizing = true);
    try {
      final preferDevice = await speech.prefersDeviceRecognizer(selected);
      if (!mounted) return;
      setState(() {
        language = settings.voiceLanguage = selected;
        deviceOnly = state?['onDevice'] == true && preferDevice;
      });
      await settings.save();
    } catch (_) {
      settings.voiceLanguage = previous;
      if (mounted) {
        setState(() {
          language = previous;
          deviceOnly = previousMode;
        });
        failure(context);
      }
    } finally {
      if (mounted) setState(() => authorizing = false);
    }
  }

  Future<void> setDeviceOnly(bool selected) async {
    setState(() => authorizing = true);
    try {
      await speech.setDeviceRecognizerPreference(language, selected);
      if (mounted) setState(() => deviceOnly = selected);
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => authorizing = false);
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
        awaitingSpokenConfirmation = false;
        speaking = false;
        previewingNavoiy = false;
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
    final result = await capture(++generation);
    if (result != null && screenReady) _readPreviousScreen(result);
  }

  Future<SpeechRecognition?> listenForFollowUp(int attempt) async {
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
          final result = await speech.recognize(
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
      recognitionChoices = const [];
    });
    try {
      final result = followUp
          ? await listenForFollowUp(attempt)
          : await speech.recognize(language: language, onDevice: deviceOnly);
      if (!mounted || attempt != generation) return null;
      if (result != null) {
        setState(() {
          text.text = result.text;
          recognitionChoices = result.alternatives.isEmpty
              ? const []
              : [result.text, ...result.alternatives];
        });
        return result.text;
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
        if (_readPreviousScreen(result)) return;
        final control = ConversationControl.parse(result);
        if (control == ConversationControl.stop) break;
        if (control == ConversationControl.pause) {
          setState(() => conversationPaused = true);
          break;
        }
        if (control == ConversationControl.repeat && answer != null) {
          if (!await playReply(answer!, attempt)) break;
          followUp = true;
          continue;
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
          if (question.action != VoiceAction.unknown) {
            await confirmSpokenCommand(attempt);
          }
          break;
        }
        if (!mounted) break;
        final reply = await actions.personalAnswer(context, question, language);
        if (reply == null || !screenReady || attempt != generation) break;
        if (!await playReply(reply, attempt)) break;
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

  Future<void> confirmSpokenCommand(int attempt) async {
    setState(() {
      awaitingSpokenConfirmation = true;
      listening = true;
      partial = '';
      status = '';
    });
    String? reply;
    try {
      reply = (await listenForFollowUp(attempt))?.text;
    } on PlatformException {
      // Keep the command preview usable after silence or a recognition error.
    } finally {
      if (mounted && attempt == generation) {
        setState(() {
          awaitingSpokenConfirmation = false;
          listening = false;
          partial = '';
          status = '';
        });
      }
    }
    if (!screenReady || attempt != generation || reply == null) return;
    switch (ConversationControl.parse(reply)) {
      case ConversationControl.confirm:
        await execute();
      case ConversationControl.cancel:
      case ConversationControl.stop:
        setState(() => command = null);
      default:
        break;
    }
  }

  Future<bool> playReply(VoiceAnswer reply, int attempt) async {
    setState(() {
      answer = reply;
      outputError = null;
      speaking = true;
    });
    try {
      await SpeechOutput.speak(reply.excerpts.join('\n\n'), language);
    } on PlatformException catch (e) {
      if (!mounted || attempt != generation || e.code == 'cancelled') {
        return false;
      }
      setState(
        () =>
            outputError = e.code == 'language' ? 'vaNoVoice' : 'vaUnavailable',
      );
    } catch (_) {
      if (!mounted || attempt != generation) return false;
      setState(() => outputError = 'vaUnavailable');
    } finally {
      if (mounted && attempt == generation) setState(() => speaking = false);
    }
    return screenReady && attempt == generation;
  }

  void reviewCommand() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_readPreviousScreen(text.text)) return;
    setState(() => command = VoiceCommand.parse(text.text));
  }

  bool _readPreviousScreen(String text) =>
      VoiceReadCommand.parse(text) == VoiceReadCommand.read &&
      VoiceScreenNavigator.of(context)?.readPreviousScreen() == true;

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

  Future<void> setScreenControls(bool enabled) async {
    final settings = AppSettings.instance;
    final previous = settings.voiceScreenControls;
    setState(() => settings.voiceScreenControls = enabled);
    try {
      await settings.save();
    } catch (_) {
      if (mounted) {
        setState(() => settings.voiceScreenControls = previous);
        failure(context);
      }
    }
  }

  Future<void> previewVoice({bool navoiy = false}) async {
    if (controlsBusy || conversation || !screenReady) return;
    if (navoiy && !showNavoiyComparison) return;
    final attempt = ++generation;
    setState(() {
      speaking = true;
      previewingNavoiy = navoiy;
      error = '';
    });
    try {
      if (navoiy) {
        await SpeechOutput.playNavoiySample();
      } else {
        final sample = switch (language) {
          'en-US' => 'Hello. I am your Bilga assistant.',
          'ru-RU' => 'Здравствуйте. Я ваш помощник Билга.',
          _ when showNavoiyComparison =>
            'Assalomu alaykum! Sizga qanday yordam bera olaman?',
          _ => 'Assalomu alaykum. Men Bilga yordamchisiman.',
        };
        await SpeechOutput.speak(sample, language);
      }
    } on PlatformException catch (e) {
      if (mounted && attempt == generation && e.code != 'cancelled') {
        setState(() => error = 'vaUnavailable');
      }
    } catch (_) {
      if (mounted && attempt == generation) {
        setState(() => error = 'vaUnavailable');
      }
    } finally {
      if (mounted && attempt == generation) {
        setState(() {
          speaking = false;
          previewingNavoiy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(speechEvents?.cancel());
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
            onChanged: controlsBusy || conversation || state == null
                ? null
                : selectLanguage,
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('voice-test-output'),
              onPressed: conversation || previewingNavoiy
                  ? null
                  : speaking
                  ? cancel
                  : controlsBusy
                  ? null
                  : previewVoice,
              icon: Icon(
                speaking && !previewingNavoiy
                    ? Icons.stop
                    : Icons.volume_up_outlined,
              ),
              label: Text(
                c.tr(
                  speaking && !previewingNavoiy
                      ? 'voiceStop'
                      : showNavoiyComparison
                      ? 'voiceCurrentSample'
                      : 'voiceTestOutput',
                ),
              ),
            ),
          ),
          if (showNavoiyComparison) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('voice-navoiy-sample'),
                onPressed: previewingNavoiy
                    ? cancel
                    : controlsBusy || conversation
                    ? null
                    : () => previewVoice(navoiy: true),
                icon: Icon(
                  previewingNavoiy ? Icons.stop : Icons.volume_up_outlined,
                ),
                label: Text(
                  c.tr(previewingNavoiy ? 'voiceStop' : 'voiceNavoiySample'),
                ),
              ),
            ),
            Text(
              c.tr('voiceNavoiySampleHint'),
              style: Theme.of(c).textTheme.bodySmall,
            ),
          ],
          if (state?['onDevice'] == true)
            SwitchListTile(
              key: const Key('voice-device-only'),
              title: Text(c.tr('voiceDeviceOnly')),
              subtitle: Text(c.tr('voiceDeviceLimit')),
              value: deviceOnly,
              onChanged: controlsBusy || conversation ? null : setDeviceOnly,
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
                    TextButton.icon(
                      onPressed: controlsBusy
                          ? null
                          : () async => playReply(reply, ++generation),
                      icon: const Icon(Icons.volume_up_outlined),
                      label: Text(c.tr('vaRepeat')),
                    ),
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
            onChanged: (_) => setState(() {
              command = null;
              recognitionChoices = const [];
            }),
          ),
          if (!controlsBusy && recognitionChoices.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final choice in recognitionChoices)
                  if (choice != text.text)
                    OutlinedButton(
                      onPressed: () => setState(() {
                        text.text = choice;
                        command = null;
                      }),
                      child: Text(
                        choice,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
            ),
          FilledButton(
            key: const Key('voice-review'),
            onPressed: controlsBusy ? null : reviewCommand,
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
                      c.tr(command!.action.label),
                      style: Theme.of(c).textTheme.titleMedium,
                    ),
                    if (command!.argument.isNotEmpty)
                      Text(
                        command!.action == VoiceAction.openSection ||
                                command!.action == VoiceAction.readSection
                            ? c.tr(
                                VoiceSection.values
                                    .byName(command!.argument)
                                    .label,
                              )
                            : command!.argument,
                      ),
                    Text(
                      c.tr(
                        command!.action == VoiceAction.unknown
                            ? 'voiceUnknown'
                            : 'voiceConfirmFlow',
                      ),
                    ),
                    if (awaitingSpokenConfirmation)
                      Text(c.tr('voiceScreenConfirm')),
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
          SwitchListTile(
            key: const Key('voice-screen-enable'),
            value: AppSettings.instance.voiceScreenControls,
            title: Text(c.tr('voiceScreenTitle')),
            onChanged: controlsBusy || conversation ? null : setScreenControls,
          ),
        ],
      ),
    ),
  );
}
