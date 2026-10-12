import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'backup_codec.dart';

class DriveService {
  static final instance = DriveService();
  static const clientId = String.fromEnvironment('BILGA_GOOGLE_WEB_CLIENT_ID');
  static const scopes = ['https://www.googleapis.com/auth/drive.appdata'];
  Future<void>? _initializing;
  GoogleSignInAccount? user;
  final http.Client _http = http.Client();

  Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object error) {
        _initializing = null;
        throw error;
      });
  Future<void> _initialize() async {
    if (clientId.isEmpty) throw StateError('google_setup');
    await GoogleSignIn.instance.initialize(serverClientId: clientId);
    GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignOut) user = null;
        if (event is GoogleSignInAuthenticationEventSignIn) user = event.user;
      },
      onError: (Object _) {
        user = null;
      },
    );
  }

  Future<GoogleSignInAccount> connect() async {
    await initialize();
    user = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    return user!;
  }

  Future<void> disconnect() async {
    await initialize();
    await GoogleSignIn.instance.disconnect();
    user = null;
  }

  Future<Map<String, String>> _headers() async {
    await initialize();
    final account = user;
    if (account == null) throw StateError('sign_in');
    final auth =
        await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);
    return {'Authorization': 'Bearer ${auth.accessToken}'};
  }

  static String errorKey(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return 'gNetwork';
    }
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          return 'gCanceled';
        case GoogleSignInExceptionCode.clientConfigurationError:
          return 'googleSetup';
        case GoogleSignInExceptionCode.providerConfigurationError:
          return 'googleSetup';
        default:
          return 'gAuth';
      }
    }
    final message = error.toString();
    if (message.contains('google_setup')) return 'googleSetup';
    if (message.contains('drive_403')) return 'gPermission';
    if (message.contains('drive_401') || message.contains('sign_in')) {
      return 'gAuth';
    }
    if (message.contains('drive_429') || message.contains('drive_5')) {
      return 'gUnavailable';
    }
    if (message.contains('password_short')) return 'passwordRule';
    if (message.contains('account_mismatch')) return 'accountMismatch';
    return 'backupError';
  }

  Future<List<Map<String, dynamic>>> backups() async {
    final headers = await _headers();
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'spaces': 'appDataFolder',
      'q': "trashed = false and appProperties has { key='bilga' and value='backup-v1' }",
      'fields': 'files(id,name,createdTime,size)',
      'orderBy': 'createdTime desc',
      'pageSize': '50',
    });
    final result = await _http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));
    if (result.statusCode != 200) {
      throw StateError('drive_${result.statusCode}');
    }
    final body = jsonDecode(result.body) as Map<String, dynamic>;
    return (body['files'] as List)
        .map((f) => Map<String, dynamic>.from(f as Map))
        .toList();
  }

  Future<Uint8List> download(String id) async {
    final uri = Uri.https(
      'www.googleapis.com',
      '/drive/v3/files/${Uri.encodeComponent(id)}',
      {'alt': 'media'},
    );
    final request = http.Request('GET', uri)..headers.addAll(await _headers());
    final response = await _http
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw StateError('drive_${response.statusCode}');
    }
    if ((response.contentLength ?? 0) > BackupCodec.maxBytes) {
      throw const FormatException('backup_large');
    }
    final bytes = BytesBuilder(copy: false);
    var size = 0;
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      size += chunk.length;
      if (size > BackupCodec.maxBytes) {
        throw const FormatException('backup_large');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  Future<String> upload(Uint8List bytes) async {
    if (bytes.length > BackupCodec.maxBytes) {
      throw const FormatException('backup_large');
    }
    final boundary = 'bilga_${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': 'Bilga-${DateTime.now().toUtc().toIso8601String()}.bilga',
      'parents': ['appDataFolder'],
      'appProperties': {'bilga': 'backup-v1'},
    });
    final body = BytesBuilder(copy: false)
      ..add(
        utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n'
          '--$boundary\r\nContent-Type: application/octet-stream\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    final result = await _http
        .post(
          Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
            'uploadType': 'multipart',
            'fields': 'id',
          }),
          headers: {
            ...await _headers(),
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: body.takeBytes(),
        )
        .timeout(const Duration(minutes: 2));
    if (result.statusCode != 200 && result.statusCode != 201) {
      throw StateError('drive_${result.statusCode}');
    }
    final id =
        (jsonDecode(result.body) as Map<String, dynamic>)['id'] as String;
    // Do not declare success until the uploaded encrypted file is readable and identical.
    final returned = await download(id);
    if (returned.length != bytes.length) throw StateError('backup_verify');
    var diff = 0;
    for (var i = 0; i < bytes.length; i++) {
      diff |= returned[i] ^ bytes[i];
    }
    if (diff != 0) throw StateError('backup_verify');
    return id;
  }
}
