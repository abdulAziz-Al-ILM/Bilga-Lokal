import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/diagnostics.dart';
import '../../core/app_lock.dart';
import '../../core/editor_form.dart';
import '../../core/settings.dart';
import '../../core/strings.dart';
import 'speech_bridge.dart';
import 'voice_command.dart';
import 'voice_read_command.dart';
import 'voice_screen_command.dart';

class VoiceScreenNavigator extends NavigatorObserver {
  final current = ValueNotifier<Route<dynamic>?>(null);
  static const assistantRoute = '/voice-assistant';
  static const readSectionRoute = '/voice-read-section';
  final _readers = <Route<dynamic>, FutureOr<String> Function()>{};
  final _readSectionStarted = Expando<bool>();
  Route<dynamic>? _assistant;
  Route<dynamic>? _assistantOrigin;
  ({Route<dynamic> origin, Route<dynamic> assistant})? _readOnReturn;

  static VoiceScreenNavigator? of(BuildContext context) =>
      Navigator.maybeOf(context)?.widget.observers
          .whereType<VoiceScreenNavigator>()
          .firstOrNull;

  bool readPreviousScreen() {
    final origin = _assistantOrigin;
    final nav = navigator;
    final assistant = current.value;
    if (assistant == null ||
        assistant.settings.name != assistantRoute ||
        origin == null ||
        !origin.isActive ||
        nav == null) {
      return false;
    }
    _readOnReturn = (origin: origin, assistant: assistant);
    nav.pop();
    return true;
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (topRoute.settings.name == assistantRoute && topRoute != _assistant) {
      _assistant = topRoute;
      _assistantOrigin = previousTopRoute;
    }
    current.value = topRoute;
  }
}

/// Supplies the full text of a document whose painted viewport may expose only
/// an excerpt to accessibility. The callback is evaluated on an explicit read.
class VoiceReadRegion extends StatefulWidget {
  const VoiceReadRegion({super.key, required this.read, required this.child});

  final FutureOr<String> Function() read;
  final Widget child;

  @override
  State<VoiceReadRegion> createState() => _VoiceReadRegionState();
}

class _VoiceReadRegionState extends State<VoiceReadRegion> {
  VoiceScreenNavigator? _observer;
  Route<dynamic>? _route;
  FutureOr<String> _read() => widget.read();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unregister();
    _observer = VoiceScreenNavigator.of(context);
    _route = ModalRoute.of(context);
    if (_route case final route?) _observer?._readers[route] = _read;
  }

  void _unregister() {
    if (_observer?._readers[_route] == _read) {
      _observer?._readers.remove(_route);
    }
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class VoiceScreenHost extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoiceScreenNavigator routes;
  final SpeechBridge? speech;

  const VoiceScreenHost({
    super.key,
    required this.child,
    required this.enabled,
    required this.routes,
    this.speech,
  });

  @override
  State<VoiceScreenHost> createState() => _VoiceScreenHostState();
}

typedef _Target = ({int id, String label, String tooltip, String value});

