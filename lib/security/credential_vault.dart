/// Credential Vault — secure storage for API keys and secrets.
///
/// Backed by FlutterSecureStorage (AES-GCM / platform Keychain). Writes are
/// verified by read-back so a silent keystore failure cannot look like a
/// successful Save.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A stored credential.
class StoredCredential {
  final String purpose;
  final String service;
  final String createdAt;
  const StoredCredential({
    required this.purpose,
    required this.service,
    required this.createdAt,
  });
}

/// Secure credential storage.
class CredentialVault {
  final FlutterSecureStorage _storage;
  static const String _prefix = 'credential_';

  /// Production defaults for API keys (no biometric gate — keys must load at
  /// cold start so creation works immediately after Save).
  static FlutterSecureStorage productionStorage() => const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
      migrateOnAlgorithmChange: true,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  CredentialVault({FlutterSecureStorage? storage})
    : _storage = storage ?? productionStorage();

  /// Save a credential and verify it can be read back.
  Future<void> save(String purpose, String value) async {
    final key = '$_prefix$purpose';
    await _storage.write(key: key, value: value);
    final check = await _storage.read(key: key);
    if (check != value) {
      throw StateError(
        'Credential could not be persisted securely. '
        'Try again or reinstall if the problem continues.',
      );
    }
  }

  /// Get a credential.
  Future<String?> get(String purpose) async {
    return await _storage.read(key: '$_prefix$purpose');
  }

  /// Delete a credential.
  Future<void> delete(String purpose) async {
    await _storage.delete(key: '$_prefix$purpose');
  }

  /// Check if a credential exists.
  Future<bool> has(String purpose) async {
    final value = await _storage.read(key: '$_prefix$purpose');
    return value != null && value.isNotEmpty;
  }
}
