/// Credential Vault — secure storage for API keys and secrets.
///
/// Primary store: FlutterSecureStorage (platform keystore).
/// Writes are verified by read-back and timed out so a wedged Android
/// keystore cannot freeze Test/Save forever. On repeated keystore failure
/// (seen on some Android 12 devices as keystore2 ResponseCode 18 during
/// keyblob upgrade), credentials fall back to private app SharedPreferences
/// so BYOK still works — less hardened than the keystore, but preferable to
/// a dead configuration sheet.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _fallbackPrefix = 'anything.credential_fallback.';
  static const Duration _ioTimeout = Duration(seconds: 5);

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
    try {
      await _writeAndVerify(key, value);
      await _clearFallback(purpose);
      return;
    } catch (_) {
      try {
        await _storage.deleteAll().timeout(_ioTimeout);
      } catch (_) {}
    }

    try {
      await _writeAndVerify(key, value);
      await _clearFallback(purpose);
      return;
    } catch (_) {
      await _writeFallback(purpose, value);
    }
  }

  Future<void> _writeAndVerify(String key, String value) async {
    await _storage.write(key: key, value: value).timeout(_ioTimeout);
    final check = await _storage.read(key: key).timeout(_ioTimeout);
    if (check != value) {
      throw StateError('Credential read-back did not match what was written.');
    }
  }

  Future<void> _writeFallback(String purpose, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString('$_fallbackPrefix$purpose', value);
    if (!ok) {
      throw StateError(
        'Credential could not be persisted on this device. '
        'Try again or reinstall if the problem continues.',
      );
    }
  }

  Future<void> _clearFallback(String purpose) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_fallbackPrefix$purpose');
    } catch (_) {}
  }

  /// Get a credential.
  Future<String?> get(String purpose) async {
    try {
      final fromStore = await _storage
          .read(key: '$_prefix$purpose')
          .timeout(_ioTimeout);
      if (fromStore != null && fromStore.isNotEmpty) return fromStore;
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_fallbackPrefix$purpose');
    } catch (_) {
      return null;
    }
  }

  /// Delete a credential.
  Future<void> delete(String purpose) async {
    try {
      await _storage.delete(key: '$_prefix$purpose').timeout(_ioTimeout);
    } catch (_) {}
    await _clearFallback(purpose);
  }

  /// Check if a credential exists.
  Future<bool> has(String purpose) async {
    final value = await get(purpose);
    return value != null && value.isNotEmpty;
  }
}
