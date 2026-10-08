import 'features/attachments/attachment_store.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'features/agent/agent_access.dart';

import 'app/bilga_app.dart';
import 'core/settings.dart';
import 'core/strings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 * 1024 * 1024;
  runApp(const _Startup());
}

class _Startup extends StatefulWidget {
  const _Startup();
  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late Future<void> loading;
  Future<void> load() async {
    await AppSettings.instance.load();
    await Strings.load(code: AppSettings.instance.language);
    await Attachments.clearPreviews();
    unawaited(AgentAccess.instance.init());
  }

  @override
  void initState() {
    super.initState();
    loading = load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: loading,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return const BilgaApp();
      }
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? TextButton(
                    onPressed: () => setState(() => loading = load()),
                    child: Text(Strings.get('uz', 'retry')),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}
