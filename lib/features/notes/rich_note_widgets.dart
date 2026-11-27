import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:url_launcher/url_launcher.dart';

import '../../core/dialogs.dart';
import '../../core/strings.dart';
import 'rich_note_codec.dart';

/// Use Quill's translated selection UI where supported, with a safe fallback
/// for Bilga locales absent from the package. Bilga's toolbar uses our catalogs.
class _QuillDelegate
    extends LocalizationsDelegate<quill.FlutterQuillLocalizations> {
  const _QuillDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<quill.FlutterQuillLocalizations> load(Locale locale) =>
      quill.FlutterQuillLocalizations.delegate.load(
        quill.FlutterQuillLocalizations.delegate.isSupported(locale)
            ? locale
            : const Locale('en'),
      );
  @override
  bool shouldReload(_QuillDelegate old) => false;
}

Widget noteQuillLocalizations(BuildContext context, Widget child) =>
    Localizations.override(
      context: context,
      delegates: const [_QuillDelegate()],
      child: child,
    );

Future<void> launchNoteLink(BuildContext context, String value) async {
  if (!RichNoteCodec.safeLink(value)) {
    showError(context, 'richInvalidLink');
    return;
  }
  if (!await confirm(context, context.tr('xExternal')) || !context.mounted) {
    return;
  }
  try {
    if (!await launchUrl(
          Uri.parse(value),
          mode: LaunchMode.externalApplication,
        ) &&
        context.mounted) {
      showError(context);
    }
  } catch (_) {
    if (context.mounted) showError(context);
  }
}

class RichNoteToolbar extends StatelessWidget {
  final quill.QuillController controller;
  final FocusNode focusNode;
  final bool enabled;
  const RichNoteToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    this.enabled = true,
  });

  void format(quill.Attribute attribute) {
    final selected = controller
        .getSelectionStyle()
        .attributes[attribute.key]
        ?.value;
    controller.formatSelection(
      selected == attribute.value
          ? quill.Attribute.clone(attribute, null)
          : attribute,
    );
    focusNode.requestFocus();
  }

  Future<void> link(BuildContext c) async {
    final selection = controller.selection;
    final current =
        controller.getSelectionStyle().attributes['link']?.value as String? ??
        '';
    final value = await askText(
      c,
      c.tr('richLink'),
      initial: current,
      allowEmpty: true,
      maxLength: 2048,
    );
    if (value == null || !c.mounted || !enabled) return;
    if (value.isNotEmpty && !RichNoteCodec.safeLink(value)) {
      showError(c, 'richInvalidLink');
      return;
    }
    if (selection.isCollapsed && value.isNotEmpty) {
      controller.replaceText(
        selection.start,
        0,
        value,
        TextSelection(
          baseOffset: selection.start,
          extentOffset: selection.start + value.length,
        ),
      );
    } else {
      controller.updateSelection(selection, quill.ChangeSource.local);
    }
    controller.formatSelection(
      quill.LinkAttribute(value.isEmpty ? null : value),
    );
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (c, _) {
      final style = controller.getSelectionStyle().attributes;
      Widget button(
        String key,
        IconData icon,
        VoidCallback action, {
        bool active = false,
        bool available = true,
      }) => IconButton(
        tooltip: c.tr(key),
        isSelected: active,
        onPressed: enabled && available ? action : null,
        icon: Icon(icon),
      );
      return Material(
        color: Theme.of(c).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              button(
                'undo',
                Icons.undo,
                controller.undo,
                available: controller.hasUndo,
              ),
              button(
                'redo',
                Icons.redo,
                controller.redo,
                available: controller.hasRedo,
              ),
              for (final (key, icon, attr) in [
                ('richBold', Icons.format_bold, quill.Attribute.bold),
                ('richItalic', Icons.format_italic, quill.Attribute.italic),
                (
                  'richUnderline',
                  Icons.format_underlined,
                  quill.Attribute.underline,
                ),
                (
                  'richStrike',
                  Icons.strikethrough_s,
                  quill.Attribute.strikeThrough,
                ),
                ('richBullets', Icons.format_list_bulleted, quill.Attribute.ul),
                ('richNumbers', Icons.format_list_numbered, quill.Attribute.ol),
                ('richChecklist', Icons.checklist, quill.Attribute.unchecked),
              ])
                button(
                  key,
                  icon,
                  () => format(attr),
                  active: style[attr.key]?.value == attr.value,
                ),
              PopupMenuButton<int>(
                tooltip: c.tr('richHeading'),
                enabled: enabled,
                icon: const Icon(Icons.title),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 0, child: Text(c.tr('richParagraph'))),
                  for (var level = 1; level <= 3; level++)
                    PopupMenuItem(
                      value: level,
                      child: Text(
                        '${c.tr('richHeading')} ${MaterialLocalizations.of(c).formatDecimal(level)}',
                      ),
                    ),
                ],
                onSelected: (level) {
                  controller.formatSelection(
                    quill.HeaderAttribute(level: level == 0 ? null : level),
                  );
                  focusNode.requestFocus();
                },
              ),
              button(
                'richLink',
                Icons.link,
                () => link(c),
                active: style['link'] != null,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class RichNoteReader extends StatefulWidget {
  final String body;
  final String? richBody;
  const RichNoteReader({super.key, required this.body, this.richBody});
  @override
  State<RichNoteReader> createState() => _RichNoteReaderState();
}

class _RichNoteReaderState extends State<RichNoteReader> {
  quill.QuillController? controller;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    if (widget.richBody == null) return;
    try {
      controller = quill.QuillController(
        document: quill.Document.fromJson(
          RichNoteCodec.decode(widget.richBody!, expectedBody: widget.body),
        ),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } on FormatException {
      /* Preserve readable original text for unsupported formatting. */
    }
  }

  @override
  void didUpdateWidget(RichNoteReader old) {
    super.didUpdateWidget(old);
    if (old.body != widget.body || old.richBody != widget.richBody) {
      controller?.dispose();
      controller = null;
      load();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => controller == null
      ? SelectableText(widget.body)
      : noteQuillLocalizations(
          context,
          quill.QuillEditor.basic(
            controller: controller!,
            config: quill.QuillEditorConfig(
              scrollable: false,
              showCursor: false,
              checkBoxReadOnly: true,
              onLaunchUrl: (value) => launchNoteLink(context, value),
            ),
          ),
        );
}
