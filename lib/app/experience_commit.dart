/// Experience Commit Framework — Implementation Specification IS-R55.
/// The ONE owner of writing an Experience to the repository.
///
/// WHAT THIS CLOSES.
///
/// IS-R54 established an installer and rerouted distribution's commit through
/// it, then recorded — as gap G-30, severity A — that FOUR other paths still
/// wrote to the repository on their own terms. The Task 1 audit for R55 found
/// them exactly where R54 said they were:
///
///     creation_coordinator.dart:442-443            savePackage + saveMetadata
///     experience_modification_coordinator.dart     savePackage x3 (incl. rollback)
///     evolution_coordinator.dart:79                savePackage
///     security/protection_service.dart:203-210,289 envelope + flag + deletePackage
///     experience_installation.dart                 savePackage/saveMetadata/delete
///     features/experiences/experiences_screen.dart:270   delete   <- a UI screen
///
/// The last one was not in R54's list. A repository-wide audit found a UI
/// screen deleting an Experience directly, which is why Task 1 says "search
/// every coordinator, manager, service, runtime" and not "check the four we
/// know about".
///
/// After R55 there is exactly one writer of Experience state, and certification
/// forbids the others from even naming a write method (I-68 … I-74).
///
/// WHAT THIS OWNS, AND NOTHING ELSE.
///
///     ExperienceCommitFramework   COMMITS, ROLLS BACK, REPAIRS   (this file)
///     SqliteExperienceRepository  STORES                          canonical
///     ExperienceInstallationFramework  INSTALLS                   R54
///     ExperienceDistributionFramework  MOVES                      R53
///     ExperienceTrustClassifier   COMPUTES trust                  R52
///     OperatingSystemGovernanceEngine  DECIDES                    R51
///     CapabilityPlatform          ENFORCES                        R49/R51
///     ExperienceEntryPipeline     ACTIVATES                       R45
///     ExperienceProtectionService PROTECTS (crypto)                Kaalka
///     MigrationExecutor           MIGRATES                        canonical
///
/// This framework creates nothing, installs nothing, imports nothing, modifies
/// nothing, evolves nothing, encrypts nothing, evaluates no compatibility,
/// plans no dependencies, runs no migration, activates no runtime and enforces
/// no policy. It receives finished state and durably writes it.
library;

import 'package:sqflite/sqflite.dart' show DatabaseExecutor;

import '../creation/experience_package.dart';
import '../storage/sqlite_experience_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TASK 7 — REPOSITORY TRANSACTION COORDINATOR
// ─────────────────────────────────────────────────────────────────────────────

/// Runs several repository writes inside ONE real SQLite transaction
/// (IS-R55 Task 7).
///
/// THE INVESTIGATION TASK 7 ASKED FOR, AND ITS ANSWER.
///
/// IS-R54 could not make a two-row commit atomic. Its `InstallationTransaction`
/// compensated instead — snapshot, write, restore on failure — and R54 recorded
/// the residual crash window as gap G-28 rather than claiming atomicity it did
/// not have. The blocker was that `savePackage`/`saveMetadata` each resolved
/// their own `Database` and sqflite's `db.transaction` was not reachable
/// through them.
///
/// Task 7 asks whether transaction exposure is now justified. It is, and for a
/// specific reason: it can be done WITHOUT moving ownership.
///
///   * `SqliteExperienceRepository.database` was ALREADY public.
///   * `Transaction` and `Database` both implement `DatabaseExecutor`.
///   * So each write method needed one optional `using` parameter — additive,
///     defaulted, no existing caller touched, no schema change, no migration.
///
/// The repository still owns every table name and every statement. It is told
/// which executor to write through; it is not told how to transact. That is
/// the whole difference between exposing a seam and moving ownership, and it
/// is why this is not "a second transaction engine": there is no engine here,
/// only sqflite's own transaction, reached in exactly one place.
///
/// WHAT THIS HONESTLY DELIVERS. Writes inside [run] are atomic: SQLite commits
/// them together or not at all, including across a process kill. G-28's crash
/// window is genuinely closed for every commit that goes through here — not
/// narrowed, closed.
///
/// WHAT IT DOES NOT. It cannot make a repository write atomic with something
/// OUTSIDE the repository — World Model ingestion and engineering-memory
/// persistence remain deliberately sequential and best-effort, exactly as they
/// were. Nested transactions are not supported and are not attempted: only
/// this coordinator opens one.
class RepositoryTransactionCoordinator {
  final SqliteExperienceRepository repository;

