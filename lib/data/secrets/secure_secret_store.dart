import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/services/secret_store.dart';

/// Android: `flutter_secure_storage` (Keystore). Web: hanya di memori, hilang
/// saat tab ditutup (docs/02-arsitektur.md).
SecretStore createSecretStore() =>
    kIsWeb ? MemorySecretStore() : SecureSecretStore();

class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  bool get persistent => true;

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);

  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}
