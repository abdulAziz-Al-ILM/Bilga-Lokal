import 'dart:convert';
import 'dart:io';

import 'package:bilga/features/agent/core_purchase_verifier.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Python backend grants verify in Dart with exact receipt and device binding', () async {
    final fixture = jsonDecode(
      File('test/fixtures/purchase_verifier_grant.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final request = fixture['request'] as Map<String, dynamic>;
    final server = CorePurchaseVerifier(
      publicKey: fixture['publicKey'] as String,
    );
    for (final status in ['purchased', 'revoked']) {
      final grant = fixture[status] as Map<String, dynamic>;
      expect(
        await server.check(
          grant,
          receipt: request['receipt'] as String,
          product: request['productId'] as String,
          installation: request['installation'] as String,
        ),
        status,
      );
      expect(
        await server.check(
          grant,
          receipt: '${request['receipt']} ',
          product: request['productId'] as String,
          installation: request['installation'] as String,
        ),
        isNull,
      );
    }
  });
  late SimpleKeyPair pair;
  late CorePurchaseVerifier verifier;
  const receipt = '{"purchaseToken":"test-token"}';
  const product = 'bilga_core_lifetime', installation = 'test-install';
  Future<Map<String, dynamic>> grant({
    Map<String, Object>? change,
    SimpleKeyPair? signer,
  }) async {
    final payload = jsonEncode({
      'version': 1,
      'packageName': 'com.ilmmizan.bilga',
      'productId': product,
      'installation': installation,
      'receiptSha256': sha256.convert(utf8.encode(receipt)).toString(),
      'entitlement': 'lifetime',
      'status': 'purchased',
      ...?change,
    });
    return {
      'payload': payload,
      'signature': base64Encode(
        (await Ed25519().sign(
          utf8.encode(payload),
          keyPair: signer ?? pair,
        )).bytes,
      ),
    };
  }

  Future<String?> check(Map<String, dynamic> g) => verifier.check(
    g,
    receipt: receipt,
    product: product,
    installation: installation,
  );
  setUp(() async {
    pair = await Ed25519().newKeyPair();
    verifier = CorePurchaseVerifier(
      endpoint: 'https://billing.example.org/verify',
      publicKey: base64Encode((await pair.extractPublicKey()).bytes),
    );
  });
  test('Only a pinned, correctly bound lifetime grant is trusted', () async {
    expect(verifier.configured, isTrue);
    expect(await check(await grant()), 'purchased');
  });
  for (final field in {
    'version': 2,
    'packageName': 'attacker.app',
    'productId': 'other',
    'installation': 'other-device',
    'receiptSha256': 'different',
    'entitlement': 'trial',
    'status': 'pending',
  }.entries) {
    test('Rejects signed grant with mismatching ${field.key}', () async {
      expect(
        await check(await grant(change: {field.key: field.value})),
        isNull,
      );
    });
  }
  test(
    'Wrong signing key, malformed or edited payload cannot grant access',
    () async {
      expect(
        await check(await grant(signer: await Ed25519().newKeyPair())),
        isNull,
      );
      final g = await grant();
      g['payload'] = '${g['payload']} ';
      expect(await check(g), isNull);
      expect(await check({'payload': 'bad', 'signature': 'bad'}), isNull);
    },
  );
  test(
    'Explicit revocation must be signed and bound to the same receipt',
    () async {
      expect(
        await check(await grant(change: {'status': 'revoked'})),
        'revoked',
      );
      final g = await grant();
      g['payload'] = (g['payload'] as String).replaceAll(
        'purchased',
        'revoked',
      );
      expect(await check(g), isNull);
    },
  );
  test(
    'Missing configuration/HTTP endpoint never bypasses verification',
    () async {
      expect(CorePurchaseVerifier().configured, isFalse);
      expect(
        CorePurchaseVerifier(
          endpoint: 'http://billing.example.org',
          publicKey: verifier.publicKey,
        ).configured,
        isFalse,
      );
      await expectLater(
        CorePurchaseVerifier().request(
          receipt: receipt,
          signature: 'sig',
          product: product,
          installation: installation,
        ),
        throwsStateError,
      );
    },
  );
  test('Request sends license metadata only; response is still untrusted until signature check', () async {
    final client = MockClient((request) async {
      expect(request.url.scheme, 'https');
      expect(jsonDecode(request.body), {
        'packageName': 'com.ilmmizan.bilga',
        'productId': product,
        'receipt': receipt,
        'signature': 'sig',
        'installation': installation,
      });
      return http.Response(jsonEncode(await grant()), 200);
    });
    verifier = CorePurchaseVerifier(
      endpoint: verifier.endpoint,
      publicKey: verifier.publicKey,
      client: client,
    );
    final response = await verifier.request(
      receipt: receipt,
      signature: 'sig',
      product: product,
      installation: installation,
    );
    expect(await check(response), 'purchased');
  });
  test('Server error cannot be confused with a purchase', () async {
    final service = CorePurchaseVerifier(
      endpoint: verifier.endpoint,
      publicKey: verifier.publicKey,
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    await expectLater(
      service.request(
        receipt: receipt,
        signature: 'sig',
        product: product,
        installation: installation,
      ),
      throwsStateError,
    );
  });
  test(
    'Redirects and oversized responses cannot be accepted as verification',
    () async {
      for (final response in [
        http.Response('', 302),
        http.Response('x' * 16385, 200),
      ]) {
        final service = CorePurchaseVerifier(
          endpoint: verifier.endpoint,
          publicKey: verifier.publicKey,
          client: MockClient((request) async {
            expect(request.followRedirects, isFalse);
            return response;
          }),
        );
        await expectLater(
          service.request(
            receipt: receipt,
            signature: 'sig',
            product: product,
            installation: installation,
          ),
          throwsStateError,
        );
      }
    },
  );
}
