import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'book_vault.dart';

class BookCover extends StatefulWidget {
  final String? blob;
  final BookVault vault;
  final double width, height;
  const BookCover({
    super.key,
    required this.blob,
    required this.vault,
    this.width = 60,
    this.height = 84,
  });
  @override
  State<BookCover> createState() => _CoverState();
}

class _CoverState extends State<BookCover> {
  late Future<Uint8List?> bytes = load();
  Future<Uint8List?> load() async {
    if (widget.blob == null) return null;
    final out = BytesBuilder();
    await for (final b in widget.vault.read(widget.blob!)) {
      if (out.length + b.length > 4 * 1024 * 1024) {
        throw const FormatException('cover_size');
      }
      out.add(b);
    }
    return out.takeBytes();
  }

  @override
  void didUpdateWidget(BookCover old) {
    super.didUpdateWidget(old);
    if (old.blob != widget.blob || old.vault != widget.vault) bytes = load();
  }

  Widget fallback(BuildContext c) => ColoredBox(
    color: Theme.of(c).colorScheme.secondaryContainer,
    child: Center(
      child: Icon(
        Icons.menu_book_outlined,
        size: widget.width * .6,
        color: Theme.of(c).colorScheme.onSecondaryContainer,
      ),
    ),
  );
  @override
  Widget build(BuildContext c) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      width: widget.width,
      height: widget.height,
      child: FutureBuilder(
        future: bytes,
        builder: (c, s) => s.data == null
            ? fallback(c)
            : Image.memory(
                s.data!,
                cacheWidth: (widget.width * MediaQuery.devicePixelRatioOf(c))
                    .round()
                    .clamp(64, 800),
                fit: BoxFit.cover,
                errorBuilder: (c, _, _) => fallback(c),
              ),
      ),
    ),
  );
}
