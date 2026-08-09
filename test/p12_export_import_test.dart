/// IS-P12 — .anything export path + import round-trip (no AI).
library;

import 'dart:io';

import 'package:anything/app/experience_portability.dart';
import 'package:anything/app/experience_installation.dart';
import 'package:anything/app/experience_provenance.dart';
import 'package:anything/app/experience_commit.dart';
import 'package:anything/capabilities/adapters/file_service_adapter.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/timing_interface_factory.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

var _dbSeq = 0;
String _freshDbName() =>
    'p12_${_dbSeq++}_${DateTime.now().microsecondsSinceEpoch}.db';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('export writes unique .anything files under sandbox exports', () async {
    final root = await Directory.systemTemp.createTemp('p12_export_');
    final files = RealFileService(rootOverride: root);
    const name = 'Stopwatch.anything';
    final written = await files.writeExport(name, '{"ok":true}');
    expect(written, isNotNull);
    expect(written!.existsSync(), isTrue);
    expect(written.path, contains(name));

    final second = await files.writeExport(name, '{"ok":2}');
    expect(second, isNotNull);
    expect(second!.path, isNot(equals(written.path)));
    expect(p.basename(second.path), contains('Stopwatch'));
  });

  test('importBytes restores timing package without AI', () async {
    final repo = SqliteExperienceRepository(dbName: _freshDbName());
    final commits = ExperienceCommitFramework(repository: repo);
    final installer = ExperienceInstallationFramework(
      repository: repo,
      commitFramework: commits,
    );
    final files = RealFileService(
      rootOverride: Directory.systemTemp.createTempSync('p12_files_'),
    );
    final portability = ExperiencePortability(
      repository: repo,
      installer: installer,
      files: files,
    );

    final now = DateTime.now();
    var package = ExperiencePackage(
      manifest: ExperienceManifest(
        experienceId: 'exp-stopwatch-rt',
        name: 'Stopwatch',
        description: 'Elapsed time',
        createdAt: now,
        updatedAt: now,
        requiredCapabilities: const ['timers'],
      ),
      interface: const InterfaceDefinition(),
      behavior: const BehaviorGraph(),
      state: const StateSchema(),
      provenance: const PackageProvenance(
        creationEngineVersion: '1.0.0',
        specVersion: 1,
        planVersion: 1,
      ),
      integrity: PackageIntegrity(contentHash: '', computedAt: now),
    );
    package = const TimingInterfaceFactory().applyToPackage(
      package,
      name: 'Stopwatch',
    );
    package = ExperiencePackage(
      packageVersion: package.packageVersion,
      manifest: package.manifest,
      interface: package.interface,
      behavior: package.behavior,
      state: package.state,
      data: package.data,
      services: package.services,
      networkDeclarations: package.networkDeclarations,
      capabilityDeclarations: package.capabilityDeclarations,
      permissionDeclarations: package.permissionDeclarations,
      protection: package.protection,
      provenance: package.provenance,
      integrity: PackageIntegrity(
        contentHash: ExperiencePackage.computeIntegrityHash(package),
        computedAt: DateTime.now(),
      ),
    );

    final committed = await commits.commit(
      experienceId: package.manifest.experienceId,
      origin: CommitOrigin.creation,
      package: package,
      metadata: ExperienceMetadataRecord(
        id: package.manifest.experienceId,
        name: package.manifest.name,
        description: package.manifest.description,
        category: package.manifest.category,
        createdAt: now,
        updatedAt: now,
        provenance: ExperienceProvenance.createdLocally(
          at: now,
          fingerprint: ExperienceFingerprint(
            ExperiencePackage.computeIntegrityHash(package),
          ),
        ),
      ),
    );
    expect(committed.succeeded, isTrue);

    final exported = await portability.export(package.manifest.experienceId);
    expect(exported.succeeded, isTrue);
    expect(exported.path, isNotNull);
    expect(exported.description, contains('Export successful'));
    expect(exported.description, contains('Saved:'));

    final removed = await commits.remove(package.manifest.experienceId);
    expect(removed.succeeded, isTrue);
    expect(await repo.getPackage(package.manifest.experienceId), isNull);

    final bytes = File(exported.path!).readAsStringSync();
    final imported = await portability.importBytes(bytes);
    expect(imported.succeeded, isTrue, reason: imported.description);
    final restored = await repo.getPackage(package.manifest.experienceId);
    expect(restored, isNotNull);
    expect(restored!.manifest.name, 'Stopwatch');
    expect(restored.manifest.requiredCapabilities, contains('timers'));
  });
}
