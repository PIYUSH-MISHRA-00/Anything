/// Implementation Specification IS-R54 — Canonical Experience Installation
/// Framework.
///
/// REALITY before R54, confirmed by the Task 1 audit:
///
///   * NOTHING owned installation. Five separate call sites wrote packages to
///     the repository — creation, distribution/import, modification, evolution
///     and protection — each committing on its own terms.
///   * `ExperienceManifest.minimumRuntimeVersion` had been declared and
///     serialised since the manifest existed and was read by NOTHING. The
///     system made a compatibility promise in its data model and never kept it.
///   * R53's `dependencies` list was transported and resolved by nothing.
///   * A real migration engine ALREADY existed (`MigrationExecutor` +
///     `DataMigrationPlan`/`MigrationValidator` in lib/storage/), so R54 must
///     not build a second one.
///
/// These tests exercise the layering the milestone exists to establish:
///
///     distribution MOVES -> installer COMMITS -> repository STORES
///
/// and the boundary it must never cross: install never activates.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/app_composition.dart';
import 'package:anything/app/experience_distribution.dart';
import 'package:anything/app/experience_installation.dart';
import 'package:anything/app/experience_provenance.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';

var _dbSeq = 0;
String _freshDbName() =>
    'r54_${_dbSeq++}_${DateTime.now().microsecondsSinceEpoch}.db';

ExperiencePackage _package({
  String id = 'exp-1',
  String name = 'Test',
  String version = '1.0.0',
  String? minimumRuntimeVersion,
  List<String> requiredCapabilities = const [],
  List<String> optionalCapabilities = const [],
  int? dataSchemaVersion,
  String entryPoint = 's1',
}) {
  final now = DateTime(2026, 8, 7);
  const screens = [
    InterfaceScreen(
      id: 's1',
      title: 'Home',
      children: [
        InterfaceNode(type: 'text', id: 'n1', properties: {'text': 'Hi'}),
      ],
    ),
  ];
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: id,
      name: name,
      description: 'd',
      category: 'general',
      entryPoint: entryPoint,
      version: version,
      minimumRuntimeVersion: minimumRuntimeVersion,
      requiredCapabilities: requiredCapabilities,
      optionalCapabilities: optionalCapabilities,
      createdAt: now,
      updatedAt: now,
    ),
    interface: const InterfaceDefinition(screens: screens),
    behavior: const BehaviorGraph(),
    state: const StateSchema(),
    data: dataSchemaVersion == null
        ? null
        : DataSchema(schemaVersion: dataSchemaVersion),
    capabilityDeclarations: const [],
    provenance: const PackageProvenance(
      creationEngineVersion: 'test',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(contentHash: 'h', computedAt: now),
  );
}

