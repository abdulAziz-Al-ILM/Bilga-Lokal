import 'package:flutter/material.dart';

import '../../../core/strings.dart';

class ReaderAppearanceSheet extends StatefulWidget {
  const ReaderAppearanceSheet({
    super.key,
    required this.isPdf,
    required this.settings,
    required this.paged,
    required this.onChange,
  });

  final bool isPdf, paged;
  final Map<String, dynamic> settings;
  final void Function(String, Object) onChange;

  @override
  State<ReaderAppearanceSheet> createState() => _ReaderAppearanceSheetState();
}

class _ReaderAppearanceSheetState extends State<ReaderAppearanceSheet> {
  late bool paged = widget.paged;

  void change(String key, Object value) {
    setState(() {
      if (key == 'paged') paged = value as bool;
      widget.onChange(key, value);
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isPdf) Text(context.tr('rPdfSettingsHint')),
          if (!widget.isPdf)
            for (final spec in const [
              ('font', 12.0, 40.0, 'rFontSize'),
              ('line', 1.0, 2.5, 'rLineSpacing'),
              ('margin', 8.0, 64.0, 'rMargins'),
            ]) ...[
              Text(context.tr(spec.$4)),
              Slider(
                value: (widget.settings[spec.$1] as num).toDouble(),
                min: spec.$2,
                max: spec.$3,
                onChanged: (value) => change(spec.$1, value),
              ),
            ],
          Wrap(
            spacing: 8,
            children: [
              for (final theme in ['light', 'dark', 'sepia'])
                ChoiceChip(
                  label: Text(context.tr('rTheme_$theme')),
                  selected: widget.settings['theme'] == theme,
                  onSelected: (_) => change('theme', theme),
                ),
            ],
          ),
          if (!widget.isPdf)
            Wrap(
              spacing: 8,
              children: [
                for (final family in ['sans', 'serif', 'mono'])
                  ChoiceChip(
                    label: Text(context.tr('rFont_$family')),
                    selected: widget.settings['family'] == family,
                    onSelected: (_) => change('family', family),
                  ),
              ],
            ),
          if (widget.isPdf)
            SwitchListTile(
              title: Text(context.tr('rPageByPage')),
              value: paged,
              onChanged: (value) => change('paged', value),
            ),
          Text(context.tr('rSessionExplanation')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('gFinish')),
          ),
        ],
      ),
    ),
  );
}
