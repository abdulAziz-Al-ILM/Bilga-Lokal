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
  String language = 'uz-UZ', partial = '', status = '', error = '';
  bool deviceOnly = true, listening = false, acting = false;
  int generation = 0;
  bool get canListen =>
      !acting &&
      state != null &&
      (deviceOnly ? state!['onDevice'] == true : state!['available'] == true);
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
    if (listening &&
        (AppLockScope.isLocked(context) ||
            ModalRoute.isCurrentOf(context) == false)) {
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
        value == AppLifecycleState.detached) {
      cancel();
    }
  }

  void cancel() {
    generation++;
    unawaited(speech.cancel());
    if (mounted) {
      setState(() {
        listening = false;
        partial = '';
        status = '';
      });
    }
  }

  Future<void> listen() async {
    if (listening || acting) return;
    if (!deviceOnly &&
        !await consent(context, context.tr('voiceSystemPrivacy'))) {
      return;
    }
    if (!mounted) return;
    final attempt = ++generation;
    setState(() {
      listening = true;
      partial = '';
      status = '';
      error = '';
      command = null;
    });
    try {
      final result = await speech.listen(
        language: language,
        onDevice: deviceOnly,
      );
      if (!mounted || attempt != generation) return;
      if (result != null && result.trim().isNotEmpty) {
        setState(() => text.text = result);
      }
    } on PlatformException catch (e) {
      if (mounted && attempt == generation && e.code != 'cancelled') {
        setState(
          () => error = switch (e.code) {
            'permission' => 'voicePermission',
            'language' => 'voiceLanguageUnavailable',
            'network' => 'voiceNetwork',
            'no_match' || 'no_speech' => 'voiceNoSpeech',
            _ => 'voiceUnavailable',
          },
        );
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
  }

  Future<void> execute() async {
    final value = command;
    if (value == null || value.action == VoiceAction.unknown || acting) return;
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
            onChanged: listening || acting
                ? null
                : (v) => setState(() => language = v!),
          ),
          if (state?['onDevice'] == true)
            SwitchListTile(
              key: const Key('voice-device-only'),
              title: Text(c.tr('voiceDeviceOnly')),
              subtitle: Text(c.tr('voiceDeviceLimit')),
              value: deviceOnly,
              onChanged: listening || acting
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
              if (listening)
                OutlinedButton(
                  key: const Key('voice-cancel-listen'),
                  onPressed: cancel,
                  child: Text(c.tr('cancel')),
                ),
            ],
          ),
          if (listening)
            Semantics(
              liveRegion: true,
              child: Text(
                c.tr(
                  status == 'processing' ? 'voiceProcessing' : 'voiceListening',
                ),
              ),
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
          const SizedBox(height: 16),
          TextField(
            key: const Key('voice-transcript'),
            controller: text,
            readOnly: listening || acting,
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
            onPressed: listening || acting
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
