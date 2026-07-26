/// Credential Vault — secure storage for API keys and secrets.
///
/// Backed by FlutterSecureStorage.
/// Credentials are scoped by purpose/service.
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

  CredentialVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Save a credential.
  Future<void> save(String purpose, String value) async {
    await _storage.write(key: '$_prefix$purpose', value: value);
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
    return value != null;
  }
}
