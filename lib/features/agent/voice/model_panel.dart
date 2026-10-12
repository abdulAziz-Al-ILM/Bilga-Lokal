import 'package:flutter/material.dart';

import '../../../core/start_strings.dart';
import '../../../core/settings.dart';
import 'voice_languages.dart';
import 'model_store.dart';
import 'offline_voice.dart';

class VoiceModelPanel extends StatefulWidget {
  final OfflineVoice voice;
  final String language;
  final VoidCallback onChanged;
  const VoiceModelPanel({
    super.key,
    required this.voice,
    required this.language,
    required this.onChanged,
  });
  @override
  State<VoiceModelPanel> createState() => _VoiceModelPanelState();
}

class _VoiceModelPanelState extends State<VoiceModelPanel>
    with WidgetsBindingObserver {
  String? message;
  bool working = false;
  int storage = 0;
  VoiceCapabilities? capabilities;
  bool awaitingTtsSettings = false;
  VoiceModelStore get store => widget.voice.store;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && awaitingTtsSettings) {
      awaitingTtsSettings = false;
      run(widget.voice.refreshSystemTts);
    }
  }

  Future<void> downloadLanguage() async {
    final language = widget.language;
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          startText(
            'Offline modellarni yuklash',
            'Download offline models',
            'Загрузить офлайн-модели',
          ),
        ),
        content: Text(
          startText(
            'Tanlangan tilning yetishmayotgan STT va TTS modellari imzosi tekshirilgan katalogdan olinadi. Hajm va jarayon quyida ko‘rsatiladi, bekor qilish mumkin. Yozuv va ovoz yuborilmaydi.',
            'Get missing STT and TTS models for this language from the verified catalog. Size and progress appear below; you can cancel. Notes and audio are never sent.',
            'Загрузить недостающие STT и TTS из проверенного каталога. Размер и ход загрузки видны ниже, доступна отмена. Заметки и голос не отправляются.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(startText('Bekor qilish', 'Cancel', 'Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(startText('Yuklab olish', 'Download', 'Скачать')),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    await run(() async {
      final missing = await widget.voice.downloadMissingModels(language);
      if (mounted && missing.isNotEmpty) {
        setState(
          () => message =
              '${missing.map((k) => k.toUpperCase()).join(", ")}: ${startText("bu til va qurilma uchun tekshirilgan model katalogda yo‘q.", "no reviewed model for this language and device in the catalog.", "в каталоге нет проверенной модели для этого языка и устройства.")}',
        );
      }
    });
  }

  @override
  void didUpdateWidget(VoiceModelPanel old) {
    super.didUpdateWidget(old);
    if (old.language != widget.language) refreshStatus();
  }

  Future<void> refreshStatus() async {
    try {
      final locale = widget.language;
      final cap = await widget.voice.capabilities(locale);
      final size = await store.storageBytes();
      if (mounted && locale == widget.language) {
        setState(() {
          capabilities = cap;
          storage = size;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = startText(
            'Offline ovoz holatini tekshirib bo‘lmadi.',
            'Could not check offline speech availability.',
            'Не удалось проверить офлайн-речь.',
          ),
        );
      }
    }
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      working = true;
      message = null;
    });
    try {
      await action();
      widget.voice.invalidateCapabilities();
      widget.onChanged();
    } on DownloadCancelled {
      if (mounted) {
        setState(
          () => message = startText(
            'Bekor qilindi. Keyingi safar yuklash davom ettiriladi.',
            'Cancelled. Partial downloads can resume next time.',
            'Отменено. Загрузка может быть продолжена.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = startText(
            'Modelni yuklab bo‘lmadi yoki tekshiruvdan o‘tmadi. Qayta urinib ko‘ring.',
            'Model download or verification failed. Try again.',
            'Ошибка загрузки или проверки модели. Повторите попытку.',
          ),
        );
      }
    } finally {
      await refreshStatus();
      if (mounted) setState(() => working = false);
    }
  }

  String availability(String state) =>
      voiceAvailabilityText(AppSettings.instance.language, state);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              startText(
                'Offline ovoz modellari',
                'Offline speech models',
                'Офлайн-модели речи',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'STT: ${capabilities == null ? "…" : availability(capabilities!.stt)}\nTTS: ${capabilities == null ? "…" : availability(capabilities!.tts ? "available" : "unavailable")}',
            ),
            Text(
              '${startText("Xotira", "Storage", "Память")}: ${(storage / 1048576).toStringAsFixed(1)} MB',
            ),
            if (store.catalog?.models.any(
                  (m) =>
                      m.preview &&
                      m.languages.contains(widget.language.split('-').first),
                ) ??
                false)
              Text(
                startText(
                  'Sinov modeli: qisqa buyruqlar xato tanilishi mumkin. To‘xtatish va davom ettirish tugmalaridan ham foydalaning.',
                  'Preview model: short commands may be misrecognized. Pause and resume buttons are also available.',
                  'Тестовая модель: короткие команды могут распознаваться ошибочно. Используйте также кнопки паузы и продолжения.',
                ),
              ),
            if (store.catalogRejected)
              Text(
                startText(
                  'Katalog imzosi tekshirilmadi. Noma’lum modellar ishlatilmaydi.',
                  'Catalog verification failed. Untrusted models are disabled.',
                  'Каталог не прошёл проверку. Недоверенные модели отключены.',
                ),
              ),
            if (!store.source.configured)
              Text(
                startText(
                  'Model yuklash hali sozlanmagan. Yuklashni yoqish uchun ilova yangilanishi kerak. Tilni almashtirish modelni o‘rnatmaydi.',
                  'Model downloads are not configured yet. An app update is needed to enable downloads. Changing language does not install a model.',
                  'Загрузка моделей пока не настроена. Для загрузки нужно обновление приложения. Смена языка не устанавливает модель.',
                ),
              ),
            if (capabilities != null &&
                (!{'available', 'model'}.contains(capabilities!.stt) ||
                    !capabilities!.tts))
              FilledButton.icon(
                onPressed: !store.source.configured || working || store.isBusy
                    ? null
                    : downloadLanguage,
                icon: const Icon(Icons.download),
                label: Text(startText('Yuklab olish', 'Download', 'Скачать')),
              ),
            if (capabilities != null && !capabilities!.tts) ...[
              Text(
                startText(
                  'TTS alohida ovoz talab qiladi. Android’da shu tilning offline ovozini o‘rnating va asosiy TTS dvigatelini tanlang; qaytganda qayta tekshiriladi.',
                  'TTS needs a separate voice. Install an offline voice for this language in Android and select its default TTS engine; availability is checked when you return.',
                  'Для TTS нужен отдельный голос. Установите офлайн-голос языка в Android и выберите движок TTS по умолчанию; после возврата доступность проверится.',
                ),
              ),
              TextButton.icon(
                onPressed: working || store.isBusy
                    ? null
                    : () => run(() async {
                        awaitingTtsSettings = true;
                        try {
                          await widget.voice.openTtsSettings();
                        } catch (_) {
                          awaitingTtsSettings = false;
                          rethrow;
                        }
                      }),
                icon: const Icon(Icons.settings_voice),
                label: Text(
                  startText(
                    'Offline ovozni sozlash',
                    'Set up offline voice',
                    'Настроить офлайн-голос',
                  ),
                ),
              ),
            ],
            if (store.source.configured)
              TextButton.icon(
                onPressed: working || store.isBusy
                    ? null
                    : () => run(store.refresh),
                icon: const Icon(Icons.refresh),
                label: Text(
                  startText(
                    'Katalogni yangilash',
                    'Refresh catalog',
                    'Обновить каталог',
                  ),
                ),
              ),
            for (final kind in ['stt', 'tts']) ...[
              if (store.catalog != null &&
                  !(store.catalog?.models.any(
                        (m) =>
                            m.kind == kind &&
                            m.languages.contains(
                              widget.language.split('-').first,
                            ),
                      ) ??
                      false))
                Text(
                  '${kind.toUpperCase()}: ${startText("katalogda model yo‘q", "no model in catalog", "модели нет в каталоге")}',
                ),
            ],
            for (final model
                in store.catalog?.models.where(
                      (m) => m.languages.contains(
                        widget.language.split('-').first,
                      ),
                    ) ??
                    <VoiceModel>[])
              FutureBuilder<bool>(
                future: store.installed(model),
                builder: (context, snapshot) {
                  final compatible =
                      capabilities != null &&
                      model.compatible(capabilities!.sdk, capabilities!.abis);
                  final installed = snapshot.data == true;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${model.kind.toUpperCase()} · ${model.id} ${model.version}',
                    ),
                    subtitle: Text(
                      '${model.license} · ${(model.bytes / 1048576).toStringAsFixed(1)} MB\n${compatible ? (installed ? startText("O‘rnatilgan", "Installed", "Установлено") : startText("Yuklash mumkin", "Available to download", "Можно загрузить")) : startText("Bu Android qurilmaga mos emas", "Incompatible with this Android device", "Несовместимо с устройством")}',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: startText(
                            'Yuklash / qayta tekshirish',
                            'Download / verify',
                            'Загрузить / проверить',
                          ),
                          onPressed: working || store.isBusy || !compatible
                              ? null
                              : () => run(
                                  () => store.install(
                                    model,
                                    sdk: capabilities!.sdk,
                                    abis: capabilities!.abis,
                                  ),
                                ),
                          icon: const Icon(Icons.download),
                        ),
                        IconButton(
                          tooltip: startText('O‘chirish', 'Delete', 'Удалить'),
                          onPressed: working || store.isBusy
                              ? null
                              : () => run(() => store.delete(model)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (store.catalogRefreshing) ...[
              const LinearProgressIndicator(),
              TextButton(
                onPressed: store.cancel,
                child: Text(startText('Bekor qilish', 'Cancel', 'Отмена')),
              ),
            ],
            if (store.activeModel != null) ...[
              LinearProgressIndicator(
                value: store.total > 0 ? store.received / store.total : null,
              ),
              Text(
                '${(store.received / 1048576).toStringAsFixed(1)} / ${(store.total / 1048576).toStringAsFixed(1)} MB',
              ),
              TextButton(
                onPressed: store.cancel,
                child: Text(startText('Bekor qilish', 'Cancel', 'Отмена')),
              ),
            ],
            if (working && store.activeModel == null)
              const LinearProgressIndicator(),
            if (message != null) Text(message!),
            Text(
              startText(
                'Internet faqat model fayllarini olish uchun. Yozuvlar va ovoz yuborilmaydi.',
                'Internet is used only to acquire models. Notes and audio stay on this device.',
                'Интернет нужен только для загрузки моделей. Заметки и голос остаются на устройстве.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
