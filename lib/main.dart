import 'core/review_performance.dart';
import 'features/attachments/attachment_store.dart';

import 'package:flutter/material.dart';

import 'features/agent/agent_access.dart';

import 'app/bilga_app.dart';
import 'core/settings.dart';
import 'core/strings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 * 1024 * 1024;
  ReviewPerformance.start();
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
    await Future.wait([
      ReviewPerformance.measure(
        'catalog.load',
        () => Strings.load(code: AppSettings.instance.language),
      ),
      ReviewPerformance.measure('preview.cleanup', Attachments.clearPreviews),
      ReviewPerformance.measure('access.init', AgentAccess.instance.init),
    ]);
  }

  @override
  void initState() {
    super.initState();
    loading = ReviewPerformance.measure('startup.ready', load);
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
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? TextButton(
                    onPressed: () => setState(() => loading = load()),
                    child: Text(
                      Strings.catalogs[AppSettings
                              .instance
                              .language]?['retry'] ??
                          Strings.catalogs[AppSettings
                              .defaultLanguage]?['retry'] ??
                          'Try again',
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}
