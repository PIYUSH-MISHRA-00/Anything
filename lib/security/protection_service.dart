/// Protection Service — orchestrates Kaalka protection for Experiences.
///
/// Architecture:
///   UI (ExperienceHostScreen, OpeningCoordinator)
///   → ProtectionService
///   → ProtectionProvider (KaalkaProtectionProvider)
///   → package:kaalka
///
/// Widgets never call Kaalka directly. This service owns the full
/// protect/unprotect lifecycle and durability guarantees.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../core/contracts/protection_provider.dart';
import '../creation/experience_package.dart';
import '../creation/package_validator.dart';
import '../legacy/kaalka_adapter.dart';
import '../app/experience_commit.dart';
import '../storage/sqlite_experience_repository.dart';

/// Typed result for protection operations.
sealed class ProtectionResult {
  const ProtectionResult();
}

/// Protection succeeded and the protected envelope is persisted.
class ProtectionSucceeded extends ProtectionResult {
  final ProtectedEnvelope envelope;
  const ProtectionSucceeded({required this.envelope});
}

/// Protection failed — the original package is preserved untouched.
class ProtectionFailed extends ProtectionResult {
  final String message;
  const ProtectionFailed({required this.message});
}

/// A Kaalka-protected envelope stored alongside the experience.
///
/// Contains only what is needed to reopen: the ciphertext, the seed
/// descriptor, and a content hash of the original package for integrity
/// verification after unprotection.
class ProtectedEnvelope {
  /// The Kaalka-produced ciphertext (JSON-encoded envelope).
  final String ciphertext;

  /// The TimeSeed used during protection.
  final TimeSeed seed;

  /// SHA-256 hash of the original unprotected package JSON, for
  /// post-unprotection integrity verification.
  final String originalContentHash;

  /// When protection occurred.
  final DateTime protectedAt;

  const ProtectedEnvelope({
    required this.ciphertext,
    required this.seed,
    required this.originalContentHash,
    required this.protectedAt,
  });

  Map<String, dynamic> toJson() => {
    'ciphertext': ciphertext,
    'seed': {'h': seed.hours, 'm': seed.minutes, 's': seed.seconds},
    'originalContentHash': originalContentHash,
    'protectedAt': protectedAt.toIso8601String(),
  };

  factory ProtectedEnvelope.fromJson(Map<String, dynamic> json) {
    final seedMap = json['seed'] as Map<String, dynamic>;
    return ProtectedEnvelope(
      ciphertext: json['ciphertext'] as String,
      seed: TimeSeed(
        hours: seedMap['h'] as int,
        minutes: seedMap['m'] as int,
        seconds: seedMap['s'] as int,
      ),
      originalContentHash: json['originalContentHash'] as String,
      protectedAt: DateTime.parse(json['protectedAt'] as String),
    );
  }

  /// Serialize envelope to a JSON string for storage.
  String serialize() => jsonEncode(toJson());

  /// Deserialize a JSON string back to an envelope.
  static ProtectedEnvelope deserialize(String json) =>
      ProtectedEnvelope.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

/// Typed result for unprotection operations.
sealed class UnprotectionResult {
  const UnprotectionResult();
}

/// Unprotection succeeded — package is validated and ready for Runtime.
class UnprotectionSucceeded extends UnprotectionResult {
  final ExperiencePackage package;
  final String experienceId;
  final String experienceName;
  const UnprotectionSucceeded({
    required this.package,
    required this.experienceId,
    required this.experienceName,
  });
}

/// Unprotection failed — wrong time input or corrupted data.
class UnprotectionFailed extends UnprotectionResult {
  final String message;
  const UnprotectionFailed({required this.message});
}

/// The Experience is not actually protected — no unprotection needed.
class UnprotectionNotProtected extends UnprotectionResult {
  final ExperiencePackage package;
  final String experienceId;
  final String experienceName;
  const UnprotectionNotProtected({
    required this.package,
    required this.experienceId,
    required this.experienceName,
  });
}

/// Orchestrates Kaalka protection and unprotection for Experiences.
///
/// Production: uses real KaalkaProtectionProvider.
/// Tests: can be constructed with a fake ProtectionProvider.
class ExperienceProtectionService {
  final ProtectionProvider _provider;
  final SqliteExperienceRepository _repository;

  /// The ONE commit owner (IS-R55 Task 5). Protection still owns the crypto —
  /// it is the only thing in this system that encrypts — but it no longer owns
  /// persistence. It hands finished ciphertext over to be written.
  final ExperienceCommitFramework _commits;

  ExperienceProtectionService({
    ProtectionProvider? provider,
    SqliteExperienceRepository? repository,
    ExperienceCommitFramework? commitFramework,
  }) : _provider = provider ?? KaalkaProtectionProvider(),
       _repository = repository ?? SqliteExperienceRepository(),
       _commits =
           commitFramework ??
           ExperienceCommitFramework(
             repository: repository ?? SqliteExperienceRepository(),
           );

  /// Expose the provider for testing/introspection.
  ProtectionProvider get provider => _provider;

  /// Protect a package using the current system time.
  Future<ProtectionResult> protectWithCurrentTime({
    required ExperiencePackage package,
    required String experienceId,
  }) async {
    final seed = _provider.getCurrentSeed();
    return _protect(package: package, experienceId: experienceId, seed: seed);
  }

