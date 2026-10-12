import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bilga/features/agent/voice/model_store.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as signing;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> modelJson({
  String id = 'test',
  String version = '1',
  List<int> bytes = const [1, 2, 3],
}) => {
  'id': id,
  'version': version,
  'kind': 'stt',
  'engine': 'whisper',
  'license': 'Apache-2.0',
  'licenseUrl': 'https://example.org/LICENSE',
  'licenseReviewed': true,
  'androidReviewed': true,
  'languages': ['en'],
  'androidAbis': ['arm64-v8a'],
  'androidMinSdk': 26,
  'files': ['encoder.onnx', 'decoder.onnx', 'tokens.txt']
      .map(
        (name) => {
          'path': name,
          'asset': name,
          'bytes': bytes.length,
          'sha256': sha256.convert(bytes).toString(),
        },
      )
      .toList(),
  'config': {
    'encoder': 'encoder.onnx',
    'decoder': 'decoder.onnx',
    'tokens': 'tokens.txt',
  },
};

Future<List<int>> signedCatalog(
  signing.SimpleKeyPair key, {
  int revision = 1,
  bool expired = false,
  String version = '1',
}) async {
  final bytes = utf8.encode(
    jsonEncode({
      'schema': 1,
      'revision': revision,
      'expires': expired ? '2000-01-01T00:00:00Z' : '2099-01-01T00:00:00Z',
      'models': [modelJson(version: version)],
    }),
  );
  final signature = await signing.Ed25519().sign(bytes, keyPair: key);
  return utf8.encode(
    jsonEncode({
      'payload': base64Encode(bytes),
      'signature': base64Encode(signature.bytes),
    }),
  );
}

class StreamClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  StreamClient(this.handler);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

class CatalogClient extends http.BaseClient {
  final http.Client inner;
  final List<int> envelope;
  CatalogClient(this.inner, this.envelope);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith('/catalog.signed.json')) {
      return http.StreamedResponse(Stream.value(envelope), 200);
    }
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}

