import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/strings.dart';

/// Technical exception details (including private paths/URIs) stay out of UI.
String readingError(BuildContext context, Object error) {
  if (error is PdfPasswordException) return context.tr('rErrorProtected');
  if (error is PdfException) return context.tr('rErrorCorrupt');
  final code = error is FormatException ? error.message : '';
  final key = switch (code) {
    'book_changed' => 'rErrorChanged',
    'book_drm' || 'book_encrypted' => 'rErrorProtected',
    'book_unsupported' => 'rErrorUnsupported',
    'book_encoding' => 'rErrorEncoding',
    'book_large' || 'book_large_text' || 'book_archive_large' => 'rErrorLarge',
    'book_empty' => 'rErrorEmpty',
    _ => error is FormatException ? 'rErrorCorrupt' : 'rErrorUnavailable',
  };
  return context.tr(key);
}