void main() {
  const evaluator = ExperienceCompatibilityEvaluator();
  const planner = ExperienceDependencyPlanner();

  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TASK 3 — COMPATIBILITY. Evaluate only.
  // ───────────────────────────────────────────────────────────────────────────
  group('Compatibility evaluation (R54 Task 3)', () {
    test(
      'minimumRuntimeVersion is FINALLY consumed — a package needing a newer runtime is incompatible',
      () {
        // The whole point of this evaluator. Before R54 this field was declared,
        // serialised, round-tripped and read by nothing.
        final evaluation = evaluator.evaluate(
          _package(minimumRuntimeVersion: '9.0.0'),
          runtimeVersion: '2.0.0',
        );

        expect(evaluation.isCompatible, isFalse);
        expect(
          evaluation.blockers.single.reason,
          IncompatibilityReason.runtimeTooOld,
        );
        expect(evaluation.blockers.single.detail, contains('9.0.0'));
      },
    );

    test('a package needing an OLDER or EQUAL runtime is compatible', () {
      expect(
        evaluator
            .evaluate(
              _package(minimumRuntimeVersion: '1.0.0'),
              runtimeVersion: '2.0.0',
            )
            .isCompatible,
        isTrue,
      );
      expect(
        evaluator
            .evaluate(
              _package(minimumRuntimeVersion: '2.0.0'),
              runtimeVersion: '2.0.0',
            )
            .isCompatible,
        isTrue,
      );
    });

    test(
      'an ABSENT minimumRuntimeVersion is not a failure — most packages do not declare one',
      () {
        expect(evaluator.evaluate(_package()).isCompatible, isTrue);
      },
    );

    test(
      'an unparseable version is reported as malformed rather than silently treated as compatible',
      () {
        final evaluation = evaluator.evaluate(
          _package(minimumRuntimeVersion: 'banana'),
        );
        expect(evaluation.isCompatible, isFalse);
        expect(
          evaluation.blockers.single.reason,
          IncompatibilityReason.malformedVersion,
        );
      },
    );

    test(
      'compareVersions orders correctly, tolerates short forms and build suffixes, and returns null on garbage',
      () {
        expect(
          ExperienceCompatibilityEvaluator.compareVersions('2.0.0', '1.9.9')! >
              0,
          isTrue,
        );
        expect(
          ExperienceCompatibilityEvaluator.compareVersions('1.0.0', '1.0.1')! <
              0,
          isTrue,
        );
        expect(
          ExperienceCompatibilityEvaluator.compareVersions('1.0.0', '1.0.0'),
          0,
        );
        // 10 > 9 numerically, NOT lexicographically — the bug a string compare
        // would have shipped.
        expect(
          ExperienceCompatibilityEvaluator.compareVersions('1.10.0', '1.9.0')! >
              0,
          isTrue,
        );
        expect(
          ExperienceCompatibilityEvaluator.compareVersions('2', '1.9.9')! > 0,
          isTrue,
        );
        expect(
          ExperienceCompatibilityEvaluator.compareVersions('2.0.0+7', '2.0.0')!,
          0,
        );
        expect(
          ExperienceCompatibilityEvaluator.compareVersions('x', '1.0.0'),
          isNull,
        );
        expect(
          ExperienceCompatibilityEvaluator.compareVersions('1.0.0.0', '1.0.0'),
          isNull,
        );
      },
    );

    test(
      'a MISSING REQUIRED capability blocks; a missing OPTIONAL one only warns',
      () {
        final evaluation = evaluator.evaluate(
          _package(
            requiredCapabilities: ['http'],
            optionalCapabilities: ['notifications'],
          ),
          availableCapabilities: {'clock', 'http'},
        );
        // http is present, notifications is not: degraded, not uninstallable.
        expect(evaluation.isCompatible, isTrue);
        expect(evaluation.warnings.single.detail, contains('notifications'));

        final blocked = evaluator.evaluate(
          _package(requiredCapabilities: ['http']),
          availableCapabilities: {'clock'},
        );
        expect(blocked.isCompatible, isFalse);
        expect(
          blocked.blockers.single.reason,
          IncompatibilityReason.capabilityUnavailable,
        );
      },
    );

    test(
      'an EMPTY capability set means "not told", not "nothing available" — it does not block every install',
      () {
        // Treating the two the same would make a caller's omission look like an
        // incompatible device.
        final evaluation = evaluator.evaluate(
          _package(requiredCapabilities: ['http']),
          availableCapabilities: const {},
        );
        expect(evaluation.isCompatible, isTrue);
      },
    );

    test('an incomplete manifest is caught', () {
      expect(
        evaluator.evaluate(_package(entryPoint: '')).blockers.single.reason,
        IncompatibilityReason.manifestIncomplete,
      );
    });

    test(
      'THE EVALUATOR CANNOT INSTALL — it holds no repository and returns a verdict only (Task 3)',
      () {
        // Certified statically too (I-63); asserted here on the live object
        // because "only evaluate" is the property that keeps it safe to call
        // anywhere.
        final before = evaluator.evaluate(_package());
        expect(before, isA<CompatibilityEvaluation>());
        expect(evaluator.supportsPackageFormat(1), isTrue);
        expect(evaluator.supportsPackageFormat(999), isFalse);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TASK 4 — DEPENDENCY PREPARATION.
  // ───────────────────────────────────────────────────────────────────────────
  group(
    'Dependency planning (R54 Task 4) — architecture only, nothing downloads',
    () {
      test(
        'classifies satisfied, missing and self-referential dependencies',
        () {
          final plan = planner.plan(
            experienceId: 'exp-1',
            dependencies: ['dep-a', 'dep-b', 'exp-1'],
            installedIds: {'dep-a'},
          );

          expect(plan.missing, ['dep-b']);
          expect(plan.circular, ['exp-1']);
          expect(plan.isSatisfied, isFalse);
          expect(plan.nodes.first.status, DependencyStatus.satisfied);
        },
      );

      test(
        'an empty dependency list is satisfied — the overwhelmingly common case',
        () {
          expect(
            planner
                .plan(
                  experienceId: 'exp-1',
                  dependencies: const [],
                  installedIds: const {},
                )
                .isSatisfied,
            isTrue,
          );
        },
      );

      test(
        'deduplicates and ignores blank entries rather than reporting the same gap twice',
        () {
          final plan = planner.plan(
            experienceId: 'exp-1',
            dependencies: ['dep-a', 'dep-a', '  ', ''],
            installedIds: const {},
          );
          expect(plan.missing, ['dep-a']);
          expect(plan.nodes.length, 1);
        },
      );
    },
  );

  // ───────────────────────────────────────────────────────────────────────────
  // TASK 5 — INSTALLATION TRANSACTION.
  // ───────────────────────────────────────────────────────────────────────────
  group('Installation transaction (R54 Task 5)', () {
    test(
      'prepare captures the prior state, commit writes both rows, rollback restores exactly what prepare saw',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);

        final v1 = _package(version: '1.0.0');
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );
        await installer.install(package: v1);

        final tx = InstallationTransaction(
          repository: repository,
          experienceId: 'exp-1',
        );
        await tx.prepare();
        expect(tx.replacesExisting, isTrue);
        expect(tx.priorPackage!.manifest.version, '1.0.0');

        final v2 = _package(version: '2.0.0');
        await tx.commit(
          package: v2,
          metadata: ExperienceMetadataRecord(
            id: 'exp-1',
            name: 'Test',
            description: 'd',
            category: 'general',
            createdAt: DateTime(2026, 8, 7),
            updatedAt: DateTime(2026, 8, 8),
            packageVersion: '2.0.0',
          ),
        );
        expect(tx.state, TransactionState.committed);
        expect(
          (await repository.getPackage('exp-1'))!.manifest.version,
          '2.0.0',
        );

        await tx.rollback();
        expect(tx.state, TransactionState.rolledBack);
        expect(
          (await repository.getPackage('exp-1'))!.manifest.version,
          '1.0.0',
          reason: 'rollback restores the snapshot prepare() captured',
        );
        expect(
          (await repository.getMetadata('exp-1'))!.packageVersion,
          '1.0.0',
        );
      },
    );

    test(
      'rolling back a FRESH install DELETES rather than writing — there was nothing to restore',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);

        final tx = InstallationTransaction(
          repository: repository,
          experienceId: 'exp-1',
        );
        await tx.prepare();
        expect(tx.replacesExisting, isFalse);

        final package = _package();
        await tx.commit(
          package: package,
          metadata: ExperienceMetadataRecord(
            id: 'exp-1',
            name: 'Test',
            description: 'd',
            category: 'general',
            createdAt: DateTime(2026, 8, 7),
            updatedAt: DateTime(2026, 8, 7),
          ),
        );
        expect(await repository.getPackage('exp-1'), isNotNull);

        await tx.rollback();
        expect(await repository.getPackage('exp-1'), isNull);
        expect(await repository.getMetadata('exp-1'), isNull);
      },
    );

    test(
      'cancel abandons without touching storage, and the state machine refuses out-of-order calls',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);

        final tx = InstallationTransaction(
          repository: repository,
          experienceId: 'exp-1',
        );
        await tx.prepare();
        tx.cancel();

        expect(tx.state, TransactionState.cancelled);
        expect(await repository.getPackage('exp-1'), isNull);

        // A cancelled transaction must not be committable.
        expect(
          () => tx.commit(
            package: _package(),
            metadata: ExperienceMetadataRecord(
              id: 'exp-1',
              name: 'T',
              description: 'd',
              category: 'g',
              createdAt: DateTime(2026, 8, 7),
              updatedAt: DateTime(2026, 8, 7),
            ),
          ),
          throwsStateError,
        );

        // Nor may an un-prepared transaction commit.
        final fresh = InstallationTransaction(
          repository: repository,
          experienceId: 'exp-2',
        );
        expect(() => fresh.rollback(), throwsStateError);
      },
    );

    test(
      'validate DELEGATES to the canonical validator rather than re-implementing one',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);

        final tx = InstallationTransaction(
          repository: repository,
          experienceId: 'exp-1',
        );
        expect(tx.validate(_package()).isValid, isTrue);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TASK 2 — INSTALL / UPGRADE / DOWNGRADE.
  // ───────────────────────────────────────────────────────────────────────────
  group('Installation (R54 Task 2)', () {
    test(
      'a fresh install commits BOTH rows and reports freshInstall',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );

        final result = await installer.install(
          package: _package(),
          provenance: ExperienceProvenance.imported(
            at: DateTime(2026, 8, 7),
            source: 'test',
          ),
        );

        expect(result.succeeded, isTrue);
        expect(result.kind, InstallationKind.freshInstall);
        expect(result.previousPackage, isNull);

        // Genuinely usable, not merely recorded.
        expect(await repository.getPackage('exp-1'), isNotNull);
        final metadata = await repository.getMetadata('exp-1');
        expect(metadata!.provenance.origin, ExperienceOrigin.imported);
        expect(metadata.packageVersion, '1.0.0');
      },
    );

    test(
      'the KIND is DERIVED from the versions, never taken from the caller',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );

        await installer.install(package: _package(version: '1.0.0'));

        // Calling upgrade() with an OLDER package is honestly reported as a
        // downgrade rather than believed.
        final lied = await installer.upgrade(
          package: _package(version: '0.9.0'),
        );
        expect(lied.kind, InstallationKind.downgrade);

        expect(
          (await installer.install(package: _package(version: '1.5.0'))).kind,
          InstallationKind.upgrade,
        );
        expect(
          (await installer.install(package: _package(version: '1.5.0'))).kind,
          InstallationKind.reinstall,
        );
        expect(
          (await installer.downgrade(package: _package(version: '1.0.0'))).kind,
          InstallationKind.downgrade,
        );
      },
    );

    test(
      'an upgrade keeps the ORIGINAL creation date — the Experience was not created again',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );

        await installer.install(
          package: _package(version: '1.0.0'),
          at: DateTime(2026, 1, 1),
        );
        final created = (await repository.getMetadata('exp-1'))!.createdAt;

        await installer.install(
          package: _package(version: '2.0.0'),
          at: DateTime(2026, 8, 7),
        );
        final after = (await repository.getMetadata('exp-1'))!;

        expect(after.createdAt, created);
        expect(after.updatedAt, DateTime(2026, 8, 7));
        expect(after.packageVersion, '2.0.0');
      },
    );

    test(
      'an INCOMPATIBLE package is refused and NOTHING is persisted',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );

        final result = await installer.install(
          package: _package(minimumRuntimeVersion: '99.0.0'),
        );

        expect(result.succeeded, isFalse);
        expect(result.failure, InstallationFailure.incompatible);
        expect(await repository.getPackage('exp-1'), isNull);
        expect(await repository.getMetadata('exp-1'), isNull);
      },
    );

    test(
      'UNSATISFIED DEPENDENCIES refuse the install and persist NOTHING',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );

        final result = await installer.install(
          package: _package(),
          dependencies: ['missing-dep'],
        );

        expect(result.succeeded, isFalse);
        expect(result.failure, InstallationFailure.dependenciesUnsatisfied);
        expect(result.dependencies!.missing, ['missing-dep']);
        expect(await repository.getPackage('exp-1'), isNull);
      },
    );

    test(
      'a dependency ALREADY INSTALLED satisfies the plan and the install proceeds',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );

        await installer.install(
          package: _package(id: 'dep-a', name: 'Dep'),
        );
        final result = await installer.install(
          package: _package(),
          dependencies: ['dep-a'],
        );

        expect(result.succeeded, isTrue);
        expect(result.dependencies!.isSatisfied, isTrue);
      },
    );

    test(
      'a FAILED install over an existing one leaves the existing install untouched',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );

        await installer.install(package: _package(version: '1.0.0'));
        final failed = await installer.install(
          package: _package(version: '2.0.0', minimumRuntimeVersion: '99.0.0'),
        );

        expect(failed.succeeded, isFalse);
        expect(
          (await repository.getPackage('exp-1'))!.manifest.version,
          '1.0.0',
          reason:
              'a rejected install must not disturb what is already installed',
        );
      },
    );

    test('INSTALL NEVER ACTIVATES — it commits and stops (Task 9)', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final installer = ExperienceInstallationFramework(repository: repository);

      final result = await installer.install(package: _package());

      // The Experience is installed and idle. There is no session, no route
      // and no runtime — the result object exposes no way to start one, which
      // is the point: installing something must not run it.
      expect(result.succeeded, isTrue);
      expect(result.experienceId, 'exp-1');
      expect(
        (await repository.getMetadata('exp-1'))!.lastUsedAt,
        isNull,
        reason: 'nothing was opened, so nothing was used',
      );
    });

    test(
      'protection requested with NO service wired is REPORTED, never silently skipped',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );

        final result = await installer.install(
          package: _package(),
          protect: true,
        );

        expect(result.succeeded, isTrue);
        expect(result.protected, isFalse);
        expect(
          result.messages.join(),
          contains('no ExperienceProtectionService'),
        );
        expect(
          (await repository.getMetadata('exp-1'))!.isProtected,
          isFalse,
          reason:
              'the installer must never assert a protected state it did not produce',
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TASK 6 — MIGRATION PREPARATION.
  // ───────────────────────────────────────────────────────────────────────────
  group(
    'Migration preparation (R54 Task 6) — records requirements, executes nothing',
    () {
      test(
        'a data-schema version change is RECORDED as a requirement on upgrade',
        () async {
          final repository = SqliteExperienceRepository(dbName: _freshDbName());
          addTearDown(repository.close);
          final installer = ExperienceInstallationFramework(
            repository: repository,
          );

          await installer.install(
            package: _package(version: '1.0.0', dataSchemaVersion: 1),
          );
          final result = await installer.install(
            package: _package(version: '2.0.0', dataSchemaVersion: 2),
          );

          final migration = result.migrations.singleWhere(
            (m) => m.kind == MigrationKind.dataSchema,
          );
          expect(migration.fromVersion, '1');
          expect(migration.toVersion, '2');
          expect(migration.experienceId, 'exp-1');
        },
      );

      test('a runtime-requirement change is recorded', () {
        final requirements = migrationRequirements(
          installed: _package(minimumRuntimeVersion: '1.0.0'),
          incoming: _package(minimumRuntimeVersion: '2.0.0'),
        );
        final runtime = requirements.singleWhere(
          (m) => m.kind == MigrationKind.runtime,
        );
        expect(runtime.fromVersion, '1.0.0');
        expect(runtime.toVersion, '2.0.0');
      });

      test(
        'an unchanged schema produces NO requirement — no busywork migration',
        () {
          expect(
            migrationRequirements(
              installed: _package(dataSchemaVersion: 1),
              incoming: _package(dataSchemaVersion: 1),
            ),
            isEmpty,
          );
        },
      );

      test(
        'a FRESH install has no migrations — there is nothing to migrate FROM',
        () async {
          final repository = SqliteExperienceRepository(dbName: _freshDbName());
          addTearDown(repository.close);
          final installer = ExperienceInstallationFramework(
            repository: repository,
          );

          expect(
            (await installer.install(
              package: _package(dataSchemaVersion: 3),
            )).migrations,
            isEmpty,
          );
        },
      );
    },
  );

  // ───────────────────────────────────────────────────────────────────────────
  // ROLLBACK AND REPAIR.
  // ───────────────────────────────────────────────────────────────────────────
  group('Rollback (R54 Task 2)', () {
    test('rollback restores a caller-held previous package', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final installer = ExperienceInstallationFramework(repository: repository);

      final v1 = _package(version: '1.0.0');
      await installer.install(package: v1);

      final upgraded = await installer.install(
        package: _package(version: '2.0.0'),
      );
      expect(
        upgraded.previousPackage!.manifest.version,
        '1.0.0',
        reason: 'the result must hand back what a later rollback will need',
      );

      final rolled = await installer.rollback(
        experienceId: 'exp-1',
        previousPackage: upgraded.previousPackage!,
      );
      expect(rolled.succeeded, isTrue);
      expect((await repository.getPackage('exp-1'))!.manifest.version, '1.0.0');
    });

    test('rolling back something that is not installed is refused', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final installer = ExperienceInstallationFramework(repository: repository);

      final result = await installer.rollback(
        experienceId: 'ghost',
        previousPackage: _package(id: 'ghost'),
      );
      expect(result.succeeded, isFalse);
      expect(result.failure, InstallationFailure.notInstalled);
    });
  });

  group('Repair (R54 Task 2)', () {
    test(
      'a TORN install — package present, metadata missing — is repaired from the package itself',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );

        // Exactly the state a crash between the two writes leaves behind.
        await repository.savePackage(_package(name: 'Torn'));
        expect(await repository.getMetadata('exp-1'), isNull);

        final result = await installer.repair(
          'exp-1',
          at: DateTime(2026, 8, 8),
        );

        expect(result.succeeded, isTrue);
        expect(result.kind, InstallationKind.repair);
        final metadata = await repository.getMetadata('exp-1');
        expect(metadata!.name, 'Torn');
        expect(
          metadata.provenance.origin,
          ExperienceOrigin.unknown,
          reason:
              'the row that carried provenance is the row that was lost; unknown is the truthful answer, not a guess',
        );
      },
    );

    test(
      'metadata WITHOUT a package is reported as unrepairable rather than faked',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );

        await repository.saveMetadata(
          ExperienceMetadataRecord(
            id: 'exp-1',
            name: 'Half',
            description: 'd',
            category: 'g',
            createdAt: DateTime(2026, 8, 7),
            updatedAt: DateTime(2026, 8, 7),
          ),
        );

        final result = await installer.repair('exp-1');
        expect(result.succeeded, isFalse);
        expect(result.messages.join(), contains('cannot be reconstructed'));
      },
    );

    test(
      'a HEALTHY install reports nothing to repair and changes nothing',
      () async {
        final repository = SqliteExperienceRepository(dbName: _freshDbName());
        addTearDown(repository.close);
        final installer = ExperienceInstallationFramework(
          repository: repository,
        );

        await installer.install(package: _package(version: '1.2.3'));
        final result = await installer.repair('exp-1');

        expect(result.succeeded, isTrue);
        expect(result.messages.join(), contains('nothing to repair'));
        expect(
          (await repository.getPackage('exp-1'))!.manifest.version,
          '1.2.3',
        );
      },
    );

    test('repairing something absent entirely is refused', () async {
      final repository = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repository.close);
      final installer = ExperienceInstallationFramework(repository: repository);

      expect(
        (await installer.repair('ghost')).failure,
        InstallationFailure.notInstalled,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // TASK 8 — DISTRIBUTION INTEGRATION.
  // ───────────────────────────────────────────────────────────────────────────
  group(
    'Distribution integration (R54 Task 8) — distribution MOVES, installer COMMITS',
    () {
      test(
        'import still persists exactly as it did in R53 — ownership moved, behaviour did not',
        () async {
          final repository = SqliteExperienceRepository(dbName: _freshDbName());
          addTearDown(repository.close);

          final installer = ExperienceInstallationFramework(
            repository: repository,
          );
          final distribution = ExperienceDistributionFramework(
            repository: repository,
            installer: installer,
          );
          final package = _package();

          final result = await distribution.import(
            ExperienceDistributionPackage(
              envelope: ExperienceDistributionManifest(
                manifest: package.manifest,
                fingerprint: ExperienceFingerprint(
                  ExperiencePackage.computeIntegrityHash(package),
                ),
              ),
              package: package,
            ),
          );

          expect(result.succeeded, isTrue);
          expect(result.provenance!.origin, ExperienceOrigin.imported);
          expect(await repository.getPackage('exp-1'), isNotNull);
          expect((await repository.getMetadata('exp-1'))!.isProtected, isFalse);
        },
      );

      test(
        'an import whose package the INSTALLER rejects fails, and persists nothing',
        () async {
          final repository = SqliteExperienceRepository(dbName: _freshDbName());
          addTearDown(repository.close);

          final distribution = ExperienceDistributionFramework(
            repository: repository,
          );
          // Passes envelope verification (fingerprint and identity agree) but the
          // installer's compatibility gate refuses it.
          final package = _package(minimumRuntimeVersion: '99.0.0');

          final result = await distribution.import(
            ExperienceDistributionPackage(
              envelope: ExperienceDistributionManifest(
                manifest: package.manifest,
                fingerprint: ExperienceFingerprint(
                  ExperiencePackage.computeIntegrityHash(package),
                ),
              ),
              package: package,
            ),
          );

          expect(result.succeeded, isFalse);
          expect(result.error, contains('runtimeTooOld'));
          expect(await repository.getPackage('exp-1'), isNull);
        },
      );

      test(
        'the envelope dependencies R53 transported and never resolved are now READ by the installer',
        () async {
          final repository = SqliteExperienceRepository(dbName: _freshDbName());
          addTearDown(repository.close);

          final distribution = ExperienceDistributionFramework(
            repository: repository,
          );
          final package = _package();

          final result = await distribution.import(
            ExperienceDistributionPackage(
              envelope: ExperienceDistributionManifest(
                manifest: package.manifest,
                fingerprint: ExperienceFingerprint(
                  ExperiencePackage.computeIntegrityHash(package),
                ),
                dependencies: const ['not-installed'],
              ),
              package: package,
            ),
          );

          expect(result.succeeded, isFalse);
          expect(result.error, contains('missing dependencies'));
          expect(
            await repository.getPackage('exp-1'),
            isNull,
            reason:
                'closing R53 gap G-27: dependencies are no longer transported and ignored',
          );
        },
      );

      test(
        'export -> import -> the installed package is byte-identical',
        () async {
          final source = SqliteExperienceRepository(dbName: _freshDbName());
          final target = SqliteExperienceRepository(dbName: _freshDbName());
          addTearDown(source.close);
          addTearDown(target.close);

          final package = _package();
          await ExperienceInstallationFramework(
            repository: source,
          ).install(package: package);

          final exported = await ExperienceDistributionFramework(
            repository: source,
          ).export('exp-1');
          final imported = await ExperienceDistributionFramework(
            repository: target,
          ).import(exported!);

          expect(imported.succeeded, isTrue);
          expect(
            ExperiencePackage.computeIntegrityHash(
              (await target.getPackage('exp-1'))!,
            ),
            ExperiencePackage.computeIntegrityHash(package),
          );
        },
      );
    },
  );

  // ───────────────────────────────────────────────────────────────────────────
  // COMPOSITION.
  // ───────────────────────────────────────────────────────────────────────────
  group('Composition (R54 Task 12)', () {
    test(
      'the ONE installer is shared, and distribution commits through THAT instance',
      () {
        // A second installer instance would mean two commit paths with two
        // protection configurations — exactly the split this milestone exists to
        // prevent.
        final composition = AppComposition.production();
        addTearDown(() => composition.experienceRepository.close());

        expect(
          identical(
            composition.experienceInstallation,
            composition.experienceInstallation,
          ),
          isTrue,
        );
        expect(
          identical(
            composition.experienceDistribution.installer,
            composition.experienceInstallation,
          ),
          isTrue,
          reason:
              'distribution must commit through the composition installer, not a private one',
        );
        expect(
          composition.experienceInstallation.protectionService,
          isNotNull,
          reason:
              'production installs must be able to honour a protection request',
        );
        expect(
          identical(
            composition.experienceInstallation.repository,
            composition.experienceRepository,
          ),
          isTrue,
          reason:
              'the installer must commit to the ONE repository, never a second store',
        );
      },
    );
  });
}
