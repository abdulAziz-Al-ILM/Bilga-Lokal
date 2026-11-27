import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

/// A server attestation is required for NEW Core purchases. The backend must
/// query Google Play Developer API and acknowledge before signing this grant.
/// Existing Google-signed legacy receipts retain their old offline semantics.
class CorePurchaseVerifier {
  static const configuredEndpoint = String.fromEnvironment(
    'BILGA_BILLING_VERIFY_URL',
  );
  static const configuredKey = String.fromEnvironment(
    'BILGA_BILLING_VERIFY_KEY',
  );
  final String endpoint, publicKey;
  final http.Client client;
  CorePurchaseVerifier({
    this.endpoint = configuredEndpoint,
    this.publicKey = configuredKey,
    http.Client? client,
  }) : client = client ?? http.Client();

  bool get configured {
    final uri = Uri.tryParse(endpoint);
    try {
      return uri?.scheme == 'https' &&
          uri!.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          uri.fragment.isEmpty &&
          base64Decode(publicKey).length == 32;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> request({
    required String receipt,
    required String signature,
    required String product,
    required String installation,
  }) async {
    if (!configured) throw StateError('billing_not_configured');
    final request = http.Request('POST', Uri.parse(endpoint))
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'packageName': 'com.ilmmizan.bilga',
        'productId': product,
        'receipt': receipt,
        'signature': signature,
        'installation': installation,
      });
    return (() async {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        await response.stream.listen(null).cancel();
        throw StateError('billing_verification_unavailable');
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > 16384) {
          throw StateError('billing_response_size');
        }
        bytes.addAll(chunk);
      }
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    })().timeout(const Duration(seconds: 15));
  }

  /// Returns purchased/revoked only for a signed, correctly bound attestation.
  /// The signature covers the exact UTF-8 payload, never re-serialized JSON.
  Future<String?> check(
    Map<String, dynamic> grant, {
    required String receipt,
    required String product,
    required String installation,
  }) async {
    try {
      if (base64Decode(publicKey).length != 32) return null;
      final payload = grant['payload'] as String;
      if (payload.length > 8192) return null;
      final valid = await Ed25519().verify(
        utf8.encode(payload),
        signature: Signature(
          base64Decode(grant['signature'] as String),
          publicKey: SimplePublicKey(
            base64Decode(publicKey),
            type: KeyPairType.ed25519,
          ),
        ),
      );
      if (!valid) return null;
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['version'] != 1 ||
          data['packageName'] != 'com.ilmmizan.bilga' ||
          data['productId'] != product ||
          data['installation'] != installation ||
          data['receiptSha256'] !=
              sha256.convert(utf8.encode(receipt)).toString() ||
          data['entitlement'] != 'lifetime' ||
          !{'purchased', 'revoked'}.contains(data['status'])) {
        return null;
      }
      return data['status'] as String;
    } catch (_) {
      return null;
    }
  }
}