void main() {
  late Directory root;
  late signing.SimpleKeyPair key;
  late ModelSource source;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('bilga-model-test');
    key = await signing.Ed25519().newKeyPair();
    source = ModelSource(
      repository: 'owner/models',
      publicKey: base64Encode((await key.extractPublicKey()).bytes),
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  Future<VoiceModelStore> storeWith(http.Client Function() factory) async {
    final envelope = await signedCatalog(key);
    final store = VoiceModelStore(
      root,
      source: source,
      clientFactory: () => CatalogClient(factory(), envelope),
    );
    await store.refresh();
    return store;
  }

  test(
    'Signed catalog rejects tampering, wrong key, expiry and rollback',
    () async {
      final bytes = await signedCatalog(key);
      expect(
        (await ModelCatalog.verify(bytes, source.publicKey)).models.length,
        1,
      );
      final json = jsonDecode(utf8.decode(bytes)) as Map;
      json['payload'] = base64Encode(utf8.encode('{}'));
      await expectLater(
        ModelCatalog.verify(utf8.encode(jsonEncode(json)), source.publicKey),
        throwsFormatException,
      );
      final wrong = await signing.Ed25519().newKeyPair();
      await expectLater(
        ModelCatalog.verify(
          bytes,
          base64Encode((await wrong.extractPublicKey()).bytes),
        ),
        throwsFormatException,
      );
      await expectLater(
        ModelCatalog.verify(
          await signedCatalog(key, expired: true),
          source.publicKey,
        ),
        throwsFormatException,
      );
      final store = await storeWith(
        () => MockClient((r) async => http.Response.bytes(bytes, 200)),
      );
      store.catalog = ModelCatalog(2, DateTime.utc(2099), []);
      await expectLater(store.refresh(), throwsFormatException);
    },
  );
  test(
    'Unconfigured source and unreviewed/incompatible models fail closed',
    () {
      expect(
        const ModelSource(repository: '', publicKey: '').configured,
        isFalse,
      );
      expect(
        () => const ModelSource(
          repository: '',
          publicKey: '',
        ).asset('catalog.signed.json'),
        throwsStateError,
      );
      expect(
        () => VoiceModel(modelJson()..['licenseReviewed'] = false),
        throwsFormatException,
      );
      expect(
        () => VoiceModel(modelJson()..['androidReviewed'] = false),
        throwsFormatException,
      );
      expect(
        () => VoiceModel(modelJson()..['license'] = 'unknown'),
        throwsFormatException,
      );
      expect(
        () => VoiceModel(modelJson()..['engine'] = 'arbitrary-library'),
        throwsFormatException,
      );
      expect(VoiceModel(modelJson()).compatible(25, ['arm64-v8a']), isFalse);
      expect(VoiceModel(modelJson()).compatible(35, ['x86_64']), isFalse);
      for (final path in [
        '../outside',
        '/absolute',
        'x/../outside',
        'x\\outside',
        'x//file',
      ]) {
        expect(safeModelPath(path), isFalse);
      }
    },
  );
  test('Malformed catalog keys never enable downloads', () {
    for (final key in [
      '',
      'invalid!',
      base64Encode([1, 2, 3]),
    ]) {
      expect(
        ModelSource(repository: 'owner/models', publicKey: key).configured,
        isFalse,
      );
    }
    expect(source.configured, isTrue);
  });
  test('Shipped public model source pins the dedicated repository and key', () {
    const shipped = ModelSource();
    expect(shipped.configured, isTrue);
    expect(shipped.repository, 'abdulAziz-Al-ILM/Bilga-Language-Models');
    expect(
      shipped.asset('catalog.signed.json').toString(),
      'https://github.com/abdulAziz-Al-ILM/Bilga-Language-Models/releases/download/voice-models-v1/catalog.signed.json',
    );
    expect(base64Decode(shipped.publicKey), hasLength(32));
  });
  test(
    'Preview availability is explicit and does not bypass Android review',
    () {
      expect(VoiceModel(modelJson()..['preview'] = true).preview, isTrue);
      expect(VoiceModel(modelJson()).preview, isFalse);
      expect(
        () => VoiceModel(modelJson()..['preview'] = 'true'),
        throwsFormatException,
      );
      expect(
        () => VoiceModel(
          modelJson()..addAll({'preview': true, 'androidReviewed': false}),
        ),
        throwsFormatException,
      );
    },
  );
  test('Streaming transducer requires all four hashed runtime files', () {
    final json = modelJson()..['engine'] = 'streaming_transducer';
    expect(() => VoiceModel(json), throwsFormatException);
    (json['files'] as List).add({
      'path': 'joiner.onnx',
      'asset': 'joiner.onnx',
      'bytes': 3,
      'sha256': sha256.convert([1, 2, 3]).toString(),
    });
    (json['config'] as Map)['joiner'] = 'joiner.onnx';
    expect(VoiceModel(json).engine, 'streaming_transducer');
    json['androidReviewed'] = false;
    expect(() => VoiceModel(json), throwsFormatException);
  });
  test(
    'Private install verifies files, emits progress and sends only empty GETs',
    () async {
      final requests = <http.Request>[];
      final store = await storeWith(
        () => MockClient((request) async {
          requests.add(request);
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      var notifications = 0;
      store.addListener(() => notifications++);
      final model = store.catalog!.models.first;
      await store.install(model, sdk: 35, abis: ['arm64-v8a']);
      expect(await store.verifyInstalled(model), isTrue);
      expect(notifications, greaterThan(3));
      expect(store.received, model.bytes);
      expect(
        requests.every(
          (r) =>
              r.method == 'GET' &&
              r.body.isEmpty &&
              r.url.host == 'github.com' &&
              !r.headers.containsKey('authorization'),
        ),
        isTrue,
      );
      expect(await store.find('ru', 'stt', 35, ['arm64-v8a']), isNull);
      expect(await store.find('en', 'tts', 35, ['arm64-v8a']), isNull);
      expect(await store.storageBytes(), greaterThan(0));
      await store.delete(model);
      expect(await store.installed(model), isFalse);
    },
  );
  test('Interrupted download resumes only a correct HTTP range', () async {
    final requests = <http.Request>[];
    final store = await storeWith(
      () => MockClient((request) async {
        requests.add(request);
        if (request.headers['Range'] != null ||
            request.headers['range'] != null) {
          return http.Response.bytes(
            [2, 3],
            206,
            headers: {'content-range': 'bytes 1-2/3'},
          );
        }
        return http.Response.bytes([1, 2, 3], 200);
      }),
    );
    final model = store.catalog!.models.first;
    final part = File('${store.directory(model).path}/encoder.onnx.part');
    await part.parent.create(recursive: true);
    await part.writeAsBytes([1]);
    await store.install(model, sdk: 35, abis: ['arm64-v8a']);
    expect(
      requests.first.headers['Range'] ?? requests.first.headers['range'],
      'bytes=1-',
    );
    expect(await store.installed(model), isTrue);
  });
  test(
    'Server ignoring Range restarts file without duplicating partial bytes',
    () async {
      final store = await storeWith(
        () => MockClient((r) async => http.Response.bytes([1, 2, 3], 200)),
      );
      final model = store.catalog!.models.first;
      final part = File('${store.directory(model).path}/encoder.onnx.part');
      await part.parent.create(recursive: true);
      await part.writeAsBytes([1]);
      await store.install(model, sdk: 35, abis: ['arm64-v8a']);
      expect(await store.verifyInstalled(model), isTrue);
    },
  );
  test(
    'Bad checksum never marks installed; cancellation preserves partial data',
    () async {
      final corrupt = await storeWith(
        () => MockClient((r) async => http.Response.bytes([9, 9, 9], 200)),
      );
      final model = corrupt.catalog!.models.first;
      await expectLater(
        corrupt.install(model, sdk: 35, abis: ['arm64-v8a']),
        throwsFormatException,
      );
      expect(await corrupt.installed(model), isFalse);
      final stream = StreamController<List<int>>();
      final cancelled = await storeWith(
        () => StreamClient(
          (r) async => http.StreamedResponse(stream.stream, 200),
        ),
      );
      final next = cancelled.catalog!.models.first;
      final firstByte = Completer<void>();
      cancelled.addListener(() {
        if (cancelled.received == 1 && !firstByte.isCompleted) {
          firstByte.complete();
        }
      });
      final job = cancelled.install(next, sdk: 35, abis: ['arm64-v8a']);
      final expectation = expectLater(job, throwsA(isA<DownloadCancelled>()));
      stream.add([1]);
      await firstByte.future;
      cancelled.cancel();
      await stream.close();
      await expectation;
      expect(await cancelled.installed(next), isFalse);
      expect(
        await File('${cancelled.directory(next).path}/encoder.onnx.part')
            .length(),
        1,
      );
    },
  );
  test(
    'Untrusted redirect is blocked before any private data could leave',
    () async {
      var calls = 0;
      final store = await storeWith(
        () => MockClient((r) async {
          calls++;
          return http.Response(
            '',
            302,
            headers: {'location': 'https://evil.example/model'},
          );
        }),
      );
      await expectLater(
        store.install(
          store.catalog!.models.first,
          sdk: 35,
          abis: ['arm64-v8a'],
        ),
        throwsFormatException,
      );
      expect(calls, 1);
    },
  );
  test(
    'Deleting one model never removes another id sharing its prefix',
    () async {
      final store = await storeWith(
        () => MockClient((r) async => http.Response.bytes([1, 2, 3], 200)),
      );
      final model = store.catalog!.models.first;
      final other = VoiceModel(modelJson(id: 'test-extra'));
      final keep = store.directory(other);
      await keep.create(recursive: true);
      await store.delete(model);
      expect(await keep.exists(), isTrue);
    },
  );
  test(
    'A failed update keeps the old model usable after offline restart',
    () async {
      var envelope = await signedCatalog(key);
      var failDownload = false;
      http.Client makeClient() => MockClient((request) async {
        if (request.url.path.endsWith('/catalog.signed.json')) {
          return http.Response.bytes(envelope, 200);
        }
        return failDownload
            ? http.Response('', 503)
            : http.Response.bytes([1, 2, 3], 200);
      });
      final store = VoiceModelStore(
        root,
        source: source,
        clientFactory: makeClient,
      );
      await store.refresh();
      final first = store.catalog!.models.first;
      await store.install(first, sdk: 35, abis: ['arm64-v8a']);
      envelope = await signedCatalog(key, revision: 2, version: '2');
      await store.refresh();
      failDownload = true;
      await expectLater(
        store.install(
          store.catalog!.models.first,
          sdk: 35,
          abis: ['arm64-v8a'],
        ),
        throwsA(isA<HttpException>()),
      );
      expect((await store.find('en', 'stt', 35, ['arm64-v8a']))?.version, '1');
      final offline = VoiceModelStore(
        root,
        source: source,
        clientFactory: () => throw StateError('No network allowed'),
      );
      await offline.loadCached();
      expect(
        (await offline.find('en', 'stt', 35, ['arm64-v8a']))?.version,
        '1',
      );
      failDownload = false;
      await store.install(
        store.catalog!.models.first,
        sdk: 35,
        abis: ['arm64-v8a'],
      );
      expect((await store.find('en', 'stt', 35, ['arm64-v8a']))?.version, '2');
      expect(await store.directory(first).exists(), isFalse);
    },
  );
  test(
    'Invalid resume ranges and modified installed files are rejected',
    () async {
      final store = await storeWith(
        () => MockClient(
          (r) async => http.Response.bytes(
            [2, 3],
            206,
            headers: {'content-range': 'bytes 0-1/3'},
          ),
        ),
      );
      final model = store.catalog!.models.first;
      final part = File('${store.directory(model).path}/encoder.onnx.part');
      await part.parent.create(recursive: true);
      await part.writeAsBytes([1]);
      await expectLater(
        store.install(model, sdk: 35, abis: ['arm64-v8a']),
        throwsA(isA<HttpException>()),
      );
      final working = await storeWith(
        () => MockClient((r) async => http.Response.bytes([1, 2, 3], 200)),
      );
      await working.install(
        working.catalog!.models.first,
        sdk: 35,
        abis: ['arm64-v8a'],
      );
      await File(
        '${working.directory(working.catalog!.models.first).path}/encoder.onnx',
      ).writeAsBytes([9, 9, 9]);
      final reopened = VoiceModelStore(root, source: source);
      await reopened.loadCached();
      expect(await reopened.find('en', 'stt', 35, ['arm64-v8a']), isNull);
    },
  );
  test('Untrusted cached catalog leaves system speech and manual controls available', () async {
    await File('${root.path}/catalog.signed.json').writeAsString('{}');
    final store = VoiceModelStore(root, source: source);
    await store.loadCached();
    expect(store.catalog, isNull);
    expect(store.catalogRejected, isTrue);
  });
  test(
    'Catalog cancellation and concurrent refresh/install fail safely',
    () async {
      final response = Completer<http.Response>();
      final store = VoiceModelStore(
        root,
        source: source,
        clientFactory: () => MockClient((r) => response.future),
      );
      final pending = store.refresh();
      final result = expectLater(pending, throwsA(isA<DownloadCancelled>()));
      expect(store.catalogRefreshing, isTrue);
      await expectLater(store.refresh(), throwsStateError);
      await expectLater(
        store.install(VoiceModel(modelJson()), sdk: 35, abis: ['arm64-v8a']),
        throwsStateError,
      );
      store.cancel();
      response.complete(http.Response.bytes(await signedCatalog(key), 200));
      await result;
      expect(store.isBusy, isFalse);
      expect(store.catalog, isNull);
    },
  );
}
