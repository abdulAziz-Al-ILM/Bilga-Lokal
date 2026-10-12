import 'dart:convert';

import 'package:cryptography/cryptography.dart' as signing;
import 'package:path/path.dart' as p;

import 'model_release_config.dart';

class ModelSource {
  final String repository, release, publicKey;
  const ModelSource({
    this.repository = const String.fromEnvironment(
      'BILGA_VOICE_MODEL_REPOSITORY',
      defaultValue: voiceModelRepository,
    ),
    this.release = const String.fromEnvironment(
      'BILGA_VOICE_MODEL_RELEASE',
      defaultValue: voiceModelRelease,
    ),
    this.publicKey = const String.fromEnvironment(
      'BILGA_VOICE_CATALOG_KEY',
      defaultValue: voiceCatalogPublicKey,
    ),
  });
  bool get configured {
    try {
      return RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')
              .hasMatch(repository) &&
          RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(release) &&
          base64Decode(publicKey).length == 32;
    } on FormatException {
      return false;
    }
  }

  Uri asset(String name) {
    if (!configured ||
        name == '.' ||
        name == '..' ||
        !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(name)) {
      throw StateError('model_source_not_configured');
    }
    return Uri.https(
      'github.com',
      '/$repository/releases/download/$release/$name',
    );
  }
}

class VoiceModel {
  final String id, version, kind, engine, license, licenseUrl;
  final List<String> languages, abis;
  final int minSdk;
  final bool preview;
  final List<Map<String, dynamic>> files;
  final Map<String, dynamic> config;
  VoiceModel(Map<String, dynamic> json)
    : id = json['id'] as String,
      version = json['version'] as String,
      kind = json['kind'] as String,
      engine = json['engine'] as String,
      license = json['license'] as String,
      licenseUrl = json['licenseUrl'] as String,
      languages = List<String>.from(json['languages'] as List),
      abis = List<String>.from(json['androidAbis'] as List),
      minSdk = json['androidMinSdk'] as int,
      preview = json['preview'] == true,
      files = (json['files'] as List)
          .map((f) => Map<String, dynamic>.from(f as Map))
          .toList(),
      config = Map<String, dynamic>.from(json['config'] as Map) {
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,79}$').hasMatch(id) ||
        !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,39}$').hasMatch(version) ||
        !{
          'stt:whisper',
          'stt:sense_voice',
          'stt:streaming_transducer',
          'tts:vits',
        }.contains('$kind:$engine') ||
        !{
          'Apache-2.0',
          'MIT',
          'BSD-2-Clause',
          'BSD-3-Clause',
          'CC0-1.0',
        }.contains(license) ||
        json['licenseReviewed'] != true ||
        json['androidReviewed'] != true ||
        Uri.tryParse(licenseUrl)?.scheme != 'https' ||
        languages.isEmpty ||
        abis.isEmpty ||
        minSdk < 26 ||
        files.isEmpty ||
        files.length > 10000 ||
        (json['preview'] != null && json['preview'] is! bool)) {
      throw const FormatException('Unreviewed or unsupported model');
    }
    final names = <String>{};
    for (final file in files) {
      final name = file['path'] as String;
      if (!safeModelPath(name) ||
          name.endsWith('.part') ||
          name.endsWith('.tmp') ||
          {
            'installed.json',
            'provenance.signed.json',
          }.contains(p.basename(name)) ||
          !names.add(name) ||
          !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(file['asset'] as String) ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(file['sha256'] as String) ||
          file['bytes'] is! int ||
          (file['bytes'] as int) <= 0) {
        throw const FormatException('Invalid model file');
      }
    }
    final required = switch (engine) {
      'whisper' => ['encoder', 'decoder', 'tokens'],
      'streaming_transducer' => ['encoder', 'decoder', 'joiner', 'tokens'],
      'sense_voice' => ['model', 'tokens'],
      _ => ['model', 'tokens'],
    };
    for (final key in required) {
      if (!names.contains(config[key])) throw FormatException('Missing $key');
    }
    for (final entry in config.entries) {
      if (!{
            'model',
            'tokens',
            'encoder',
            'decoder',
            'joiner',
            'lexicon',
            'dataDir',
          }.contains(entry.key) ||
          entry.value is! String ||
          !safeModelPath(entry.value as String)) {
        throw const FormatException('Invalid runtime configuration');
      }
      if (entry.key == 'dataDir') {
        if (!names.any((n) => n.startsWith('${entry.value}/'))) {
          throw const FormatException('Missing phoneme data');
        }
      } else if (!names.contains(entry.value)) {
        throw const FormatException('Unlisted runtime file');
      }
    }
  }
  String get key => '$id-$version';
  int get bytes => files.fold(0, (sum, f) => sum + (f['bytes'] as int));
  bool compatible(int sdk, List<String> deviceAbis) =>
      sdk >= minSdk && abis.any(deviceAbis.contains);
}

bool safeModelPath(String value) =>
    value.isNotEmpty &&
    !p.isAbsolute(value) &&
    !value.contains('\\') &&
    value
        .split('/')
        .every(
          (v) =>
              v != '.' && v != '..' && RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(v),
        );

class ModelCatalog {
  final int revision;
  final DateTime expires;
  final List<VoiceModel> models;
  ModelCatalog(this.revision, this.expires, this.models);
  static Future<ModelCatalog> verify(
    List<int> envelope,
    String publicKey, {
    bool checkExpiry = true,
    DateTime? now,
  }) async {
    final json = jsonDecode(utf8.decode(envelope)) as Map;
    final payload = base64Decode(json['payload'] as String);
    final signature = signing.Signature(
      base64Decode(json['signature'] as String),
      publicKey: signing.SimplePublicKey(
        base64Decode(publicKey),
        type: signing.KeyPairType.ed25519,
      ),
    );
    if (!await signing.Ed25519().verify(payload, signature: signature)) {
      throw const FormatException('Catalog signature rejected');
    }
    final data = jsonDecode(utf8.decode(payload)) as Map;
    final expires = DateTime.parse(data['expires'] as String).toUtc();
    final clock = (now ?? DateTime.now()).toUtc();
    if (data['schema'] != 1 ||
        (data['revision'] as int) < 1 ||
        (checkExpiry && !expires.isAfter(clock))) {
      throw const FormatException('Expired or invalid catalog');
    }
    final models = (data['models'] as List)
        .map((m) => VoiceModel(Map<String, dynamic>.from(m as Map)))
        .toList();
    if (models.map((m) => m.id).toSet().length != models.length) {
      throw const FormatException('Duplicate model');
    }
    return ModelCatalog(data['revision'] as int, expires, models);
  }
}

class DownloadCancelled implements Exception {}
