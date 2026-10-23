import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/data/secrets/secure_secret_store.dart';
import 'package:simulator_psikotes_it/domain/services/secret_store.dart';

void main() {
  group('SecureSecretStore (Android)', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('tulis, baca, dan hapus lewat penyimpanan aman', () async {
      final store = SecureSecretStore();
      expect(store.persistent, isTrue);
      expect(await store.read('api_key_gemini'), isNull);
      await store.write('api_key_gemini', 'AIza-rahasia');
      expect(await store.read('api_key_gemini'), 'AIza-rahasia');
      expect(await store.read('api_key_groq'), isNull,
          reason: 'tiap penyedia punya key sendiri');
      await store.delete('api_key_gemini');
      expect(await store.read('api_key_gemini'), isNull);
    });
  });

  group('MemorySecretStore (web)', () {
    test('hanya di memori: tidak bertahan, tidak dibagi antar instance',
        () async {
      final a = MemorySecretStore();
      expect(a.persistent, isFalse);
      await a.write('api_key_groq', 'gsk-rahasia');
      expect(await a.read('api_key_groq'), 'gsk-rahasia');
      expect(await MemorySecretStore().read('api_key_groq'), isNull,
          reason: 'tab baru mulai kosong');
      await a.delete('api_key_groq');
      expect(await a.read('api_key_groq'), isNull);
    });
  });

  group('AiProvider', () {
    test('kode dan nama rahasia per penyedia', () {
      expect(AiProvider.fromCode('gemini'), AiProvider.gemini);
      expect(AiProvider.fromCode('groq'), AiProvider.groq);
      expect(AiProvider.fromCode(null), isNull);
      expect(AiProvider.fromCode('lain'), isNull);
      expect(AiProvider.gemini.secretName, 'api_key_gemini');
      expect(AiProvider.groq.secretName, 'api_key_groq');
    });
  });
}
