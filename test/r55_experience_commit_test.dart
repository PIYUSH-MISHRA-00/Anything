/// Implementation Specification IS-R55 — Canonical Experience Commit
/// Framework.
///
/// REALITY before R55, confirmed by the Task 1 audit. SIX writers of Experience
/// state, each committing on its own terms:
///
///     creation_coordinator.dart:442-443       savePackage + saveMetadata
///     experience_modification_coordinator     savePackage x3 (incl. rollback)
///     evolution_coordinator.dart:79           savePackage
///     security/protection_service.dart        envelope + flag + deletePackage
///     experience_installation.dart            savePackage/saveMetadata/delete
///     features/experiences/experiences_screen.dart:270   delete  <- a UI screen
///
/// The last was NOT on R54's list of four. R54 recorded the situation as gap
/// G-30, severity A. R55 closes it.
///
/// The other thing R55 closes is G-28. R54's installation transaction had to
/// COMPENSATE — snapshot, write, restore — because sqflite's transaction was
/// unreachable through the repository's write methods, leaving a crash window
/// between the two writes. R55 reaches it with one additive optional
/// parameter, so commits are now genuinely atomic.
///
/// These tests exercise both claims, and the one that matters most: an
/// interrupted protection can no longer leave an Experience marked protected
/// with its plaintext still on disk.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/experience_commit.dart';
import 'package:anything/app/experience_installation.dart';
import 'package:anything/app/experience_provenance.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';

var _dbSeq = 0;
String _freshDbName() => 'r55_${_dbSeq++}_${DateTime.now().microsecondsSinceEpoch}.db';

ExperiencePackage _package({String id = 'exp-1', String name = 'Test', String version = '1.0.0'}) {
  final now = DateTime(2026, 8, 7);
  const screens = [
    InterfaceScreen(id: 's1', title: 'Home', children: [
      InterfaceNode(type: 'text', id: 'n1', properties: {'text': 'Hi'}),
    ]),
  ];
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: id,
      name: name,
      description: 'd',
      category: 'general',
      entryPoint: 's1',
      version: version,
      createdAt: now,
      updatedAt: now,
    ),
    interface: const InterfaceDefinition(screens: screens),
    behavior: const BehaviorGraph(),
    state: const StateSchema(),
    capabilityDeclarations: const [],
    provenance: const PackageProvenance(creationEngineVersion: 'test', specVersion: 1, planVersion: 1),
    integrity: PackageIntegrity(contentHash: 'h', computedAt: now),
  );
}

ExperienceMetadataRecord _metadata({String id = 'exp-1', String version = '1.0.0', bool protected = false}) =>
    ExperienceMetadataRecord(
      id: id,
      name: 'Test',
      description: 'd',
      category: 'general',
      createdAt: DateTime(2026, 8, 7),
      updatedAt: DateTime(2026, 8, 7),
      packageVersion: version,
      isProtected: protected,
    );

