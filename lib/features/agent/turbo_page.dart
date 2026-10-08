import 'package:flutter/material.dart';

import '../../core/strings.dart';

class TurboPage extends StatelessWidget {
  const TurboPage({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(c.tr('xTurbo'))),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(c.tr('turboDeferred')),
    ),
  );
}
