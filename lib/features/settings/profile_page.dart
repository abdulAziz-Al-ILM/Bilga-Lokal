import '../agent/agent_access.dart';
import '../agent/access_summary.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../attachments/attachment_store.dart';
import '../backup/media_backup.dart';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/settings.dart';
import '../../core/strings.dart';
import '../../core/dialogs.dart';
import '../backup/backup_codec.dart';
import '../backup/backup_store.dart';
import '../backup/drive_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final settings = AppSettings.instance;
  final drive = DriveService.instance;
  final store = BackupStore();
  bool busy = false;
  String? status;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      status = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        final key = DriveService.errorKey(error);
        setState(() => status = key);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> password({required bool creating}) async {
    final first = TextEditingController(), second = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(c.tr('backupPassword')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.tr(creating ? 'passwordWarning' : 'passwordPrompt')),
                const SizedBox(height: 16),
                TextField(
                  controller: first,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  decoration: InputDecoration(labelText: c.tr('password')),
                ),
                if (creating) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: second,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    decoration: InputDecoration(
                      labelText: c.tr('repeatPassword'),
                    ),
                  ),
                ],
                if (error != null)
                  Text(
                    c.tr(error!),
                    style: TextStyle(color: Theme.of(c).colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(c.tr('cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (first.text.isEmpty ||
                    (creating && first.text.runes.length < 12)) {
                  update(() => error = 'passwordRule');
                  return;
                }
                if (creating && first.text != second.text) {
                  update(() => error = 'passwordMismatch');
                  return;
                }
                Navigator.pop(c, first.text);
              },
              child: Text(c.tr('continue')),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    first.clear();
    second.clear();
    first.dispose();
    second.dispose();
    return result;
  }

  Future<void> connect() async {
    final user = await drive.connect();
    if (!mounted) return;
    if (settings.backupOwner != null && settings.backupOwner != user.id) {
      // Do not silently send account A's local content to account B.
      if (!await confirm(context, context.tr('accountSwitchConfirm'))) {
        await drive.disconnect();
        return;
      }
    }
    settings.backupOwner = user.id;
    await settings.save();
  }

  Future<void> exportFile() async {
    final snapshot = await store.snapshot(ownerId: settings.backupOwner);
    final size = MediaBackup.blobs(snapshot).values
        .fold<int>(0, (a, b) => a + b);
    if (!mounted) return;
    final full = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('backup')),
        content: SingleChildScrollView(
          child: Text(
            '${c.tr('rBackupChoice')}\n\n${(size / (1024 * 1024)).toStringAsFixed(1)} MB ${c.tr('rBackupSize')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(c.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.tr('rBackupMetadata')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr('rBackupFull')),
          ),
        ],
      ),
    );
    if (full == null || !mounted) return;
    final secret = await password(creating: true);
    if (secret == null) return;
    final bytes = full
        ? MediaBackup.encode(snapshot, secret)
        : Stream.value(await BackupCodec.encrypt(snapshot, secret));
    await Attachments.export(
      'Bilga-${DateTime.now().millisecondsSinceEpoch}.${full ? 'bilga2' : 'bilga'}',
      'application/octet-stream',
      bytes,
    );
    if (mounted) setState(() => status = 'exported');
  }

  Future<void> importFile() async {
    if (AgentAccess.instance.initialized && !AgentAccess.instance.coreAllowed) {
      showError(context, 'readOnlyInfo');
      return;
    }
    final items = await Attachments.pick();
    if (items.isEmpty || !mounted) return;
    final secret = await password(creating: false);
    if (secret == null) return;
    final payload = await MediaBackup.decode(
      Attachments.uriStream(items.first['uri']),
      secret,
    );
    if (!mounted ||
        !await confirm(context, context.tr('restoreMerge')) ||
        !mounted) {
      return;
    }
    final changed = await store.restore(payload, context.tr('restored'));
    if (mounted) {
      setState(() => status = changed ? 'restored' : 'alreadyImported');
    }
  }

  Future<void> restore(Uint8List bytes, {required bool fromDrive}) async {
    if (AgentAccess.instance.initialized && !AgentAccess.instance.coreAllowed) {
      showError(context, 'readOnlyInfo');
      return;
    }
    if (!mounted) return;
    final secret = await password(creating: false);
    if (secret == null) return;
    final payload = await BackupCodec.decrypt(bytes, secret);
    BackupStore.validate(payload);
    if (fromDrive && payload['ownerId'] != drive.user?.id) {
      throw StateError('account_mismatch');
    }
    if (!mounted || !await confirm(context, context.tr('restoreMerge'))) return;
    if (!mounted) return;
    final label =
        '${context.tr('restored')} ${MaterialLocalizations.of(context).formatMediumDate(DateTime.now())}';
    final changed = await store.restore(payload, label);
    if (mounted) {
      setState(() => status = changed ? 'restored' : 'alreadyImported');
    }
  }

  Future<void> backupNow() async {
    if (MediaBackup.blobs(await store.snapshot()).isNotEmpty) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            content: Text(c.tr('xMediaLocalBackup')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(c.tr('cancel')),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (drive.user == null) {
      await connect();
      if (drive.user == null) return;
    }
    if (settings.backupOwner != drive.user!.id) {
      throw StateError('account_mismatch');
    }
    if (!mounted) return;
    final secret = await password(creating: true);
    if (secret == null) return;
    final payload = await store.snapshot(ownerId: drive.user!.id);
    final bytes = await BackupCodec.encrypt(payload, secret);
    await drive.upload(bytes);
    settings.lastBackup = DateTime.now().toIso8601String();
    await settings.save();
    if (mounted) setState(() => status = 'backupSaved');
  }

  Future<void> restoreDrive() async {
    if (AgentAccess.instance.initialized && !AgentAccess.instance.coreAllowed) {
      showError(context, 'readOnlyInfo');
      return;
    }
    if (drive.user == null) {
      await connect();
      if (drive.user == null) return;
    }
    final files = await drive.backups();
    if (!mounted) return;
    if (files.isEmpty) {
      setState(() => status = 'noBackups');
      return;
    }
    final id = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(c.tr('backups')),
        children: files
            .map(
              (f) => SimpleDialogOption(
                onPressed: () => Navigator.pop(c, f['id'] as String),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f['name'] as String),
                    Text(
                      '${f['size'] ?? '?'} B',
                      style: Theme.of(c).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (id != null) await restore(await drive.download(id), fromDrive: true);
  }

  Future<void> lock(bool enabled) async {
    final auth = LocalAuthentication();
    final supported = await auth.isDeviceSupported();
    if (!mounted) return;
    if (!supported) {
      showError(context, 'lockUnavailable');
      return;
    }
    final ok = await auth.authenticate(
      localizedReason: context.tr('unlock'),
      options: const AuthenticationOptions(stickyAuth: true),
    );
    if (ok) {
      settings.appLock = enabled;
      await settings.save();
    }
  }

  Future<void> chooseLanguage() async {
    await showDialog<void>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(c.tr('language')),
        children: languages.entries
            .map(
              (e) => SimpleDialogOption(
                onPressed: () async {
                  await Strings.load(code: e.key);
                  settings.language = e.key;
                  try {
                    await settings.save();
                    if (c.mounted) Navigator.pop(c);
                  } catch (_) {
                    if (c.mounted) showError(c);
                  }
                },
                child: Row(
                  children: [
                    Expanded(child: Text(e.value)),
                    if (settings.language == e.key) const Icon(Icons.check),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(context.tr('profile'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AccessSummary(),
            if (busy) const LinearProgressIndicator(),
            AbsorbPointer(
              absorbing: busy,
              child: Column(
                children: [
                  Center(
                    child: Text(
                      settings.avatar,
                      style: const TextStyle(fontSize: 56),
                    ),
                  ),
                  ListTile(
                    title: Text(
                      settings.nickname.isEmpty
                          ? context.tr('guest')
                          : settings.nickname,
                    ),
                    subtitle: Text(
                      drive.user?.email ?? context.tr('offlineProfile'),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      final name = await askText(
                        context,
                        context.tr('name'),
                        initial: settings.nickname,
                      );
                      if (name != null) {
                        await run(() async {
                          settings.nickname = name;
                          await settings.save();
                        });
                      }
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: ['🌿', '📚', '🌊', '🌙', '☀️', '🌸', '🦉', '🧠']
                        .map(
                          (a) => IconButton(
                            onPressed: () => run(() async {
                              settings.avatar = a;
                              await settings.save();
                            }),
                            icon: Text(a, style: const TextStyle(fontSize: 24)),
                          ),
                        )
                        .toList(),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(context.tr('language')),
                    subtitle: Text(languages[settings.language] ?? 'English'),
                    onTap: chooseLanguage,
                  ),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(context.tr('theme')),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: palettes.entries
                        .map(
                          (e) => ChoiceChip(
                            avatar: CircleAvatar(
                              backgroundColor: e.value,
                              radius: 9,
                            ),
                            label: Text(context.tr(e.key)),
                            selected: settings.palette == e.key,
                            onSelected: (_) => run(() async {
                              settings.palette = e.key;
                              await settings.save();
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: ThemeMode.values
                        .map(
                          (m) => ChoiceChip(
                            label: Text(context.tr(m.name)),
                            selected: settings.mode == m,
                            onSelected: (_) => run(() async {
                              settings.mode = m;
                              await settings.save();
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.feedback_outlined),
                    title: Text(context.tr('xFeedback')),
                    subtitle: const Text('ilmmizanofficial@gmail.com'),
                    onTap: () async {
                      final uri = Uri(
                        scheme: 'mailto',
                        path: 'ilmmizanofficial@gmail.com',
                        query:
                            'subject=${Uri.encodeComponent('Bilga — feedback')}',
                      );
                      try {
                        if (await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        )) {
                          return;
                        }
                      } catch (_) {}
                      if (!context.mounted) return;
                      await showDialog(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(c.tr('xFeedback')),
                          content: const SelectableText(
                            'ilmmizanofficial@gmail.com',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                await Clipboard.setData(
                                  const ClipboardData(
                                    text: 'ilmmizanofficial@gmail.com',
                                  ),
                                );
                                if (c.mounted) Navigator.pop(c);
                              },
                              child: Text(c.tr('xCopyEmail')),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SwitchListTile(
                    title: Text(context.tr('xPrivacy')),
                    value: settings.screenPrivacy,
                    onChanged: busy
                        ? null
                        : (v) => run(() async {
                            settings.screenPrivacy = v;
                            await settings.save();
                          }),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.lock_outline),
                    title: Text(context.tr('appLock')),
                    subtitle: Text(context.tr('deviceLock')),
                    value: settings.appLock,
                    onChanged: (v) => run(() => lock(v)),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: Text(context.tr('backup')),
                    subtitle: Text(context.tr('backupExplanation')),
                  ),
                  if (drive.user == null)
                    FilledButton.tonalIcon(
                      onPressed: () => run(connect),
                      icon: const Icon(Icons.account_circle_outlined),
                      label: Text(context.tr('connectGoogle')),
                    )
                  else
                    ListTile(
                      title: Text(drive.user!.email),
                      subtitle: Text(context.tr('connected')),
                      trailing: TextButton(
                        onPressed: () => run(() async {
                          if (await confirm(
                            context,
                            context.tr('disconnectConfirm'),
                          )) {
                            await drive.disconnect();
                          }
                        }),
                        child: Text(context.tr('disconnect')),
                      ),
                    ),
                  if (settings.lastBackup != null)
                    ListTile(
                      title: Text(context.tr('lastBackup')),
                      subtitle: Text(settings.lastBackup!),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => run(backupNow),
                        icon: const Icon(Icons.backup_outlined),
                        label: Text(context.tr('backupNow')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => run(restoreDrive),
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: Text(context.tr('restoreDrive')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => run(exportFile),
                        icon: const Icon(Icons.file_upload_outlined),
                        label: Text(context.tr('export')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => run(importFile),
                        icon: const Icon(Icons.file_download_outlined),
                        label: Text(context.tr('import')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('backupManual'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('privacySummary'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.tr(status!), textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    ),
  );
}