void main() {
  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  // ───────────────────────────────────────────────────────────────────────────
  // THE COMMIT ITSELF
  // ───────────────────────────────────────────────────────────────────────────
  group('Commit (IS-R55)', () {
    test('writes package and metadata together and reports what it replaced', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      final first = await commits.commit(
        experienceId: 'exp-1',
        origin: CommitOrigin.creation,
        package: _package(),
        metadata: _metadata(),
      );

      expect(first.succeeded, isTrue);
      expect(first.replacedExisting, isFalse);
      expect(first.previousPackage, isNull);
      expect(await repository.getPackage('exp-1'), isNotNull);
      expect(await repository.getMetadata('exp-1'), isNotNull);

      final second = await commits.commit(
        experienceId: 'exp-1',
        origin: CommitOrigin.modification,
        package: _package(version: '2.0.0'),
        metadata: _metadata(version: '2.0.0'),
      );

      expect(second.replacedExisting, isTrue);
      expect(second.previousPackage!.manifest.version, '1.0.0',
          reason: 'the caller must be handed what a later rollback will need — the repository keeps no version history');
      expect(second.previousMetadata!.packageVersion, '1.0.0');
    });

    test('a package-only commit leaves metadata alone — modification and evolution rewrite only the package', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await commits.commit(
        experienceId: 'exp-1',
        origin: CommitOrigin.creation,
        package: _package(),
        metadata: _metadata(),
      );
      await commits.commit(
        experienceId: 'exp-1',
        origin: CommitOrigin.modification,
        package: _package(version: '2.0.0'),
      );

      expect((await repository.getPackage('exp-1'))!.manifest.version, '2.0.0');
      expect((await repository.getMetadata('exp-1'))!.packageVersion, '1.0.0',
          reason: 'a package-only commit must not silently rewrite metadata');
    });

    test('committing nothing is REPORTED, never a silent success', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);

      final result = await ExperienceCommitFramework(repository: repository)
          .commit(experienceId: 'exp-1', origin: CommitOrigin.creation);

      expect(result.succeeded, isFalse);
      expect(result.failure, CommitFailure.nothingToCommit);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TASK 7 — REAL ATOMICITY. THE G-28 CLOSER.
  // ───────────────────────────────────────────────────────────────────────────
  group('Transaction coordinator (IS-R55 Task 7) — G-28', () {
    test('a failure inside a transaction rolls back EVERY write in it, not just the failing one', () async {
      // This is the property R54 could not provide. It is asserted directly on
      // the coordinator, because it is the whole justification for touching
      // the repository at all.
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await commits.commit(
        experienceId: 'exp-1',
        origin: CommitOrigin.creation,
        package: _package(version: '1.0.0'),
        metadata: _metadata(version: '1.0.0'),
      );

      // Write a new package, then throw before the transaction closes.
      await expectLater(
        commits.transactions.run((txn) async {
          await repository.savePackage(_package(version: '9.9.9'), using: txn);
          throw StateError('interrupted after the first write');
        }),
        throwsStateError,
      );

      expect((await repository.getPackage('exp-1'))!.manifest.version, '1.0.0',
          reason: 'SQLite must have rolled the partial write back — no compensation, no snapshot, no crash window');
    });

    test('writes inside one transaction are all visible afterwards', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await commits.transactions.run((txn) async {
        await repository.savePackage(_package(), using: txn);
        await repository.saveMetadata(_metadata(), using: txn);
      });

      expect(await repository.getPackage('exp-1'), isNotNull);
      expect(await repository.getMetadata('exp-1'), isNotNull);
    });

    test('the optional executor is genuinely optional — every pre-R55 caller still works', () async {
      // Backward compatibility, asserted rather than assumed: the additive
      // parameter must not have changed the default behaviour of a bare write.
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);

      await repository.savePackage(_package());
      await repository.saveMetadata(_metadata());

      expect(await repository.getPackage('exp-1'), isNotNull);
      expect(await repository.getMetadata('exp-1'), isNotNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TASK 5 — PROTECTION
  // ───────────────────────────────────────────────────────────────────────────
  group('Protection commit (IS-R55 Task 5)', () {
    test('envelope, flag and plaintext removal land TOGETHER', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await commits.commit(
        experienceId: 'exp-1',
        origin: CommitOrigin.creation,
        package: _package(),
        metadata: _metadata(),
      );

      final result = await commits.commitProtection(
        experienceId: 'exp-1',
        serializedEnvelope: '{"ciphertext":"xxx"}',
      );

      expect(result.succeeded, isTrue);
      expect(await repository.getProtectedEnvelope('exp-1'), isNotNull);
      expect((await repository.getMetadata('exp-1'))!.isProtected, isTrue);
      expect(await repository.getPackage('exp-1'), isNull,
          reason: 'the plaintext must be gone once the envelope is stored');
    });

    test('THE STATE THAT CAN NO LONGER EXIST: marked protected with the plaintext still on disk', () async {
      // Before R55 these were three sequential writes. A failure between the
      // second and the third left an Experience that LOOKED secure and was
      // not. One transaction makes that combination unreachable.
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await commits.commit(
        experienceId: 'exp-1',
        origin: CommitOrigin.creation,
        package: _package(),
        metadata: _metadata(),
      );

      await expectLater(
        commits.transactions.run((txn) async {
          await repository.saveProtectedEnvelope('exp-1', '{"ciphertext":"xxx"}', using: txn);
          await repository.updateProtectionState('exp-1', true, using: txn);
          throw StateError('interrupted before the plaintext was removed');
        }),
        throwsStateError,
      );

      final metadata = await repository.getMetadata('exp-1');
      final plaintext = await repository.getPackage('exp-1');

      expect(metadata!.isProtected && plaintext != null, isFalse,
          reason: 'an Experience must never be marked protected while its plaintext survives');
      expect(metadata.isProtected, isFalse);
      expect(plaintext, isNotNull, reason: 'the whole protection rolled back, so the package is untouched');
      expect(await repository.getProtectedEnvelope('exp-1'), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TASK 9 — ROLLBACK
  // ───────────────────────────────────────────────────────────────────────────
  group('Rollback (IS-R55 Task 9) — exactly one owner', () {
    test('restores caller-held prior state', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await commits.commit(
        experienceId: 'exp-1', origin: CommitOrigin.creation,
        package: _package(version: '1.0.0'), metadata: _metadata(version: '1.0.0'),
      );
      final upgraded = await commits.commit(
        experienceId: 'exp-1', origin: CommitOrigin.modification,
        package: _package(version: '2.0.0'), metadata: _metadata(version: '2.0.0'),
      );

      await commits.rollback(
        experienceId: 'exp-1',
        previousPackage: upgraded.previousPackage,
        previousMetadata: upgraded.previousMetadata,
      );

      expect((await repository.getPackage('exp-1'))!.manifest.version, '1.0.0');
      expect((await repository.getMetadata('exp-1'))!.packageVersion, '1.0.0');
    });

    test('rolling back a commit that had NO prior state deletes rather than writes', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await commits.commit(
        experienceId: 'exp-1', origin: CommitOrigin.creation,
        package: _package(), metadata: _metadata(),
      );
      await commits.rollback(experienceId: 'exp-1');

      expect(await repository.getPackage('exp-1'), isNull);
      expect(await repository.getMetadata('exp-1'), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TASK 8 — REPAIR
  // ───────────────────────────────────────────────────────────────────────────
  group('Repair (IS-R55 Task 8) — exactly one owner', () {
    test('rebuilds missing metadata from the package, recording provenance as UNKNOWN', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await repository.savePackage(_package(name: 'Torn'));

      final result = await commits.repair('exp-1', at: DateTime(2026, 8, 8));

      expect(result.outcome, RepairOutcome.repaired);
      final metadata = await repository.getMetadata('exp-1');
      expect(metadata!.name, 'Torn');
      expect(metadata.provenance.origin, ExperienceOrigin.unknown,
          reason: 'the row that carried provenance is the row that was lost; unknown is truthful, a guess is not');
    });

    test('metadata without a package is unrepairable, never faked', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await repository.saveMetadata(_metadata());
      final result = await commits.repair('exp-1');

      expect(result.outcome, RepairOutcome.unrepairable);
      expect(result.message, contains('cannot be reconstructed'));
    });

    test('a PROTECTED Experience is healthy, not damaged — its plaintext is absent by design', () async {
      // The obvious repair implementation would report every protected
      // Experience as torn, because protection deliberately deletes the
      // plaintext. That would be a false alarm on a correct install.
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await commits.commit(
        experienceId: 'exp-1', origin: CommitOrigin.creation,
        package: _package(), metadata: _metadata(),
      );
      await commits.commitProtection(experienceId: 'exp-1', serializedEnvelope: '{"c":"x"}');

      final result = await commits.repair('exp-1');
      expect(result.outcome, RepairOutcome.healthy);
      expect(result.message, contains('by design'));
    });

    test('a healthy install and an absent one are each reported honestly', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await commits.commit(
        experienceId: 'exp-1', origin: CommitOrigin.creation,
        package: _package(), metadata: _metadata(),
      );

      expect((await commits.repair('exp-1')).outcome, RepairOutcome.healthy);
      expect((await commits.repair('ghost')).outcome, RepairOutcome.notInstalled);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // REMOVAL — the write the audit found in the UI
  // ───────────────────────────────────────────────────────────────────────────
  group('Removal (IS-R55 Task 1 finding)', () {
    test('removes metadata, package and envelope together', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);

      await commits.commit(
        experienceId: 'exp-1', origin: CommitOrigin.creation,
        package: _package(), metadata: _metadata(),
      );
      await commits.commitProtection(experienceId: 'exp-1', serializedEnvelope: '{"c":"x"}');

      final result = await commits.remove('exp-1');

      expect(result.succeeded, isTrue);
      expect(await repository.getMetadata('exp-1'), isNull);
      expect(await repository.getPackage('exp-1'), isNull);
      expect(await repository.getProtectedEnvelope('exp-1'), isNull,
          reason: 'a removed Experience must not leave its ciphertext behind');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TASK 6 — INSTALLATION STILL WORKS, THROUGH THE ONE OWNER
  // ───────────────────────────────────────────────────────────────────────────
  group('Installation integration (IS-R55 Task 6)', () {
    test('the installer commits through the commit framework and behaves exactly as in R54', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final commits = ExperienceCommitFramework(repository: repository);
      final installer = ExperienceInstallationFramework(repository: repository, commitFramework: commits);

      final result = await installer.install(package: _package());

      expect(result.succeeded, isTrue);
      expect(result.kind, InstallationKind.freshInstall);
      expect(await repository.getPackage('exp-1'), isNotNull);
      expect(identical(installer.commits, commits), isTrue,
          reason: 'the installer must write through the injected owner, not a private one');
    });

    test('the installer REQUESTS repair rather than performing it', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final installer = ExperienceInstallationFramework(repository: repository);

      await repository.savePackage(_package(name: 'Torn'));
      final result = await installer.repair('exp-1');

      expect(result.succeeded, isTrue);
      expect(result.kind, InstallationKind.repair);
      expect((await repository.getMetadata('exp-1'))!.name, 'Torn');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // COMPOSITION
  // ───────────────────────────────────────────────────────────────────────────
  group('Composition (IS-R55 Task 11)', () {
    test('ONE commit framework is shared by the installer and the whole graph', () {
      final composition = AppComposition.production();
      addTearDown(() => composition.experienceRepository.close());

      expect(identical(composition.experienceCommit, composition.experienceCommit), isTrue);
      expect(identical(composition.experienceInstallation.commitFramework, composition.experienceCommit), isTrue,
          reason: 'the installer must commit through the composition owner');
      expect(identical(composition.experienceCommit.repository, composition.experienceRepository), isTrue,
          reason: 'the ONE commit owner must write to the ONE repository');
      expect(identical(composition.experienceCommit.transactions.repository, composition.experienceRepository), isTrue);
    });
  });
}
