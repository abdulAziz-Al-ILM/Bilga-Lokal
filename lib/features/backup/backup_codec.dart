import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupCodec {
  static const maxBytes = 32 * 1024 * 1024;
  static const rounds = 600000;
  static Future<Uint8List> encrypt(
    Map<String, dynamic> payload,
    String password,
  ) => Isolate.run(() => _encrypt(payload, password));
  static Future<Map<String, dynamic>> decrypt(
    Uint8List bytes,
    String password,
  ) => Isolate.run(() => _decrypt(bytes, password));

  static Future<SecretKey> _key(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: rounds,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  static Future<Uint8List> _encrypt(
    Map<String, dynamic> payload,
    String password,
  ) async {
    if (password.runes.length < 12) {
      throw const FormatException('password_short');
    }
    final clear = utf8.encode(jsonEncode(payload));
    if (clear.length > maxBytes ~/ 2) {
      throw const FormatException('backup_large');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final header = {
      'format': 'bilga-backup',
      'version': 1,
      'kdf': 'PBKDF2-SHA256',
      'rounds': rounds,
      'salt': base64Encode(salt),
    };
    final box = await AesGcm.with256bits().encrypt(
      clear,
      secretKey: await _key(password, salt),
      aad: utf8.encode(jsonEncode(header)),
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          ...header,
          'nonce': base64Encode(box.nonce),
          'ciphertext': base64Encode(box.cipherText),
          'tag': base64Encode(box.mac.bytes),
        }),
      ),
    );
  }

  static Future<Map<String, dynamic>> _decrypt(
    Uint8List bytes,
    String password,
  ) async {
    if (bytes.length > maxBytes) throw const FormatException('backup_large');
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic> ||
        data['format'] != 'bilga-backup' ||
        data['version'] != 1 ||
        data['kdf'] != 'PBKDF2-SHA256' ||
        data['rounds'] != rounds) {
      throw const FormatException('backup_invalid');
    }
    final salt = base64Decode(data['salt'] as String);
    final nonce = base64Decode(data['nonce'] as String);
    final tag = base64Decode(data['tag'] as String);
    final cipher = base64Decode(data['ciphertext'] as String);
    if (salt.length != 16 || nonce.length != 12 || tag.length != 16) {
      throw const FormatException('backup_invalid');
    }
    final header = {
      'format': 'bilga-backup',
      'version': 1,
      'kdf': 'PBKDF2-SHA256',
      'rounds': rounds,
      'salt': data['salt'],
    };
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(tag)),
      secretKey: await _key(password, salt),
      aad: utf8.encode(jsonEncode(header)),
    );
    final result = jsonDecode(utf8.decode(clear));
    if (result is! Map<String, dynamic>) {
      throw const FormatException('backup_invalid');
    }
    return result;
  }
}