  const RepositoryTransactionCoordinator(this.repository);

  /// Runs [body] inside one transaction, passing it the executor every
  /// repository write must be given. Throwing from [body] rolls the whole
  /// transaction back.
  Future<T> run<T>(Future<T> Function(DatabaseExecutor txn) body) async {
    final db = await repository.database;
    return db.transaction<T>((txn) => body(txn));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMIT VOCABULARY
// ─────────────────────────────────────────────────────────────────────────────

/// Which subsystem asked for a commit. Recorded for diagnostics ONLY — the
/// framework's behaviour does not branch on it, because a commit is a commit.
/// It exists so a failed write can be attributed without a caller having to
/// thread a log message through.
enum CommitOrigin { creation, modification, evolution, protection, installation, repair, removal }

enum CommitFailure {
  /// The caller asked to write something that is not there.
  nothingToCommit,

  /// SQLite (or the platform) refused the write. The transaction rolled back.
  storageFailure,

  /// The target Experience does not exist and the operation required it to.
  notFound,
}

/// What a commit did. Deliberately carries the PRIOR state, because the
/// repository keeps no version history — a caller that may need to undo later
/// must hold this, and R54's installer and
/// `ExperienceModificationCoordinator.rollback` already had to.
class CommitResult {
  final bool succeeded;
  final CommitOrigin origin;
  final String experienceId;
  final CommitFailure? failure;
  final String? error;

  /// The package this commit replaced, or null when nothing was there.
  final ExperiencePackage? previousPackage;

  /// The metadata this commit replaced, or null when nothing was there.
  final ExperienceMetadataRecord? previousMetadata;

  /// True when the Experience already existed before this commit.
  final bool replacedExisting;

  const CommitResult._({
    required this.succeeded,
    required this.origin,
    required this.experienceId,
    this.failure,
    this.error,
    this.previousPackage,
    this.previousMetadata,
    this.replacedExisting = false,
  });

  factory CommitResult.success({
    required CommitOrigin origin,
    required String experienceId,
    ExperiencePackage? previousPackage,
    ExperienceMetadataRecord? previousMetadata,
    bool replacedExisting = false,
  }) =>
      CommitResult._(
        succeeded: true,
        origin: origin,
        experienceId: experienceId,
        previousPackage: previousPackage,
        previousMetadata: previousMetadata,
        replacedExisting: replacedExisting,
      );

  factory CommitResult.failed({
    required CommitOrigin origin,
    required String experienceId,
    required CommitFailure failure,
    String? error,
  }) =>
      CommitResult._(
        succeeded: false,
        origin: origin,
        experienceId: experienceId,
        failure: failure,
        error: error,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// THE COMMIT FRAMEWORK
// ─────────────────────────────────────────────────────────────────────────────

/// THE one owner of Experience persistence (IS-R55).
///
/// Every method here does the same three things: read what is currently there
/// (so the caller can undo), write inside ONE transaction, and report what
/// happened. Nothing else.
class ExperienceCommitFramework {
  final SqliteExperienceRepository repository;
  final RepositoryTransactionCoordinator transactions;

  ExperienceCommitFramework({required this.repository})
      : transactions = RepositoryTransactionCoordinator(repository);

  /// Reads the current state a commit would replace.
  ///
  /// Exposed because callers that may roll back later must hold the prior
  /// state themselves — the repository keeps no version history, so "the
  /// version before this one" cannot be looked up after the fact.
  Future<({ExperiencePackage? package, ExperienceMetadataRecord? metadata})> currentState(
    String experienceId,
  ) async {
    return (
      package: await repository.getPackage(experienceId),
      metadata: await repository.getMetadata(experienceId),
    );
  }

  /// THE commit. Writes package and/or metadata ATOMICALLY.
  ///
  /// This is the single write path for creation, modification, evolution and
  /// installation. Either both rows land or neither does — the property IS-R54
  /// could not provide and recorded as G-28.
  ///
  /// [package] or [metadata] may be null: modification and evolution rewrite
  /// only the package, and a metadata-only commit is equally valid. Both null
  /// is a caller error, reported rather than silently succeeding.
  Future<CommitResult> commit({
    required String experienceId,
    required CommitOrigin origin,
    ExperiencePackage? package,
    ExperienceMetadataRecord? metadata,
  }) async {
    if (package == null && metadata == null) {
      return CommitResult.failed(
        origin: origin,
        experienceId: experienceId,
        failure: CommitFailure.nothingToCommit,
        error: 'commit requires a package, metadata, or both',
      );
    }

    final prior = await currentState(experienceId);

    try {
      await transactions.run((txn) async {
        if (package != null) await repository.savePackage(package, using: txn);
        if (metadata != null) await repository.saveMetadata(metadata, using: txn);
      });
    } catch (e) {
      // SQLite rolled the transaction back. Nothing partial survived, so there
      // is nothing to compensate for — the whole point of Task 7.
      return CommitResult.failed(
        origin: origin,
        experienceId: experienceId,
        failure: CommitFailure.storageFailure,
        error: e.toString(),
      );
    }

    return CommitResult.success(
      origin: origin,
      experienceId: experienceId,
      previousPackage: prior.package,
      previousMetadata: prior.metadata,
      replacedExisting: prior.package != null || prior.metadata != null,
    );
  }

  /// PROTECTION COMMIT (IS-R55 Task 5).
  ///
  /// Protection owns the crypto; this owns the three writes that follow it —
  /// store the envelope, flip the flag, drop the plaintext — and now performs
  /// them ATOMICALLY.
  ///
  /// That matters more here than anywhere else in the system. Before R55 these
  /// were three sequential writes, so a failure between the second and third
  /// left an Experience marked protected with its PLAINTEXT still on disk.
  /// Either the whole protection lands or none of it does.
  ///
  /// This framework never encrypts and never sees a key. [serializedEnvelope]
  /// arrives already-ciphertext from `ExperienceProtectionService`.
  Future<CommitResult> commitProtection({
    required String experienceId,
    required String serializedEnvelope,
  }) async {
    final prior = await currentState(experienceId);
    try {
      await transactions.run((txn) async {
        await repository.saveProtectedEnvelope(experienceId, serializedEnvelope, using: txn);
        await repository.updateProtectionState(experienceId, true, using: txn);
        await repository.deletePackage(experienceId, using: txn);
      });
    } catch (e) {
      return CommitResult.failed(
        origin: CommitOrigin.protection,
        experienceId: experienceId,
        failure: CommitFailure.storageFailure,
        error: e.toString(),
      );
    }
    return CommitResult.success(
      origin: CommitOrigin.protection,
      experienceId: experienceId,
      previousPackage: prior.package,
      previousMetadata: prior.metadata,
      replacedExisting: true,
    );
  }

  /// UNPROTECTION COMMIT — restores the plaintext package.
  ///
  /// Deliberately does NOT clear the protected envelope or the flag. That is
  /// existing behaviour preserved exactly: `unprotect()` is a read-and-decrypt
  /// operation that makes the package available again, and R55 is forbidden
  /// from redesigning it. Changing it here would be a behavioural change
  /// smuggled in under a persistence refactor.
  Future<CommitResult> commitUnprotection({
    required String experienceId,
    required ExperiencePackage package,
  }) =>
      commit(
        experienceId: experienceId,
        origin: CommitOrigin.protection,
        package: package,
      );

  /// ROLLBACK (IS-R55 Task 9) — the ONE rollback owner.
  ///
  /// Restores caller-held prior state, or REMOVES the Experience when there
  /// was no prior state (a fresh commit's correct undo is deletion, not a
  /// write). Atomic.
  ///
  /// It takes the prior state rather than looking it up because the repository
  /// keeps no version history. Both R54's installer and
  /// `ExperienceModificationCoordinator.rollback` already worked this way; R55
  /// makes it the only way, so there is exactly one rollback contract instead
  /// of three that happened to agree.
  Future<CommitResult> rollback({
    required String experienceId,
    ExperiencePackage? previousPackage,
    ExperienceMetadataRecord? previousMetadata,
  }) async {
    final hadPriorState = previousPackage != null || previousMetadata != null;

    try {
      await transactions.run((txn) async {
        if (!hadPriorState) {
          await repository.delete(experienceId, using: txn);
          return;
        }
        if (previousPackage != null) {
          await repository.savePackage(previousPackage, using: txn);
        }
        if (previousMetadata != null) {
          await repository.saveMetadata(previousMetadata, using: txn);
        }
      });
    } catch (e) {
      return CommitResult.failed(
        origin: CommitOrigin.repair,
        experienceId: experienceId,
        failure: CommitFailure.storageFailure,
        error: e.toString(),
      );
    }

    return CommitResult.success(origin: CommitOrigin.repair, experienceId: experienceId);
  }

  /// REPAIR (IS-R55 Task 8) — the ONE repair owner.
  ///
  /// The installer used to do this. R55 moves the COORDINATION here because
  /// repair is entirely a persistence-consistency operation: it looks at what
  /// is on disk and reconciles the rows. The installer still decides WHEN to
  /// repair; this decides what repairing means.
  ///
  /// Note what R55 changes about repair's justification. R54 needed it because
  /// a crash between two non-atomic writes could tear an install apart. With
  /// Task 7's real transaction, a commit through this framework can no longer
  /// produce that state. Repair remains because a database can still be torn
  /// by anything OUTSIDE this framework's history — a pre-R55 write, a
  /// restored backup, manual surgery, storage corruption — and because
  /// removing a recovery path on the grounds that the new code no longer
  /// causes the problem would be exactly the wrong trade.
  Future<RepairResult> repair(String experienceId, {DateTime? at}) async {
    final package = await repository.getPackage(experienceId);
    final metadata = await repository.getMetadata(experienceId);

    if (package == null && metadata == null) {
      return const RepairResult._(
        outcome: RepairOutcome.notInstalled,
        message: 'not installed',
      );
    }

    if (package == null) {
      // Metadata without a package. The package data is gone and cannot be
      // reconstructed from anything on the device — reported, never faked.
      //
      // A protected Experience is NOT this case: its plaintext is deliberately
      // absent and its envelope holds the real data, so treating it as damaged
      // would be a false alarm on a healthy install.
      final envelope = await repository.getProtectedEnvelope(experienceId);
      if (envelope != null) {
        return const RepairResult._(
          outcome: RepairOutcome.healthy,
          message: 'protected: the plaintext package is absent by design',
        );
      }
      return const RepairResult._(
        outcome: RepairOutcome.unrepairable,
        message: 'metadata exists but the package data is gone and cannot be '
            'reconstructed — reinstall it',
      );
    }

    if (metadata != null) {
      return const RepairResult._(outcome: RepairOutcome.healthy, message: 'nothing to repair');
    }

    // Package without metadata — rebuild metadata from the package's own
    // manifest. Every field comes from data actually on the device.
    //
    // Provenance is NOT invented. The row that carried it is the row that was
    // lost, so unknown origin is the truthful answer — and R52's classifier
    // treats it as untrusted, which is correct for an Experience whose origin
    // nobody can vouch for.
    final rebuilt = ExperienceMetadataRecord(
      id: experienceId,
      name: package.manifest.name,
      description: package.manifest.description,
      category: package.manifest.category,
      createdAt: package.manifest.createdAt,
      updatedAt: at ?? DateTime.now(),
      packageVersion: package.manifest.version,
      isProtected: false,
    );

    final committed = await commit(
      experienceId: experienceId,
      origin: CommitOrigin.repair,
      metadata: rebuilt,
    );

    if (!committed.succeeded) {
      return RepairResult._(
        outcome: RepairOutcome.unrepairable,
        message: 'rebuilding metadata failed: ${committed.error}',
      );
    }

    return const RepairResult._(
      outcome: RepairOutcome.repaired,
      message: 'rebuilt missing metadata from the installed package; '
          'provenance could not be recovered and is recorded as unknown',
    );
  }

  /// REMOVAL — deletes an Experience and everything belonging to it.
  ///
  /// Exists because the R55 audit found `ExperiencesScreen` calling
  /// `repository.delete` directly: a UI screen was a repository writer. Now it
  /// asks for a removal and this performs it.
  Future<CommitResult> remove(String experienceId) async {
    try {
      await transactions.run((txn) => repository.delete(experienceId, using: txn));
    } catch (e) {
      return CommitResult.failed(
        origin: CommitOrigin.removal,
        experienceId: experienceId,
        failure: CommitFailure.storageFailure,
        error: e.toString(),
      );
    }
    return CommitResult.success(origin: CommitOrigin.removal, experienceId: experienceId);
  }
}

enum RepairOutcome { healthy, repaired, unrepairable, notInstalled }

class RepairResult {
  final RepairOutcome outcome;
  final String message;

  const RepairResult._({required this.outcome, required this.message});

  bool get succeeded => outcome == RepairOutcome.healthy || outcome == RepairOutcome.repaired;
}
