import '../../attachments/attachment_store.dart';

/// Reuses the existing encrypted, streaming attachment vault in the app;
/// fixtures can supply a separate vault without touching owner media.
abstract interface class BookVault {
  Stream<List<int>> read(String id);
  Future<(String, int)> write(
    Stream<List<int>> bytes, {
    String? expected,
    int? size,
  });
}

class AppBookVault implements BookVault {
  const AppBookVault();
  @override
  Stream<List<int>> read(String id) => Attachments.read(id);
  @override
  Future<(String, int)> write(
    Stream<List<int>> bytes, {
    String? expected,
    int? size,
  }) => Attachments.write(bytes, expected: expected, size: size);
}
