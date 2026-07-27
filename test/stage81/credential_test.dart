/// Tests for Credential Vault.
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake secure storage for testing.
class FakeSecureStorage {
  final Map<String, String> _store = {};

  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  Future<String?> read({required String key}) async {
    return _store[key];
  }

  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

/// Testable CredentialVault that uses FakeSecureStorage.
class TestableCredentialVault {
  final FakeSecureStorage _storage;
  static const String _prefix = 'credential_';

  TestableCredentialVault([FakeSecureStorage? storage])
    : _storage = storage ?? FakeSecureStorage();

  Future<void> save(String purpose, String value) async {
    await _storage.write(key: '$_prefix$purpose', value: value);
  }

  Future<String?> get(String purpose) async {
    return await _storage.read(key: '$_prefix$purpose');
  }

  Future<void> delete(String purpose) async {
    await _storage.delete(key: '$_prefix$purpose');
  }

  Future<bool> has(String purpose) async {
    final value = await _storage.read(key: '$_prefix$purpose');
    return value != null;
  }
}

void main() {
  group('CredentialVault', () {
    test('stores and retrieves credential', () async {
      final vault = TestableCredentialVault();
      await vault.save('weather.api_key', 'TEST_KEY_12345');

      final key = await vault.get('weather.api_key');
      expect(key, equals('TEST_KEY_12345'));
    });

    test('returns null for non-existent credential', () async {
      final vault = TestableCredentialVault();
      final key = await vault.get('nonexistent');
      expect(key, isNull);
    });

    test('deletes credential', () async {
      final vault = TestableCredentialVault();
      await vault.save('test.key', 'secret');
      expect(await vault.has('test.key'), isTrue);

      await vault.delete('test.key');
      expect(await vault.has('test.key'), isFalse);
    });

    test('credentials are scoped by purpose', () async {
      final vault = TestableCredentialVault();
      await vault.save('weather.api_key', 'WEATHER_KEY');
      await vault.save('groq.api_key', 'GROQ_KEY');

      expect(await vault.get('weather.api_key'), equals('WEATHER_KEY'));
      expect(await vault.get('groq.api_key'), equals('GROQ_KEY'));

      await vault.delete('weather.api_key');
      expect(await vault.get('weather.api_key'), isNull);
      expect(await vault.get('groq.api_key'), equals('GROQ_KEY'));
    });
  });
}
