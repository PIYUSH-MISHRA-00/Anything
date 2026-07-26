/// Experience Opening Coordinator — trusted production opening flow.
///
/// Single entry point for opening an Experience from any source.
/// Ensures protection/integrity/validation before Runtime.
library;

import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/package_validator.dart'
    show ExperiencePackageValidator;
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:anything/storage/activity_repository.dart';
import 'package:anything/security/protection_service.dart';
import 'package:anything/core/contracts/protection_provider.dart';

/// Typed result for Experience opening.
sealed class OpenResult {
  const OpenResult();
}

/// Experience is ready to open.
class OpenReady extends OpenResult {
  final ExperiencePackage package;
  final String experienceId;
  final String experienceName;
  const OpenReady({
    required this.package,
    required this.experienceId,
    required this.experienceName,
  });
}

/// Experience requires time input for protection unsealing.
class OpenProtectionInputRequired extends OpenResult {
  final String experienceId;
  final String experienceName;
  final bool needsTimeInput;
  const OpenProtectionInputRequired({
    required this.experienceId,
    required this.experienceName,
    this.needsTimeInput = true,
  });
}

/// Experience not found.
class OpenNotFound extends OpenResult {
  final String message;
  const OpenNotFound({required this.message});
}

/// Experience package invalid.
class OpenInvalid extends OpenResult {
  final String message;
  const OpenInvalid({required this.message});
}

/// Opening failed.
class OpenFailed extends OpenResult {
  final String message;
  const OpenFailed({required this.message});
}

/// Trusted Experience opening service.
///
/// Used by Home Recent, My Apps, and natural-language Open.
/// Ensures protection/integrity/validation before Runtime.
class ExperienceOpeningCoordinator {
  final SqliteExperienceRepository _repository;
  final ActivityRepository _activity;
  final ExperienceProtectionService _protectionService;

  ExperienceOpeningCoordinator({
    SqliteExperienceRepository? repository,
    ActivityRepository? activity,
    ExperienceProtectionService? protectionService,
  }) : _repository = repository ?? SqliteExperienceRepository(),
       _activity = activity ?? ActivityRepository(),
       _protectionService = protectionService ?? ExperienceProtectionService();

  /// Open an Experience by its ID.
  ///
  /// If the Experience is protected, returns [OpenProtectionInputRequired]
  /// so the UI can collect time input before resuming through
  /// [openProtectedExperienceWithSeed].
  Future<OpenResult> openExperience(String experienceId) async {
    // 1. Load metadata
    final metadata = await _repository.getMetadata(experienceId);
    if (metadata == null) {
      return const OpenNotFound(message: 'App not found');
    }

    // 2. Check protection state from metadata (not Activity history).
    if (metadata.isProtected) {
      // Protected Experience — check if envelope exists.
      final envelope = await _repository.getProtectedEnvelope(experienceId);
      if (envelope != null) {
        return OpenProtectionInputRequired(
          experienceId: experienceId,
          experienceName: metadata.name,
        );
      }
    }

    // 3. Load package
    final package = await _repository.getPackage(experienceId);
    if (package == null) {
      return const OpenNotFound(message: 'App data not found');
    }

    // 4. Validate integrity
    final validation = ExperiencePackageValidator.validate(package);
    if (!validation.isValid) {
      return OpenInvalid(message: 'App data is corrupted');
    }

    // 5. Record activity (single canonical Opened emission point)
    await _activity.record(
      ActivityEvent(
        id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
        type: 'opened',
        experienceId: experienceId,
        experienceName: metadata.name,
        message: 'Opened ${metadata.name}',
        timestamp: DateTime.now(),
      ),
    );

    // 6. Touch last used
    await _repository.touchLastUsed(experienceId);

    return OpenReady(
      package: package,
      experienceId: experienceId,
      experienceName: metadata.name,
    );
  }

  /// Open a protected Experience with a specific time seed.
  ///
  /// Performs real Kaalka unprotection, integrity verification, and
  /// validation before returning an [OpenReady].
  Future<OpenResult> openProtectedExperienceWithSeed({
    required String experienceId,
    required TimeSeed timeSeed,
  }) async {
    final result = await _protectionService.unprotect(
      experienceId: experienceId,
      timeSeed: timeSeed,
    );

    switch (result) {
      case UnprotectionSucceeded():
        // Validate the unprotected package
        final validation = ExperiencePackageValidator.validate(result.package);
        if (!validation.isValid) {
          return const OpenInvalid(message: 'App data is corrupted');
        }

        // Record activity (single canonical Opened emission point)
        await _activity.record(
          ActivityEvent(
            id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
            type: 'opened',
            experienceId: experienceId,
            experienceName: result.experienceName,
            message: 'Opened ${result.experienceName}',
            timestamp: DateTime.now(),
          ),
        );

        // Touch last used
        await _repository.touchLastUsed(experienceId);

        return OpenReady(
          package: result.package,
          experienceId: experienceId,
          experienceName: result.experienceName,
        );

      case UnprotectionFailed():
        return OpenFailed(message: result.message);

      case UnprotectionNotProtected():
        // Should not reach here if metadata.isProtected was true,
        // but handle gracefully: treat as unprotected.
        final validation = ExperiencePackageValidator.validate(result.package);
        if (!validation.isValid) {
          return const OpenInvalid(message: 'App data is corrupted');
        }

        await _activity.record(
          ActivityEvent(
            id: 'evt-${DateTime.now().millisecondsSinceEpoch}',
            type: 'opened',
            experienceId: experienceId,
            experienceName: result.experienceName,
            message: 'Opened ${result.experienceName}',
            timestamp: DateTime.now(),
          ),
        );

        await _repository.touchLastUsed(experienceId);

        return OpenReady(
          package: result.package,
          experienceId: experienceId,
          experienceName: result.experienceName,
        );
    }
  }
}
