import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/app_lock.dart';
import '../../core/editor_form.dart';
import '../../core/settings.dart';
import '../../core/strings.dart';
import 'speech_bridge.dart';
import 'voice_command.dart';
import 'voice_screen_command.dart';

class VoiceScreenNavigator extends NavigatorObserver {
  final current = ValueNotifier<Route<dynamic>?>(null);
  static const assistantRoute = '/voice-assistant';

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    current.value = topRoute;
  }
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
  SemanticsHandle? _handle;
  OverlayEntry? _panelEntry;
  Route<dynamic>? _openedOn;
  List<_Target> _choices = [];
  VoiceScreenCommand? _request;
  _Target? _pending;
  String? _message;
  String _status = '';
  StreamSubscription<MethodCall>? _speechEvents;
  bool _working = false, _listening = false, _local = true, _consented = false;
  Map<String, dynamic>? _availability;
  int _generation = 0;

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
    if (!widget.enabled && _handle != null) _close();
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
      setState(() {});
    });
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
    unawaited(_speechEvents?.cancel());
    _speechEvents = null;
    _status = '';
    _input.clear();
  }

  void _close() => setState(_reset);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.routes.current.removeListener(_routeChanged);
    _reset();
    _input.dispose();
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

  Future<void> _show() async {
    final route = widget.routes.current.value;
    if (route == null || !route.isCurrent || _open) return;
    setState(() {
      _openedOn = route;
      _handle = SemanticsBinding.instance.ensureSemantics();
    });
    final attempt = _generation;
    await WidgetsBinding.instance.endOfFrame;
    if (!_screenCurrent || attempt != _generation) return;
    setState(() => _choices = _targets(SemanticsAction.tap));
    try {
      final available = await _speech.state();
      final settings = AppSettings.instance;
      final local =
          available['onDevice'] == true &&
          await settings.prefersDeviceRecognizer(settings.voiceLanguage);
      if (_screenCurrent && attempt == _generation) {
        setState(() {
          _availability = available;
          _local = local;
        });
      }
    } catch (_) {
      // The same controls can be operated with a typed command.
    }
  }

  Future<void> _setDeviceOnly(bool value) async {
    final attempt = _generation;
    final settings = AppSettings.instance;
    setState(() => _working = true);
    try {
      await settings.setDeviceRecognizerPreference(
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

  void _review(String utterance) {
    if (!_screenCurrent) return;
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
    if (!_screenCurrent || _working) return;
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
      final text = await _speech.listen(language: language, onDevice: _local);
      if (!_screenCurrent || attempt != _generation || text == null) return;
      _input.text = text;
      _review(text);
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
    final enabled = widget.enabled && !AppLockScope.isLocked(context);
    final insideAssistant =
        widget.routes.current.value?.settings.name ==
        VoiceScreenNavigator.assistantRoute;
    _panelEntry?.markNeedsBuild();
    return Column(
      children: [
        Expanded(
          child: Semantics(
            identifier: _scope,
            container: true,
            child: widget.child,
          ),
        ),
        if (enabled && !insideAssistant)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: SafeArea(
              top: false,
              child: _open
                  ? Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: SizedBox(
                        height:
                            ((MediaQuery.sizeOf(context).height -
                                        MediaQuery.viewInsetsOf(context)
                                            .bottom) *
                                    .40)
                                .clamp(80.0, 300.0),
                        child: Overlay(
                          initialEntries: [
                            _panelEntry ??= OverlayEntry(builder: _panel),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: TextButton.icon(
                        key: const Key('voice-screen-open'),
                        icon: const Icon(Icons.mic_none),
                        label: Text(context.tr('voiceScreenTitle')),
                        onPressed: _show,
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _panel(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .40,
    ),
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        Row(
          children: [
            Expanded(child: Text(context.tr('voiceScreenTitle'))),
            TextButton(onPressed: _close, child: Text(context.tr('cancel'))),
          ],
        ),
        TextField(
          controller: _input,
          key: const Key('voice-screen-input'),
          readOnly: _working,
          maxLines: 1,
          enableInteractiveSelection: false,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(hintText: context.tr('voiceScreenHint')),
          onSubmitted: _review,
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed:
                  _working ||
                      _availability?[_local ? 'onDevice' : 'available'] != true
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
              onPressed: _working ? null : () => _review(_input.text),
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
        if (_message case final message?) Text(context.tr(message)),
        if (_pending case final choice?) ...[
          Text(_name(choice), style: Theme.of(context).textTheme.titleMedium),
          if (_request?.text case final text?) Text(text),
          FilledButton(
            key: const Key('voice-screen-confirm'),
            onPressed: _working ? null : _execute,
            child: Text(context.tr('voiceScreenConfirm')),
          ),
        ] else
          for (var i = 0; i < _choices.length; i++)
            ListTile(
              dense: true,
              title: Text('${i + 1}. ${_name(_choices[i])}'),
              onTap: _working
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
