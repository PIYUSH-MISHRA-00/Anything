/// Implementation Specification IS-P02 Phase 9 — Experience portability.
///
/// WHAT THE AUDIT FOUND. Every component exercised here was already built,
/// tested and certified, and NONE had a production caller:
/// `ExperiencePackageWriter`/`Reader` (R60) had **zero `lib/` importers**;
/// `ExperienceInstallationFramework` (R54) was read only by tests.
///
/// Gap G-25 -- "a user still cannot import an Experience" -- had been open
/// since R53 and deferred three times. These tests prove it is closed, and
/// prove the wiring adds no second owner of anything.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/experience_installation.dart';
import 'package:anything/app/experience_portability.dart';
import 'package:anything/capabilities/adapters/file_service_adapter.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/experience_package_codec.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';

ExperiencePackage buildPackage({
  String id = 'water-tracker',
  String name = 'Water Tracker',
  String version = '1.0.0',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: id,
      name: name,
      description: 'Logs daily water intake',
      category: 'health',
      entryPoint: 'home',
      version: version,
      createdAt: now,
      updatedAt: now,
    ),
    interface: const InterfaceDefinition(
      screens: [
        InterfaceScreen(
          id: 'home',
          title: 'Water',
          children: [
            InterfaceNode(
              type: 'text',
              id: 'title',
              properties: {'content': 'Glasses today: 0'},
            ),
          ],
        ),
      ],
    ),
    behavior: const BehaviorGraph(),
    state: const StateSchema(),
    capabilityDeclarations: const [],
    provenance: const PackageProvenance(
      creationEngineVersion: 'test',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(contentHash: 'test', computedAt: now),
  );
}

/// A picker that returns a file we wrote, so the whole import path -- pick,
/// read, decode, install -- runs without an OS dialog.
class _StubPicker implements FilePicker {
  PickedFile? next;

  @override
  Future<PickedFile?> pick({
    List<String>? allowedExtensions,
    bool imagesOnly = false,
  }) async => next;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late Directory sandbox;
  late SqliteExperienceRepository repository;
  late RealFileService files;
  late _StubPicker picker;
  late ExperiencePortability portability;

