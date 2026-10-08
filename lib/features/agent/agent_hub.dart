import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'agent_page.dart';
import 'turbo_page.dart';

class AgentHub extends StatelessWidget {
  const AgentHub({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(c.tr('xAgent'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            title: Text(c.tr('xStart')),
            subtitle: Text(c.tr('xVoice')),
            leading: const Icon(Icons.record_voice_over),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const AgentPage()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: Text(c.tr('xTurbo')),
            subtitle: Text(c.tr('turboDeferred')),
            leading: const Icon(Icons.auto_awesome),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const TurboPage()),
            ),
          ),
        ),
      ],
    ),
  );
}
