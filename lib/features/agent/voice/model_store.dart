import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';
export 'model_catalog.dart';

/// Network API accepts only release asset names. Private text/audio cannot be
/// supplied, and only GET requests without cookies/auth/body are constructed.
class VoiceModelStore extends ChangeNotifier {
  final Directory root;
  final ModelSource source;
  final http.Client Function() clientFactory;
  ModelCatalog? catalog;
  List<int>? _catalogEnvelope;
  final _installedModels = <VoiceModel>[];
  bool catalogRejected = false;
  final _verified = <String>{};
  String? activeModel;
  int received = 0, total = 0;
  bool _cancelled = false, _refreshing = false;
  bool get catalogRefreshing => _refreshing;
  bool get isBusy => _refreshing || activeModel != null;
  http.Client? _activeClient;
  VoiceModelStore(
    this.root, {
    this.source = const ModelSource(),
    http.Client Function()? clientFactory,
  }) : clientFactory = clientFactory ?? http.Client.new;
  static Future<VoiceModelStore> open() async {
    final base = await getApplicationSupportDirectory();
    final store = VoiceModelStore(
      Directory(p.join(base.path, 'offline_voice_models')),
    );
    await store.root.create(recursive: true);
    await store.loadCached();
    return store;
  }

  Directory directory(VoiceModel model) =>
      Directory(p.join(root.path, model.id, model.version));
  Future<void> loadCached() async {
    if (!source.configured) return;
    final file = File(p.join(root.path, 'catalog.signed.json'));
    if (await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        catalog = await ModelCatalog.verify(
          bytes,
          source.publicKey,
          checkExpiry: false,
        );
        _catalogEnvelope = bytes;
      } catch (_) {
        catalogRejected = true;
      }
    }
    // Each installed version retains its signed provenance. A refreshed catalog
    // must not hide a working older version while an update is being acquired.
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File ||
          p.basename(entity.path) != 'provenance.signed.json') {
        continue;
      }
      try {
        final approved = await ModelCatalog.verify(
          await entity.readAsBytes(),
          source.publicKey,
          checkExpiry: false,
        );
        for (final model in approved.models) {
          if (directory(model).path == entity.parent.path &&
              await installed(model)) {
            _installedModels.add(model);
          }
        }
      } catch (_) {
        catalogRejected = true;
      }
    }
  }

  Future<http.StreamedResponse> _get(
    http.Client client,
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    for (var redirects = 0; redirects < 6; redirects++) {
      if (uri.scheme != 'https' ||
          !{
            'github.com',
            'release-assets.githubusercontent.com',
            'objects.githubusercontent.com',
          }.contains(uri.host)) {
        throw const FormatException('Untrusted model host');
      }
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers.addAll(headers ?? {});
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers['location'];
        await response.stream.drain<void>().timeout(
          const Duration(seconds: 30),
        );
        if (location == null) throw const FormatException('Missing redirect');
        uri = uri.resolve(location);
      } else {
        return response;
      }
    }
    throw const FormatException('Too many model redirects');
  }

  Future<void> refresh() async {
    if (isBusy) throw StateError('download_busy');
    final client = clientFactory();
    _refreshing = true;
    _cancelled = false;
    _activeClient = client;
    notifyListeners();
    try {
      final response = await _get(client, source.asset('catalog.signed.json'));
      if (response.statusCode != 200) {
        throw HttpException('Catalog HTTP ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > 4 * 1024 * 1024) {
          throw const FormatException('Catalog too large');
        }
      }
      if (_cancelled) throw DownloadCancelled();
      final next = await ModelCatalog.verify(bytes, source.publicKey);
      if (next.revision < (catalog?.revision ?? 0)) {
        throw const FormatException('Catalog rollback rejected');
      }
      final staged = File(p.join(root.path, 'catalog.tmp'));
      await staged.writeAsBytes(bytes, flush: true);
      await staged.rename(p.join(root.path, 'catalog.signed.json'));
      catalog = next;
      _catalogEnvelope = bytes;
      catalogRejected = false;
      _verified.clear();
      notifyListeners();
    } catch (_) {
      if (_cancelled) throw DownloadCancelled();
      rethrow;
    } finally {
      client.close();
      _activeClient = null;
      _refreshing = false;
      notifyListeners();
    }
  }

  void cancel() {
    _cancelled = true;
    _activeClient?.close();
  }

  Future<bool> installed(VoiceModel model) async {
    final marker = File(p.join(directory(model).path, 'installed.json'));
    return await marker.exists() &&
        await marker.readAsString() == _identity(model);
  }

  String _identity(VoiceModel model) => jsonEncode(model.files);
  Future<bool> verifyInstalled(VoiceModel model) async {
    if (!await installed(model)) return false;
    final identity = model.key + _identity(model);
    if (_verified.contains(identity)) return true;
    for (final file in model.files) {
      if (!await _valid(
        File(p.join(directory(model).path, file['path'] as String)),
        file,
      )) {
        return false;
      }
    }
    _verified.add(identity);
    return true;
  }

  Future<bool> _valid(File file, Map<String, dynamic> spec) async =>
      await file.exists() &&
      await file.length() == spec['bytes'] &&
      (await sha256.bind(file.openRead()).first).toString() == spec['sha256'];
  Future<void> install(
    VoiceModel model, {
    required int sdk,
    required List<String> abis,
  }) async {
    if (isBusy) throw StateError('download_busy');
    if (_catalogEnvelope == null ||
        catalog == null ||
        !catalog!.models.contains(model) ||
        !catalog!.expires.isAfter(DateTime.now()) ||
        !model.compatible(sdk, abis)) {
      throw StateError('untrusted_or_incompatible_model');
    }
    _verified.clear();
    activeModel = model.id;
    received = 0;
    total = model.bytes;
    _cancelled = false;
    final client = clientFactory();
    _activeClient = client;
    notifyListeners();
    final dir = directory(model);
    try {
      await dir.create(recursive: true);
      for (final spec in model.files) {
        if (_cancelled) throw DownloadCancelled();
        final file = File(p.join(dir.path, spec['path'] as String));
        await file.parent.create(recursive: true);
        if (await _valid(file, spec)) {
          received += spec['bytes'] as int;
          notifyListeners();
          continue;
        }
        final part = File('${file.path}.part');
        var offset = await part.exists() ? await part.length() : 0;
        final size = spec['bytes'] as int;
        if (offset >= size) {
          if (await _valid(part, spec)) {
            await part.rename(file.path);
            received += size;
            notifyListeners();
            continue;
          }
          await part.writeAsBytes([]);
          offset = 0;
        }
        final response = await _get(
          client,
          source.asset(spec['asset'] as String),
          headers: offset > 0 ? {'Range': 'bytes=$offset-'} : null,
        );
        if (response.statusCode == 200) {
          offset = 0;
        } else if (response.statusCode != 206 ||
            response.headers['content-range'] !=
                'bytes $offset-${size - 1}/$size') {
          throw HttpException('Invalid model range response');
        }
        received += offset;
        notifyListeners();
        var written = offset;
        final sink = part.openWrite(
          mode: offset > 0 ? FileMode.append : FileMode.write,
        );
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 30),
          )) {
            if (_cancelled) throw DownloadCancelled();
            written += chunk.length;
            if (written > size) throw const FormatException('Oversized model');
            sink.add(chunk);
            received += chunk.length;
            notifyListeners();
          }
        } finally {
          await sink.close();
        }
        if (_cancelled) throw DownloadCancelled();
        if (!await _valid(part, spec)) {
          // A completed corrupt object cannot be resumed safely.
          if (await part.length() >= size) await part.delete();
          throw const FormatException('Model checksum/size rejected');
        }
        await part.rename(file.path);
      }
      if (_cancelled) throw DownloadCancelled();
      await File(p.join(dir.path, 'provenance.signed.json'))
          .writeAsBytes(_catalogEnvelope!, flush: true);
      final marker = File(p.join(dir.path, 'installed.tmp'));
      await marker.writeAsString(_identity(model), flush: true);
      await marker.rename(p.join(dir.path, 'installed.json'));
      _installedModels.removeWhere((m) => m.id == model.id);
      _installedModels.add(model);
      // Keep the previous working version until the replacement is committed.
      await for (final entity in dir.parent.list()) {
        if (entity is Directory && entity.path != dir.path) {
          await entity.delete(recursive: true);
        }
      }
    } catch (_) {
      if (_cancelled) throw DownloadCancelled();
      rethrow;
    } finally {
      client.close();
      _activeClient = null;
      activeModel = null;
      notifyListeners();
    }
  }

  Future<VoiceModel?> find(
    String language,
    String kind,
    int sdk,
    List<String> abis,
  ) async {
    for (final model in [...?catalog?.models, ..._installedModels]) {
      if (model.languages.contains(language.split('-').first) &&
          model.kind == kind &&
          model.compatible(sdk, abis) &&
          await verifyInstalled(model)) {
        return model;
      }
    }
    return null;
  }

  Future<int> storageBytes() async {
    var size = 0;
    if (!await root.exists()) return size;
    await for (final file in root.list(recursive: true, followLinks: false)) {
      if (file is File) size += await file.length();
    }
    return size;
  }

  Future<void> delete(VoiceModel model) async {
    if (isBusy) throw StateError('download_busy');
    _verified.clear();
    _installedModels.removeWhere((m) => m.id == model.id);
    final dir = Directory(p.join(root.path, model.id));
    if (await dir.exists()) await dir.delete(recursive: true);
    notifyListeners();
  }
}