  /// Protect a package using a custom date/time.
  Future<ProtectionResult> protectWithCustomTime({
    required ExperiencePackage package,
    required String experienceId,
    required DateTime customTime,
  }) async {
    final seed = TimeSeed(
      hours: customTime.hour,
      minutes: customTime.minute,
      seconds: customTime.second,
    );
    return _protect(package: package, experienceId: experienceId, seed: seed);
  }

  /// Core protection operation.
  Future<ProtectionResult> _protect({
    required ExperiencePackage package,
    required String experienceId,
    required TimeSeed seed,
  }) async {
    try {
      // 1. Compute the content hash of the original package for integrity.
      final packageJson = jsonEncode(package.toJson());
      final originalHash = sha256.convert(utf8.encode(packageJson)).toString();

      // 2. Serialize the package to plaintext, Base64-encode to preserve
      //    Unicode characters through Kaalka's text encryption.
      final plaintext = base64Encode(utf8.encode(packageJson));

      // 3. Use the Kaalka provider to encrypt with the time seed.
      final config = ProtectionConfig(
        enabled: true,
        timeSeedMode: TimeSeedMode.custom,
        customTimeSeed: seed,
      );
      await _provider.updateConfig(config);

      final ciphertext = await _provider.encrypt(plaintext);

      // 4. Build the protected envelope.
      final envelope = ProtectedEnvelope(
        ciphertext: ciphertext,
        seed: seed,
        originalContentHash: originalHash,
        protectedAt: DateTime.now(),
      );

      // 5. IS-R55 TASK 5 — PROTECTION PREPARES, THE COMMIT FRAMEWORK COMMITS.
      //
      // These were three sequential writes: store the envelope, flip the flag,
      // drop the plaintext. A failure between the second and third left an
      // Experience MARKED PROTECTED WITH ITS PLAINTEXT STILL ON DISK — the
      // worst torn state in the system, because it looks secure and is not.
      //
      // They now land inside ONE transaction. Either the whole protection is
      // durable or none of it is. Protection still performs every byte of the
      // crypto above; it just no longer writes.
      final committed = await _commits.commitProtection(
        experienceId: experienceId,
        serializedEnvelope: envelope.serialize(),
      );
      if (!committed.succeeded) {
        return ProtectionFailed(
          message:
              'Protection failed: ${committed.error ?? "could not be saved"}',
        );
      }

      return ProtectionSucceeded(envelope: envelope);
    } catch (e) {
      // Protection failed — original package remains untouched.
      return ProtectionFailed(message: 'Protection failed: ${e.toString()}');
    }
  }

  /// Unprotect a package using the specified time seed.
  ///
  /// Returns the decrypted and validated ExperiencePackage if successful.
  Future<UnprotectionResult> unprotect({
    required String experienceId,
    required TimeSeed timeSeed,
  }) async {
    // 1. Load metadata.
    final metadata = await _repository.getMetadata(experienceId);
    if (metadata == null) {
      return const UnprotectionFailed(message: 'App not found');
    }

    // 2. Load the protected envelope.
    final envelopeJson = await _repository.getProtectedEnvelope(experienceId);
    if (envelopeJson == null) {
      // Not actually protected — load the plaintext package directly.
      final package = await _repository.getPackage(experienceId);
      if (package == null) {
        return const UnprotectionFailed(message: 'App data not found');
      }
      return UnprotectionNotProtected(
        package: package,
        experienceId: experienceId,
        experienceName: metadata.name,
      );
    }

    // Deserialize the envelope.
    final envelope = envelopeJson is String
        ? ProtectedEnvelope.deserialize(envelopeJson)
        : envelopeJson as ProtectedEnvelope;

    // 3. Attempt decryption with the supplied time seed.
    try {
      final config = ProtectionConfig(
        enabled: true,
        timeSeedMode: TimeSeedMode.custom,
        customTimeSeed: timeSeed,
      );
      await _provider.updateConfig(config);

      final decryptedBase64 = await _provider.decrypt(envelope.ciphertext);
      final decryptedJson = utf8.decode(base64Decode(decryptedBase64));

      // 4. Parse the candidate package.
      final candidateMap = jsonDecode(decryptedJson) as Map<String, dynamic>;
      final candidatePackage = ExperiencePackage.fromJson(candidateMap);

      // 5. Verify integrity — compare content hash.
      final candidateJson = jsonEncode(candidatePackage.toJson());
      final candidateHash = sha256
          .convert(utf8.encode(candidateJson))
          .toString();

      if (candidateHash != envelope.originalContentHash) {
        return const UnprotectionFailed(
          message: 'Integrity check failed — data may be corrupted',
        );
      }

      // 6. Validate with the package validator.
      final validation = ExperiencePackageValidator.validate(candidatePackage);
      if (!validation.isValid) {
        return const UnprotectionFailed(
          message: 'Package validation failed after unprotection',
        );
      }

      // 7. IS-R55 Task 5 — the commit framework persists the recovered package.
      await _commits.commitUnprotection(
        experienceId: experienceId,
        package: candidatePackage,
      );

      return UnprotectionSucceeded(
        package: candidatePackage,
        experienceId: experienceId,
        experienceName: metadata.name,
      );
    } catch (e) {
      // Wrong time seed or decryption failure.
      return const UnprotectionFailed(
        message: 'Wrong protection key — try a different time',
      );
    }
  }
}
