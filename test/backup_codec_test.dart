import 'dart:convert';
import 'dart:typed_data';

import 'package:bilga/features/backup/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Encrypted backup round trip, wrong password and tampering', () async {
    const password = 'Bilga test password 2026';
    final payload = <String, dynamic>{
      'notes': ['  matn\n😀'],
      'version': 1,
    };
    final encrypted = await BackupCodec.encrypt(payload, password);
    expect(utf8.decode(encrypted), isNot(contains('matn')));
    expect(await BackupCodec.decrypt(encrypted, password), payload);
    await expectLater(
      BackupCodec.decrypt(encrypted, 'wrong password'),
      throwsA(anything),
    );
    final data = jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
    final tag = base64Decode(data['tag'] as String);
    tag[0] ^= 1;
    data['tag'] = base64Encode(tag);
    await expectLater(
      BackupCodec.decrypt(
        Uint8List.fromList(utf8.encode(jsonEncode(data))),
        password,
      ),
      throwsA(anything),
    );
    data['rounds'] = 1;
    await expectLater(
      BackupCodec.decrypt(
        Uint8List.fromList(utf8.encode(jsonEncode(data))),
        password,
      ),
      throwsFormatException,
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
  test('Short passwords are rejected', () async {
    await expectLater(BackupCodec.encrypt({}, 'short'), throwsFormatException);
  });
}