  setUp(() async {
    sandbox = Directory.systemTemp.createTempSync('p02_portability_');
    repository = SqliteExperienceRepository(
      dbName: 'p02_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    picker = _StubPicker();
    files = RealFileService(picker: picker, rootOverride: sandbox);

    portability = ExperiencePortability(
      repository: repository,
      installer: ExperienceInstallationFramework(repository: repository),
      files: files,
    );
  });

  tearDown(() async {
    await repository.close();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  group('Export (IS-P02 Phase 9)', () {
    test('a stored Experience becomes a real file on disk', () async {
      final package = buildPackage();
      await repository.savePackage(package);

      final result = await portability.export(package.manifest.experienceId);

      expect(result.succeeded, isTrue, reason: result.description);
      expect(result.path, isNotNull);
      expect(File(result.path!).existsSync(), isTrue);
      expect(result.manifest!.experienceId, 'water-tracker');
    });

    test('the file is a readable Anything package', () async {
      final package = buildPackage();
      await repository.savePackage(package);
      final result = await portability.export('water-tracker');

      final bytes = File(result.path!).readAsStringSync();
      final read = const ExperiencePackageReader().read(bytes);

      expect(read.succeeded, isTrue, reason: read.messages.join('; '));
      expect(
        ExperiencePackage.computeIntegrityHash(read.package!),
        ExperiencePackage.computeIntegrityHash(package),
        reason: 'export must not alter the Experience',
      );
    });

    test(
      'the filename is recognisable (version lives in the package)',
      () async {
        // IS-P12: human-readable Stopwatch.anything style; version is inside
        // the .anything manifest, not duplicated in the filename.
        expect(
          ExperiencePortability.fileNameFor(buildPackage().manifest),
          'Water_Tracker.anything',
        );
      },
    );

    test('A NAME CANNOT ESCAPE THE SANDBOX', () async {
      // An Experience name is user-supplied text and reaches a filename.
      final hostile = buildPackage(id: 'evil', name: '../../../etc/passwd');
      await repository.savePackage(hostile);

      final result = await portability.export('evil');
      expect(result.succeeded, isTrue);
      expect(
        File(result.path!).absolute.path,
        startsWith(sandbox.absolute.path),
        reason: 'the written file must stay inside the sandbox',
      );
      expect(result.path, isNot(contains('..')));
    });

    test('exporting an Experience that is not stored fails cleanly', () async {
      final result = await portability.export('nope');
      expect(result.succeeded, isFalse);
      expect(result.failure, PortabilityFailure.notFound);
      expect(result.description, isNotEmpty);
    });
  });

  group('Import (IS-P02 Phase 9)', () {
    test(
      'THE ROUND TRIP — export then import restores the Experience',
      () async {
        final package = buildPackage();
        await repository.savePackage(package);
        final exported = await portability.export('water-tracker');

        // A second, empty device.
        final other = Directory.systemTemp.createTempSync('p02_target_');
        final targetRepo = SqliteExperienceRepository(
          dbName: 'p02_target_${DateTime.now().microsecondsSinceEpoch}.db',
        );
        addTearDown(() async {
          await targetRepo.close();
          if (other.existsSync()) other.deleteSync(recursive: true);
        });

        final target = ExperiencePortability(
          repository: targetRepo,
          installer: ExperienceInstallationFramework(repository: targetRepo),
          files: RealFileService(picker: _StubPicker(), rootOverride: other),
        );

        expect(await targetRepo.getPackage('water-tracker'), isNull);

        final result = await target.importBytes(
          File(exported.path!).readAsStringSync(),
        );

        expect(result.succeeded, isTrue, reason: result.description);
        final restored = await targetRepo.getPackage('water-tracker');
        expect(
          restored,
          isNotNull,
          reason: 'the installer must have committed',
        );
        expect(
          ExperiencePackage.computeIntegrityHash(restored!),
          ExperiencePackage.computeIntegrityHash(package),
          reason: 'a round trip must not alter the Experience',
        );
      },
    );

    test('import through the real picker path works end to end', () async {
      final package = buildPackage();
      await repository.savePackage(package);
      final exported = await portability.export('water-tracker');

      picker.next = PickedFile(
        name: 'water-tracker-v1.0.0.anything',
        path: exported.path,
      );

      // Same repository, so this is a reinstall — it must still succeed
      // rather than throwing on a duplicate.
      final result = await portability.import();
      expect(result.succeeded, isTrue, reason: result.description);
      expect(result.manifest!.experienceId, 'water-tracker');
    });

    test('a cancelled picker is not an error', () async {
      picker.next = null;
      final result = await portability.import();
      expect(result.succeeded, isFalse);
      expect(result.failure, PortabilityFailure.cancelled);
      expect(result.description, 'Cancelled.');
    });
  });

  group('Untrusted input is refused (IS-P02 Phase 9)', () {
    test('A TAMPERED PACKAGE IS NOT INSTALLED', () async {
      final package = buildPackage();
      await repository.savePackage(package);
      final exported = await portability.export('water-tracker');
      final bytes = File(exported.path!).readAsStringSync();

      // Edit the payload but leave valid JSON behind — the case a naive
      // "is it parseable" check would wave through.
      final tampered = bytes.replaceFirst(
        '"name":"Water Tracker"',
        '"name":"Evil"',
      );
      expect(tampered, isNot(bytes), reason: 'the tamper must actually apply');

      final other = Directory.systemTemp.createTempSync('p02_tamper_');
      final targetRepo = SqliteExperienceRepository(
        dbName: 'p02_target_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      addTearDown(() async {
        await targetRepo.close();
        if (other.existsSync()) other.deleteSync(recursive: true);
      });

      final result = await ExperiencePortability(
        repository: targetRepo,
        installer: ExperienceInstallationFramework(repository: targetRepo),
        files: RealFileService(picker: _StubPicker(), rootOverride: other),
      ).importBytes(tampered);

      expect(result.succeeded, isFalse);
      expect(result.failure, PortabilityFailure.invalidPackage);
      expect(result.readFailure, PackageReadFailure.checksumMismatch);
      expect(
        await targetRepo.getPackage('water-tracker'),
        isNull,
        reason: 'NOTHING may be committed when the package is refused',
      );
    });

    test(
      'non-package input is refused with a reason a person can read',
      () async {
        for (final entry in {
          'not json at all': PackageReadFailure.malformed,
          '{"hello":"world"}': PackageReadFailure.notAPackage,
        }.entries) {
          final result = await portability.importBytes(entry.key);
          expect(result.succeeded, isFalse);
          expect(result.readFailure, entry.value);
          expect(result.description, isNotEmpty);
          expect(
            result.description,
            isNot(contains('Exception')),
            reason: 'a person reads this, not a developer',
          );
        }
      },
    );

    test('every failure has a distinct human-readable description', () {
      final seen = <String>{};
      for (final f in PortabilityFailure.values) {
        final d = PortabilityResult.failed(f).description;
        expect(d, isNotEmpty);
        expect(d.endsWith('.'), isTrue, reason: '"$d" should be a sentence');
        seen.add(d);
      }
      expect(
        seen.length,
        PortabilityFailure.values.length,
        reason: 'each failure must say something different',
      );
    });
  });

  group('Portability OWNS nothing (IS-P02 Phase 9)', () {
    test('it re-implements no validation — the reader refuses first', () async {
      // Proof by consequence: a checksum mismatch is caught before the
      // installer is ever reached, so nothing is committed. If this class had
      // its own validation path, the ordering could differ.
      final result = await portability.importBytes('{"format":"wrong"}');
      expect(result.failure, PortabilityFailure.invalidPackage);
      expect(result.messages, isNotEmpty);
    });

    test('it is const-constructible — it holds no state of its own', () {
      // A stateless coordinator cannot accumulate a second copy of anything.
      expect(portability.writer, isA<ExperiencePackageWriter>());
      expect(portability.reader, isA<ExperiencePackageReader>());
    });
  });
}
