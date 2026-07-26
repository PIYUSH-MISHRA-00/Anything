/// Kaalka service — wraps the published `package:kaalka` API.
///
/// Architecture:
///   Anything domain → ProtectionProvider → KaalkaProtectionProvider → package:kaalka → Kaalka
///
/// Only this file should import `package:kaalka/...` unless a carefully
/// documented low-level reason requires otherwise.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaalka/kaalka.dart';
import 'package:kaalka/kaalka_protocol.dart';
import 'package:kaalka/kaalka_file.dart';

/// Riverpod provider for KaalkaService.
final kaalkaServiceProvider = Provider<KaalkaService>((ref) {
  return KaalkaService();
});

/// Service wrapping the published Kaalka package API.
///
/// Provides time-based encryption/decryption using the canonical
/// Kaalka algorithm. All Kaalka-specific logic is isolated here.
class KaalkaService {
  /// Encrypt plaintext using envelope encryption.
  ///
  /// Uses senderId/receiverId model from KaalkaProtocol.
  /// Timestamp can be system UTC or custom.
  Map<String, dynamic> encryptEnvelope(
    String plaintext,
    String senderId,
    String receiverId, {
    String? timestamp,
  }) {
    return KaalkaProtocol.encryptEnvelope(
      plaintext,
      senderId,
      receiverId,
      timestamp: timestamp,
    );
  }

  /// Decrypt an envelope.
  String decryptEnvelope(
    Map<String, dynamic> envelope,
    String receiverId, {
    String? timestamp,
  }) {
    return KaalkaProtocol().decryptEnvelope(
      envelope,
      receiverId,
      timestamp: timestamp,
    );
  }

  /// Encrypt file bytes using Kaalka chunking.
  List<Map<String, dynamic>> encryptFileChunks(
    Uint8List fileBytes,
    String senderId,
    String receiverId, {
    String? timestamp,
  }) {
    return KaalkaFile.encryptFileChunks(
      fileBytes,
      senderId,
      receiverId,
      timestamp: timestamp,
    );
  }

  /// Decrypt file chunks.
  Uint8List decryptFileChunks(
    List<Map<String, dynamic>> encryptedChunks,
    String receiverId, {
    String? timestamp,
  }) {
    return KaalkaFile.decryptFileChunks(
      encryptedChunks,
      receiverId,
      timestamp: timestamp,
    );
  }

  /// Simple text encryption using the Kaalka class directly.
  ///
  /// Uses time-based key derivation.
  Future<String> encryptText(String plaintext, {String? timeKey}) async {
    final kaalka = Kaalka();
    return await kaalka.encrypt(plaintext, timeKey: timeKey);
  }

  /// Simple text decryption.
  Future<String> decryptText(String ciphertext, {String? timeKey}) async {
    final kaalka = Kaalka();
    final result = await kaalka.decrypt(ciphertext, timeKey: timeKey);
    return result.toString();
  }

  /// Encrypt a file (produces .kaalka file).
  Future<String> encryptFile(String filePath, {String? timeKey}) async {
    final kaalka = Kaalka();
    return await kaalka.encrypt(filePath, timeKey: timeKey);
  }

  /// Decrypt a file (restores original name/extension).
  Future<String> decryptFile(String kaalkaFilePath, {String? timeKey}) async {
    final kaalka = Kaalka();
    final result = await kaalka.decrypt(kaalkaFilePath, timeKey: timeKey);
    return result.toString();
  }

  /// Generate a time seed string from hours, minutes, seconds.
  String generateSeed(int hours, int minutes, int seconds) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Generate a seed from current system time.
  String generateLiveSeed() {
    final now = DateTime.now();
    return generateSeed(now.hour, now.minute, now.second);
  }
}