class _VoiceScreenHostState extends State<VoiceScreenHost>
    with WidgetsBindingObserver {
  static const _scope = 'bilga.current-screen';
  late final _speech = widget.speech ?? SpeechBridge();
  final _input = TextEditingController();
  final _commandFocus = FocusNode();
  SemanticsHandle? _handle;
  OverlayEntry? _panelEntry;
  Route<dynamic>? _openedOn;
  List<_Target> _choices = [];
  VoiceScreenCommand? _request;
  _Target? _pending;
  String? _message;
  String? _submittedText;
  String _status = '';
  StreamSubscription<MethodCall>? _speechEvents;
  bool _working = false, _listening = false, _local = true, _consented = false;
  Map<String, dynamic>? _availability;
  int _generation = 0;
  int _readGeneration = 0, _readIndex = 0;
  bool _reading = false, _loadingRead = false;
  List<String> _readingParts = [], _recognitionChoices = [];
  String _readingLanguage = 'uz-UZ';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.routes.current.addListener(_routeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppLockScope.isLocked(context) && _handle != null) _close();
  }

  @override
  void didUpdateWidget(VoiceScreenHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled && _handle != null) _close();
  }

  bool get _open => _handle != null;
  bool get _screenCurrent =>
      mounted &&
      _open &&
      !AppLockScope.isLocked(context) &&
      (_openedOn?.isCurrent ?? false) &&
      _openedOn == widget.routes.current.value;

  void _routeChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_open && !_screenCurrent && !_working) _close();
      if (widget.routes._readOnReturn case final request?
          when request.origin == widget.routes.current.value) {
        widget.routes._readOnReturn = null;
        unawaited(_readAfterAssistant(request.origin, request.assistant));
      }
      final route = widget.routes.current.value;
      if (route is ModalRoute<dynamic> &&
          route.settings.name == VoiceScreenNavigator.readSectionRoute &&
          widget.routes._readSectionStarted[route] != true) {
        widget.routes._readSectionStarted[route] = true;
        unawaited(_readAfterOpening(route));
      }
      setState(() {});
    });
  }

  Future<void> _readAfterOpening(ModalRoute<dynamic> route) async {
    final animation = route.animation;
    if (animation != null && !animation.isCompleted) {
      final opened = Completer<void>();
      void onStatus(AnimationStatus status) {
        if (status == AnimationStatus.completed && !opened.isCompleted) {
          opened.complete();
        }
      }

      animation.addStatusListener(onStatus);
      try {
        await Future.any([opened.future, route.popped]);
      } finally {
        animation.removeStatusListener(onStatus);
      }
    }
    if (mounted && route.isCurrent && !AppLockScope.isLocked(context)) {
      await _show(read: true);
    }
  }

  Future<void> _readAfterAssistant(
    Route<dynamic> origin,
    Route<dynamic> assistant,
  ) async {
    if (assistant is TransitionRoute<dynamic>) await assistant.completed;
    if (mounted && origin.isCurrent && !AppLockScope.isLocked(context)) {
      await _show(read: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_open) _close();
    }
  }

  void _reset() {
    _generation++;
    if (_listening) unawaited(_speech.cancel());
    _resetRead();
    _listening = _working = _consented = false;
    _handle?.dispose();
    _handle = null;
    final entry = _panelEntry;
    _panelEntry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
      entry.dispose();
    }
    _openedOn = null;
    _request = null;
    _pending = null;
    _choices = [];
    _availability = null;
    _message = null;
    _submittedText = null;
    unawaited(_speechEvents?.cancel());
    _speechEvents = null;
    _status = '';
    _recognitionChoices = [];
    _input.clear();
  }

  void _resetRead({bool pause = false}) {
    _readGeneration++;
    if (_reading) unawaited(SpeechOutput.stop());
    _reading = _loadingRead = false;
    if (!pause) {
      _readingParts = [];
      _readIndex = 0;
    }
  }

  void _close() => setState(_reset);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.routes.current.removeListener(_routeChanged);
    _reset();
    _input.dispose();
    _commandFocus.dispose();
    super.dispose();
  }

  SemanticsOwner? get _owner {
    final view = View.of(context);
    for (final renderView in RendererBinding.instance.renderViews) {
      if (renderView.flutterView == view) {
        return renderView.owner?.semanticsOwner;
      }
    }
    return null;
  }

  List<_Target> _targets(SemanticsAction action) {
    final targets = <_Target>[];
    void visit(SemanticsNode node, bool inScreen) {
      if (targets.length >= 80 || node.areUserActionsBlocked) return;
      final data = node.getSemanticsData();
      if (data.flagsCollection.isHidden) return;
      final inside = inScreen || data.identifier == _scope;
      final editable =
          action == SemanticsAction.setText &&
          data.flagsCollection.isTextField &&
          !data.flagsCollection.isReadOnly &&
          !data.flagsCollection.isObscured &&
          data.hasAction(SemanticsAction.focus);
      if (inside &&
          (data.hasAction(action) || editable) &&
          data.flagsCollection.isEnabled != Tristate.isFalse) {
        final label = (data.label.isEmpty && editable ? data.hint : data.label)
            .trim()
            .split('\n')
            .first;
        final tooltip = data.tooltip.trim();
        if (label.isNotEmpty ||
            tooltip.isNotEmpty ||
            action != SemanticsAction.tap) {
          targets.add((
            id: node.id,
            label: label,
            tooltip: tooltip,
            value: data.value,
          ));
        }
      }
      node.visitChildren((child) {
        visit(child, inside);
        return targets.length < 80;
      });
    }

    final root = _owner?.rootSemanticsNode;
    if (root != null && _screenCurrent) visit(root, false);
    return targets;
  }

  String _visibleText() {
    final lines = <String>[];
    void visit(SemanticsNode node, bool inScreen) {
      final data = node.getSemanticsData();
      final flags = data.flagsCollection;
      if (node.areUserActionsBlocked || flags.isHidden || flags.isObscured) {
        return;
      }
      final inside = inScreen || data.identifier == _scope;
      if (inside && node.rect.width > 0 && node.rect.height > 0) {
        final line = [
          data.label.trim(),
          data.value.trim(),
        ].where((value) => value.isNotEmpty).toSet().join('. ');
        if (line.isNotEmpty && line != lines.lastOrNull) lines.add(line);
      }
      node.visitChildren((child) {
        visit(child, inside);
        return true;
      });
    }

    final root = _owner?.rootSemanticsNode;
    if (_screenCurrent && root != null) visit(root, false);
    return lines.join('\n');
  }

  Future<void> _readScreen({String? visibleText}) async {
    if (!_screenCurrent || _reading || _loadingRead) return;
    final attempt = ++_readGeneration;
    setState(() {
      _loadingRead = true;
      _message = null;
      _request = null;
      _pending = null;
      _readingParts = [];
      _readIndex = 0;
    });
    try {
      final source = widget.routes._readers[_openedOn];
      final text = source == null
          ? visibleText ?? _visibleText()
          : await source();
      if (!_screenCurrent || attempt != _readGeneration) return;
      final language = AppSettings.instance.voiceLanguage;
      final parts = SpeechOutput.readingChunks(text, language);
      setState(() {
        _loadingRead = false;
        _readingParts = parts;
        _readingLanguage = language;
        _message = parts.isEmpty ? 'voiceReadEmpty' : null;
      });
      if (parts.isNotEmpty) await _playReading();
    } catch (_) {
      if (_screenCurrent && attempt == _readGeneration) {
        setState(() {
          _loadingRead = false;
          _message = 'vaUnavailable';
        });
      }
    }
  }

  Future<void> _playReading() async {
    if (!_screenCurrent || _reading || _readIndex >= _readingParts.length) {
      return;
    }
    final attempt = ++_readGeneration;
    setState(() {
      _reading = true;
      _message = null;
    });
    try {
      while (_screenCurrent &&
          attempt == _readGeneration &&
          _readIndex < _readingParts.length) {
        await SpeechOutput.speakReadingChunk(
          _readingParts[_readIndex],
          _readingLanguage,
        );
        if (!_screenCurrent || attempt != _readGeneration) return;
        setState(() => _readIndex++);
      }
    } on PlatformException catch (error) {
      if (_screenCurrent && attempt == _readGeneration) {
        setState(
          () => _message = error.code == 'language'
              ? 'vaNoVoice'
              : 'vaUnavailable',
        );
      }
    } catch (_) {
      if (_screenCurrent && attempt == _readGeneration) {
        setState(() => _message = 'vaUnavailable');
      }
    } finally {
      if (mounted && attempt == _readGeneration) {
        setState(() {
          _reading = false;
          if (_readIndex >= _readingParts.length) _resetRead();
        });
      }
    }
  }

  Future<void> _show({bool read = false}) async {
    final route = widget.routes.current.value;
    if (route == null || !route.isCurrent || _open) return;
    _openedOn = route;
    _handle = SemanticsBinding.instance.ensureSemantics();
    final attempt = _generation;
    // Capture the current viewport before the voice panel takes screen space.
    await WidgetsBinding.instance.endOfFrame;
    if (!_screenCurrent || attempt != _generation) return;
    final visible = read ? _visibleText() : null;
    setState(() => _choices = _targets(SemanticsAction.tap));
    if (read) unawaited(_readScreen(visibleText: visible));
    if (!widget.enabled) return;
    try {
      final available = await _speech.state();
      final settings = AppSettings.instance;
      final local =
          available['onDevice'] == true &&
          await _speech.prefersDeviceRecognizer(settings.voiceLanguage);
      if (_screenCurrent && attempt == _generation) {
        setState(() {
          _availability = available;
          _local = local;
        });
      }
    } catch (error) {
      // Users can continue with a typed command.
      logFailure('Could not check voice input availability', error);
    }
  }

  Future<void> _setDeviceOnly(bool value) async {
    final attempt = _generation;
    final settings = AppSettings.instance;
    setState(() => _working = true);
    try {
      await _speech.setDeviceRecognizerPreference(
        settings.voiceLanguage,
        value,
      );
      if (_screenCurrent && attempt == _generation) {
        setState(() => _local = value);
      }
    } catch (_) {
      if (_screenCurrent && attempt == _generation) {
        setState(() => _message = 'saveError');
      }
    } finally {
      if (mounted && attempt == _generation) {
        if (_screenCurrent) {
          setState(() => _working = false);
        } else {
          _close();
        }
      }
    }
  }

  String _name(_Target target) {
    if (target.label.isNotEmpty) return target.label;
    if (target.tooltip.isNotEmpty) return target.tooltip;
    return context.tr(
      _request?.action == SemanticsAction.setText
          ? 'voiceScreenField'
          : 'voiceScreenArea',
    );
  }

  void _submit(String text) {
    setState(() {
      _submittedText = text;
      _recognitionChoices = [];
    });
    _commandFocus.unfocus();
  }

  void _reviewAfterKeyboard() {
    final attempt = _generation;
    // Wait for the route's visible semantics to reflect the new viewport.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_screenCurrent || attempt != _generation) return;
      if (View.of(context).viewInsets.bottom > 0) return;
      final text = _submittedText;
      if (text == null) return;
      setState(() => _submittedText = null);
      if (text == _input.text) _review(text);
    });
  }

  void _review(String utterance) {
    if (!_screenCurrent) return;
    switch (VoiceReadCommand.parse(utterance)) {
      case VoiceReadCommand.read:
        unawaited(_readScreen());
        return;
      case VoiceReadCommand.pause:
        setState(() => _resetRead(pause: true));
        return;
      case VoiceReadCommand.resume:
        unawaited(_playReading());
        return;
      case VoiceReadCommand.stop:
        setState(_resetRead);
        return;
      case null:
        break;
    }
    if (_pending != null) {
      switch (ConversationControl.parse(utterance)) {
        case ConversationControl.confirm:
          unawaited(_execute());
          return;
        case ConversationControl.cancel:
        case ConversationControl.stop:
          _close();
          return;
        default:
          break;
      }
    }
    final request = VoiceScreenCommand.parse(utterance);
    if (request == null) return;
    final number = VoiceScreenCommand.option(request.target);
    if (number != null &&
        number > 0 &&
        number <= _choices.length &&
        request.action == SemanticsAction.tap) {
      setState(() {
        _request ??= request;
        _pending = _choices[number - 1];
        _message = null;
      });
      return;
    }
    final targets = _targets(request.action);
    final words = VoiceScreenCommand.terms(request.target);
    final exact = targets
        .where(
          (target) => [
            target.label,
            target.tooltip,
          ].any((label) => VoiceScreenCommand.words(label) == request.target),
        )
        .toList();
    final matches = request.target.isEmpty
        ? targets
        : exact.isNotEmpty
        ? exact
        : targets
              .where(
                (target) => [target.label, target.tooltip].any(
                  (label) => VoiceScreenCommand.terms(label).containsAll(words),
                ),
              )
              .toList();
    setState(() {
      _request = request;
      _choices = matches.isEmpty ? targets : matches;
      _pending = matches.length == 1 ? matches.single : null;
      _message = matches.isEmpty ? 'voiceScreenNoMatch' : null;
    });
  }

  Future<void> _listen() async {
    if (!_screenCurrent || _working || _submittedText != null) return;
    if (_reading) setState(() => _resetRead(pause: true));
    final attempt = _generation;
    final language = AppSettings.instance.voiceLanguage;
    setState(() => _working = true);
    try {
      if (!_local && !_consented) {
        final route = _openedOn;
        final promptContext = route is ModalRoute ? route.subtreeContext : null;
        if (promptContext == null ||
            !await consent(promptContext, context.tr('voiceSystemPrivacy')) ||
            !_screenCurrent ||
            attempt != _generation) {
          return;
        }
        _consented = true;
      }
      setState(() {
        _listening = true;
        _message = null;
        _status = '';
      });
      _speechEvents ??= SpeechBridge.events.listen((call) {
        if (_listening && mounted && call.method == 'status') {
          setState(() => _status = call.arguments as String? ?? '');
        }
      });
      final result = await _speech.recognize(
        language: language,
        onDevice: _local,
      );
      if (!_screenCurrent || attempt != _generation || result == null) return;
      final text = result.text;
      _input.text = text;
      setState(() => _recognitionChoices = result.alternatives);
      final wasConfirming = _pending != null && _confirmation(text);
      _review(text);
      if (_pending case final target? when !wasConfirming) {
        await _listenForConfirmation(language, attempt, target);
      }
    } catch (_) {
      if (_screenCurrent && attempt == _generation) {
        setState(() => _message = 'voiceNoSpeech');
      }
    } finally {
      if (mounted && attempt == _generation) {
        if (!_screenCurrent) {
          _close();
        } else {
          setState(() => _working = _listening = false);
        }
      }
    }
  }

  static bool _confirmation(String text) =>
      switch (ConversationControl.parse(text)) {
        ConversationControl.confirm ||
        ConversationControl.cancel ||
        ConversationControl.stop => true,
        _ => false,
      };

  Future<void> _listenForConfirmation(
    String language,
    int attempt,
    _Target target,
  ) async {
    setState(() => _status = '');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!_screenCurrent || attempt != _generation || _pending != target) return;
    try {
      final reply = await _speech.listen(
        language: language,
        onDevice: _local,
        followUp: true,
      );
      if (reply != null &&
          _screenCurrent &&
          attempt == _generation &&
          _pending == target &&
          _confirmation(reply)) {
        _review(reply);
      }
    } on PlatformException catch (error) {
      // Keep the preview available for manual confirmation.
      if (error.code != 'cancelled') {
        logFailure('Screen command voice confirmation failed', error);
      }
    }
  }

  Future<void> _execute() async {
    final request = _request;
    final target = _pending;
    if (request == null || target == null || !_screenCurrent) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!_screenCurrent || _pending != target) return;
    if (!_targets(request.action).contains(target)) {
      _staleTarget();
      return;
    }
    final owner = _owner;
    if (owner == null) return;
    if (request.action == SemanticsAction.setText) {
      setState(() => _working = true);
      owner.performAction(target.id, SemanticsAction.focus);
      await WidgetsBinding.instance.endOfFrame;
      if (!_screenCurrent || _pending != target) {
        if (mounted && _open) _close();
        return;
      }
      final field = owner.getSemanticsNode(target.id)?.getSemanticsData();
      if (field?.hasAction(SemanticsAction.setText) != true ||
          field?.flagsCollection.isObscured == true) {
        setState(() => _working = false);
        _staleTarget();
        return;
      }
    }
    owner.performAction(target.id, request.action, request.text);
    if (mounted) _close();
  }

  void _staleTarget() => setState(() {
    _pending = null;
    _choices = _targets(SemanticsAction.tap);
    _request = null;
    _message = 'voiceScreenChanged';
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !AppLockScope.isLocked(context);
    final insideAssistant =
        widget.routes.current.value?.settings.name ==
        VoiceScreenNavigator.assistantRoute;
    _panelEntry?.markNeedsBuild();
    return LayoutBuilder(
      builder: (context, constraints) {
        final safeBottom = MediaQuery.paddingOf(context).bottom
            .clamp(0.0, constraints.maxHeight);
        final keyboard = MediaQuery.viewInsetsOf(context).bottom
            .clamp(0.0, constraints.maxHeight - safeBottom);
        final available = constraints.maxHeight - safeBottom - keyboard;
        final panelHeight = (available * .40).clamp(
          available.clamp(0.0, 80.0),
          300.0,
        );
        if (_submittedText != null && keyboard == 0) _reviewAfterKeyboard();
        return Column(
          children: [
            Expanded(
              child: Semantics(
                identifier: _scope,
                container: true,
                child: MediaQuery.removeViewInsets(
                  context: context,
                  removeBottom: _open,
                  child: widget.child,
                ),
              ),
            ),
            if (enabled && !insideAssistant)
              Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: SafeArea(
                  top: false,
                  child: _open
                      ? Padding(
                          padding: EdgeInsets.only(bottom: keyboard),
                          child: SizedBox(
                            height: panelHeight,
                            child: Overlay(
                              initialEntries: [
                                _panelEntry ??= OverlayEntry(builder: _panel),
                              ],
                            ),
                          ),
                        )
                      : Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton.icon(
                              key: const Key('voice-read-open'),
                              icon: const Icon(Icons.volume_up_outlined),
                              label: Text(context.tr('voiceReadAloud')),
                              onPressed: () => _show(read: true),
                            ),
                            if (widget.enabled)
                              TextButton.icon(
                                key: const Key('voice-screen-open'),
                                icon: const Icon(Icons.mic_none),
                                label: Text(context.tr('voiceScreenTitle')),
                                onPressed: _show,
                              ),
                          ],
                        ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _panel(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .40,
    ),
    child: ListView(
      key: const Key('voice-screen-actions'),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        Row(
          children: [
            Expanded(child: Text(context.tr('voiceScreenTitle'))),
            if (widget.enabled && !_loadingRead && _readingParts.isEmpty)
              IconButton(
                tooltip: context.tr('voiceReadAloud'),
                icon: const Icon(Icons.volume_up_outlined),
                onPressed: _working ? null : () => _readScreen(),
              ),
            TextButton(onPressed: _close, child: Text(context.tr('cancel'))),
          ],
        ),
        if (!widget.enabled || _loadingRead || _readingParts.isNotEmpty)
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_loadingRead)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (_reading)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.pause),
                  onPressed: () => setState(() => _resetRead(pause: true)),
                  label: Text(context.tr('voiceReadPause')),
                )
              else if (_readingParts.isNotEmpty)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _working ? null : _playReading,
                  label: Text(context.tr('voiceReadResume')),
                )
              else if (!_loadingRead)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.volume_up_outlined),
                  label: Text(context.tr('voiceReadAloud')),
                  onPressed: _working ? null : () => _readScreen(),
                ),
              if (_readingParts.isNotEmpty || _loadingRead)
                TextButton.icon(
                  icon: const Icon(Icons.stop),
                  onPressed: () => setState(_resetRead),
                  label: Text(context.tr('voiceReadStop')),
                ),
            ],
          ),
        if (widget.enabled)
          TextField(
            controller: _input,
            focusNode: _commandFocus,
            key: const Key('voice-screen-input'),
            readOnly: _working,
            maxLines: 1,
            enableInteractiveSelection: false,
            enableIMEPersonalizedLearning: false,
            decoration: InputDecoration(
              hintText: context.tr('voiceScreenHint'),
            ),
            onSubmitted: _submit,
          ),
        if (widget.enabled)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const Key('voice-screen-speak'),
                onPressed:
                    _working ||
                        _submittedText != null ||
                        _availability?[_local ? 'onDevice' : 'available'] !=
                            true
                    ? null
                    : _listen,
                icon: const Icon(Icons.mic_none),
                label: Text(
                  context.tr(
                    !_listening
                        ? 'voiceSpeak'
                        : switch (_status) {
                            'ready' || 'listening' => 'voiceListening',
                            'processing' => 'voiceProcessing',
                            _ => 'voiceMicPreparing',
                          },
                  ),
                ),
              ),
              TextButton(
                onPressed: _working ? null : () => _submit(_input.text),
                child: Text(context.tr('voiceReview')),
              ),
              if (_availability?['onDevice'] == true)
                FilterChip(
                  label: Text(context.tr('voiceDeviceOnly')),
                  selected: _local,
                  onSelected: _working ? null : _setDeviceOnly,
                ),
            ],
          ),
        if (widget.enabled && _recognitionChoices.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              for (final alternative in _recognitionChoices)
                ActionChip(
                  label: Text(alternative),
                  onPressed: _working
                      ? null
                      : () {
                          _input.text = alternative;
                          if (_reading) setState(_resetRead);
                          _submit(alternative);
                        },
                ),
            ],
          ),
        if (_message case final message?) Text(context.tr(message)),
        if (_pending case final choice?) ...[
          Text(_name(choice), style: Theme.of(context).textTheme.titleMedium),
          if (_request?.text case final text?) Text(text),
          FilledButton(
            key: const Key('voice-screen-confirm'),
            onPressed: (_working && !_listening) || _submittedText != null
                ? null
                : _execute,
            child: Text(context.tr('voiceScreenConfirm')),
          ),
        ] else if (widget.enabled && !_reading && !_loadingRead)
          for (var i = 0; i < _choices.length; i++)
            ListTile(
              dense: true,
              title: Text('${i + 1}. ${_name(_choices[i])}'),
              onTap: _working || _submittedText != null
                  ? null
                  : () => setState(() {
                      _pending = _choices[i];
                      _request ??= const VoiceScreenCommand(
                        SemanticsAction.tap,
                        '',
                      );
                    }),
            ),
      ],
    ),
  );
}
