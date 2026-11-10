import 'dart:convert';

/// Versioned text-only Quill delta. The separate plain body remains the source
/// for search, widgets and text exports; formatting never replaces that body.
class RichNoteCodec {
  static const maxBytes = 8 * 1024 * 1024;
  static const maxOperations = 100000;
  static const _attributes = {
    'bold',
    'italic',
    'underline',
    'strike',
    'code',
    'header',
    'list',
    'link',
    'blockquote',
    'code-block',
    'indent',
    'align',
    'direction',
    'color',
    'background',
    'size',
    'font',
    'script',
  };

  static bool safeLink(String text) {
    final uri = Uri.tryParse(text);
    return uri != null &&
        text.length <= 2048 &&
        !text.contains(RegExp(r'[\x00-\x20]')) &&
        (({'http', 'https'}.contains(uri.scheme) &&
                uri.host.isNotEmpty &&
                uri.userInfo.isEmpty) ||
            (uri.scheme == 'mailto' && uri.path.contains('@')));
  }

  static List<Map<String, dynamic>> decode(String raw, {String? expectedBody}) {
    if (raw.length > maxBytes || utf8.encode(raw).length > maxBytes) {
      throw const FormatException('rich_note_large');
    }
    final value = jsonDecode(raw);
    if (value is! Map ||
        value['version'] != 1 ||
        value['ops'] is! List ||
        value.keys.any((k) => k != 'version' && k != 'ops')) {
      throw const FormatException('rich_note_format');
    }
    final ops = value['ops'] as List;
    if (ops.isEmpty || ops.length > maxOperations) {
      throw const FormatException('rich_note_format');
    }
    final text = StringBuffer();
    final result = <Map<String, dynamic>>[];
    for (final op in ops) {
      if (op is! Map ||
          op['insert'] is! String ||
          (op['insert'] as String).isEmpty ||
          op.keys.any((k) => k != 'insert' && k != 'attributes')) {
        throw const FormatException('rich_note_operation');
      }
      final attributes = op['attributes'];
      if (attributes != null) {
        if (attributes is! Map ||
            attributes.keys.any((k) => !_attributes.contains(k))) {
          throw const FormatException('rich_note_attribute');
        }
        const blockAttributes = {
          'header',
          'list',
          'blockquote',
          'code-block',
          'indent',
          'align',
          'direction',
        };
        if (attributes.keys.any(blockAttributes.contains) &&
            (op['insert'] as String).replaceAll('\n', '').isNotEmpty) {
          throw const FormatException('rich_note_block');
        }
        for (final e in attributes.entries) {
          final k = e.key, v = e.value;
          final valid = switch (k) {
            'bold' ||
            'italic' ||
            'underline' ||
            'strike' ||
            'code' ||
            'blockquote' ||
            'code-block' => v is bool,
            'header' => v is int && v >= 1 && v <= 6,
            'indent' => v is int && v >= 0 && v <= 8,
            'list' => {'ordered', 'bullet', 'checked', 'unchecked'}.contains(v),
            'align' => {'left', 'center', 'right', 'justify'}.contains(v),
            'direction' => v == 'rtl' || v == 'ltr',
            'link' => v is String && safeLink(v),
            'script' => v == 'sub' || v == 'super',
            'color' || 'background' =>
              v is String &&
                  RegExp(r'^#[a-fA-F0-9]{6}(?:[a-fA-F0-9]{2})?$').hasMatch(v),
            'font' || 'size' =>
              v is String &&
                  v.length <= 100 &&
                  !v.contains(RegExp(r'[\x00-\x1f]')),
            _ => false,
          };
          if (!valid) throw const FormatException('rich_note_attribute');
        }
      }
      text.write(op['insert']);
      result.add(Map<String, dynamic>.from(op));
    }
    final projection = text.toString();
    if (!projection.endsWith('\n') ||
        (expectedBody != null &&
            projection.substring(0, projection.length - 1) != expectedBody)) {
      throw const FormatException('rich_note_projection');
    }
    return result;
  }

  static String encode(List<dynamic> ops, {required String body}) {
    final raw = jsonEncode({'version': 1, 'ops': ops});
    decode(raw, expectedBody: body);
    return raw;
  }

  static void validate(String? raw, String body) {
    if (raw != null) decode(raw, expectedBody: body);
  }
}
