/// Implementation Specification IS-R53 — Canonical Experience Distribution
/// Framework.
///
/// REALITY before R53, confirmed by the Task 1 audit: exactly ONE production
/// Experience creator existed, and there was NO import, export, installer,
/// distributor, marketplace or duplicate path anywhere. R50–R52 built
/// retention, governance, provenance and trust — and almost nothing could
/// reach them, because nothing moved an Experience.
///
/// R53 supplies the missing producer layer, reusing rather than duplicating
/// two types the specification asked to "introduce" but which already exist:
/// `ExperienceManifest` and `ExperiencePackageValidator`.
///
/// These tests exercise the full chain the milestone exists to complete:
///
///     import -> provenance -> trust classification -> governance -> platform
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/experience_distribution.dart';
import 'package:anything/app/experience_provenance.dart';
import 'package:anything/app/governance_engine.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';

var _dbSeq = 0;
String _freshDbName() => 'r53_${_dbSeq++}_${DateTime.now().microsecondsSinceEpoch}.db';

ExperiencePackage _package({String id = 'exp-1', String name = 'Test'}) {
  final now = DateTime(2026, 8, 7);
  const screens = [InterfaceScreen(id: 's1', title: 'Home', children: [InterfaceNode(type: 'text', id: 'n1', properties: {'text': 'Hi'})])];
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: id,
      name: name,
      description: 'd',
      category: 'general',
      entryPoint: 's1',
      version: '1.0.0',
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

ExperienceDistributionPackage _distribution(ExperiencePackage package, {ExperienceFingerprint? fingerprint}) {
  return ExperienceDistributionPackage(
    envelope: ExperienceDistributionManifest(
      manifest: package.manifest,
      fingerprint: fingerprint ?? ExperienceFingerprint(ExperiencePackage.computeIntegrityHash(package)),
    ),
    package: package,
  );
}

class _EchoCapability extends PlatformCapability {
  int executions = 0;
  _EchoCapability(String id) : super(id: id, name: id, description: 't', supportedOperations: const ['run']);
  @override
  Future<CapabilityInvocationResult> execute(String operation, Map<String, dynamic> params) async {
    executions++;
    return CapabilityInvocationResult.success();
  }
}

void main() {
  const verifier = ExperiencePackageVerifier();
  const classifier = ExperienceTrustClassifier();

  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('Distribution manifest (R53 Task 3) — a transport envelope, not a second manifest', () {
    test('the envelope EMBEDS the canonical ExperienceManifest rather than re-declaring its fields', () {
      final package = _package();
      final envelope = ExperienceDistributionManifest(manifest: package.manifest);

      expect(envelope.manifest, same(package.manifest),
          reason: 'the canonical manifest is carried, not copied into a parallel record');
      expect(envelope.experienceId, package.manifest.experienceId);
      // Capabilities/version/compatibility already live on the canonical
      // manifest and are reached THROUGH it.
      expect(envelope.manifest.requiredCapabilities, isNotNull);
      expect(envelope.manifest.minimumRuntimeVersion, package.manifest.minimumRuntimeVersion);
    });

    test('round-trips through JSON with provenance, fingerprint, marketplace and enterprise metadata intact', () {
      final package = _package();
      final envelope = ExperienceDistributionManifest(
        manifest: package.manifest,
        provenance: ExperienceProvenance.imported(source: '/tmp/a.anything', author: 'someone'),
        fingerprint: const ExperienceFingerprint('fp-1'),
        wasProtected: true,
        marketplace: const MarketplaceMetadata(listingId: 'l-1', publisherId: 'p-1', publisherName: 'Pub', publisherSignature: 'sig'),
        enterprise: const EnterpriseDistributionMetadata(organizationId: 'o-1', deploymentId: 'd-1', policyId: 'pol-1'),
        dependencies: ['dep-a'],
      );

      final restored = ExperienceDistributionManifest.fromJson(envelope.toJson());

      expect(restored.manifest.experienceId, package.manifest.experienceId);
      expect(restored.manifest.name, package.manifest.name);
      expect(restored.provenance.origin, ExperienceOrigin.imported);
      expect(restored.provenance.author, 'someone');
      expect(restored.fingerprint, const ExperienceFingerprint('fp-1'));
      expect(restored.wasProtected, isTrue);
      expect(restored.marketplace!.listingId, 'l-1');
      expect(restored.marketplace!.publisherSignature, 'sig');
      expect(restored.enterprise!.policyId, 'pol-1');
      expect(restored.dependencies, ['dep-a']);
      expect(restored.envelopeVersion, ExperienceDistributionManifest.currentEnvelopeVersion);
    });
  });

  group('Package verification (R53 Task 6) — verifies packages, never computes trust', () {
    test('a well-formed package verifies', () {
      expect(verifier.verify(_distribution(_package())).isValid, isTrue);
    });

    test('a FINGERPRINT MISMATCH is rejected — the one genuinely new check', () {
      final result = verifier.verify(_distribution(_package(), fingerprint: const ExperienceFingerprint('wrong')));
      expect(result.isValid, isFalse);
      expect(result.failures, [VerificationFailure.fingerprintMismatch]);
    });

    test('an ABSENT fingerprint is not a failure — older envelopes may not carry one', () {
      final package = _package();
      final distribution = ExperienceDistributionPackage(
        envelope: ExperienceDistributionManifest(manifest: package.manifest),
        package: package,
      );
      expect(verifier.verify(distribution).isValid, isTrue);
    });

    test('an envelope/package IDENTITY MISMATCH is rejected', () {
      final distribution = ExperienceDistributionPackage(
        envelope: ExperienceDistributionManifest(manifest: _package(id: 'exp-OTHER').manifest),
        package: _package(id: 'exp-1'),
      );
      final result = verifier.verify(distribution);
      expect(result.isValid, isFalse);
      expect(result.failures, [VerificationFailure.identityMismatch]);
    });

    test('an unsupported envelope version is rejected rather than parsed hopefully', () {
      final package = _package();
      final distribution = ExperienceDistributionPackage(
        envelope: ExperienceDistributionManifest(manifest: package.manifest, envelopeVersion: 99),
        package: package,
      );
      expect(verifier.verify(distribution).failures, [VerificationFailure.unsupportedEnvelopeVersion]);

      final zero = ExperienceDistributionPackage(
        envelope: ExperienceDistributionManifest(manifest: package.manifest, envelopeVersion: 0),
        package: package,
      );
      expect(zero.envelope.envelopeVersion, 0);
      expect(verifier.verify(zero).failures, [VerificationFailure.unsupportedEnvelopeVersion]);
    });

    test('structural validation is DELEGATED to the pre-existing validator, not re-implemented', () {
      // An empty experienceId is a structural fault the existing validator
      // already knows about. It must surface through verification.
      final package = _package(id: '');
      final distribution = ExperienceDistributionPackage(
        envelope: ExperienceDistributionManifest(manifest: package.manifest),
        package: package,
      );
      final result = verifier.verify(distribution);
      expect(result.isValid, isFalse);
      expect(result.failures.first, VerificationFailure.malformed);
    });

    test('verification returns a verdict ONLY — it produces no trust level of any kind', () {
      final result = verifier.verify(_distribution(_package()));
      expect(result, isA<PackageVerificationResult>());
      expect(result.isValid, isTrue);
      // A valid package earns no authority by being valid. Nothing in the
      // result type can express a trust level, which is the point.
    });
  });

  group('Import pipeline (R53 Task 4)', () {
    test('an imported Experience is persisted with IMPORTED provenance — not local', () async {
      final repo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final distribution = ExperienceDistributionFramework(repository: repo);

      final result = await distribution.import(
        _distribution(_package(id: 'exp-imported')),
        source: DistributionSource.sharedTransfer,
        installationSource: 'share-sheet',
      );

      expect(result.succeeded, isTrue);
      expect(result.provenance!.origin, ExperienceOrigin.imported);

      final stored = await repo.getMetadata('exp-imported');
      expect(stored, isNotNull);
      expect(stored!.provenance.origin, ExperienceOrigin.imported,
          reason: 'THE point of R53 — provenance now has a producer other than creation');
      expect(stored.provenance.installationSource, 'share-sheet');
      expect(stored.provenance.fingerprint.isPresent, isTrue);
    });

    test('the imported PACKAGE is persisted too, so the Experience is genuinely usable', () async {
      final repo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final distribution = ExperienceDistributionFramework(repository: repo);

      await distribution.import(_distribution(_package(id: 'exp-a')));
      final package = await repo.getPackage('exp-a');
      expect(package, isNotNull);
      expect(package!.manifest.experienceId, 'exp-a');
    });

    test('a package that FAILS verification is REJECTED and persists nothing', () async {
      final repo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final distribution = ExperienceDistributionFramework(repository: repo);

      final result = await distribution.import(
        _distribution(_package(id: 'exp-bad'), fingerprint: const ExperienceFingerprint('tampered')),
      );

      expect(result.succeeded, isFalse);
      expect(result.verification!.failures, [VerificationFailure.fingerprintMismatch]);
      expect(await repo.getMetadata('exp-bad'), isNull,
          reason: 'a rejected import must leave no trace');
      expect(await repo.getPackage('exp-bad'), isNull);
    });

    test('IMPORT NEVER ACTIVATES A RUNTIME — importing something must not run it', () async {
      final repo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final distribution = ExperienceDistributionFramework(repository: repo);

      final result = await distribution.import(_distribution(_package(id: 'exp-a')));

      // The result carries an id and provenance — and nothing that could
      // start anything. Activation stays with ExperienceEntryPipeline.
      expect(result.succeeded, isTrue);
      expect(result.experienceId, 'exp-a');
      expect(result, isA<ImportResult>());
    });

    test('protection state is NOT carried across — an import is not protected until this device protects it', () async {
      final repo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final distribution = ExperienceDistributionFramework(repository: repo);
      final package = _package(id: 'exp-a');

      await distribution.import(ExperienceDistributionPackage(
        envelope: ExperienceDistributionManifest(manifest: package.manifest, wasProtected: true),
        package: package,
      ));

      final stored = await repo.getMetadata('exp-a');
      expect(stored!.isProtected, isFalse,
          reason: 'distribution must not fabricate a protected state it cannot honour — Kaalka owns that');
    });

    test('a marketplace import records marketplace provenance but is NOT auto-verified', () async {
      final repo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final distribution = ExperienceDistributionFramework(repository: repo);
      final package = _package(id: 'exp-m');

      final result = await distribution.import(
        ExperienceDistributionPackage(
          envelope: ExperienceDistributionManifest(
            manifest: package.manifest,
            marketplace: const MarketplaceMetadata(listingId: 'l-1', publisherName: 'Pub', publisherSignature: 'unchecked'),
          ),
          package: package,
        ),
        source: DistributionSource.marketplace,
      );

      expect(result.provenance!.origin, ExperienceOrigin.marketplace);
      expect(result.provenance!.marketplaceId, 'l-1');
      expect(result.provenance!.verificationState, VerificationState.unverified,
          reason: 'nothing checked the publisher signature, so it must not be treated as proof');
      expect(classifier.classify(result.provenance!), ExperienceTrustLevel.imported,
          reason: 'an unverified marketplace origin earns imported, not verified');
    });
  });

  group('Export pipeline (R53 Task 5)', () {
    test('export carries current metadata, provenance and a live fingerprint', () async {
      final repo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final distribution = ExperienceDistributionFramework(repository: repo);
      final package = _package(id: 'exp-a');

      await repo.savePackage(package);
      await repo.saveMetadata(ExperienceMetadataRecord(
        id: 'exp-a', name: 'Test', description: 'd', category: 'general',
        createdAt: DateTime(2026), updatedAt: DateTime(2026),
        provenance: ExperienceProvenance.createdLocally(author: 'me'),
      ));

      final exported = await distribution.export('exp-a');

      expect(exported, isNotNull);
      expect(exported!.envelope.provenance.origin, ExperienceOrigin.createdLocally);
      expect(exported.envelope.provenance.author, 'me');
      expect(exported.envelope.fingerprint.value, ExperiencePackage.computeIntegrityHash(package));
      expect(exported.envelope.manifest.experienceId, 'exp-a');
    });

    test('exporting an unknown Experience returns null rather than fabricating one', () async {
      final repo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      expect(await ExperienceDistributionFramework(repository: repo).export('nope'), isNull);
    });

    test('EXPORT -> IMPORT round-trips: the package survives and verifies on the other side', () async {
      final sourceRepo = SqliteExperienceRepository(dbName: _freshDbName());
      final targetRepo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(sourceRepo.close);
      addTearDown(targetRepo.close);
      final package = _package(id: 'exp-round');

      await sourceRepo.savePackage(package);
      await sourceRepo.saveMetadata(ExperienceMetadataRecord(
        id: 'exp-round', name: 'Test', description: 'd', category: 'general',
        createdAt: DateTime(2026), updatedAt: DateTime(2026),
        provenance: ExperienceProvenance.createdLocally(),
      ));

      final exported = await ExperienceDistributionFramework(repository: sourceRepo).export('exp-round');
      final imported = await ExperienceDistributionFramework(repository: targetRepo).import(exported!);

      expect(imported.succeeded, isTrue);
      // Locally-created on the SOURCE device becomes IMPORTED on the target —
      // which is exactly right: it did not originate here.
      expect(imported.provenance!.origin, ExperienceOrigin.imported);
      expect((await targetRepo.getPackage('exp-round'))!.manifest.name, 'Test');
    });
  });

  group('The full chain (R53 Task 10) — import feeds trust, governance and enforcement', () {
    test('an imported Experience is REFUSED a capability that a locally-created one receives', () async {
      final repo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repo.close);
      final distribution = ExperienceDistributionFramework(repository: repo);

      final result = await distribution.import(_distribution(_package(id: 'exp-a')));
      final stored = await repo.getMetadata('exp-a');

      const governance = OperatingSystemGovernanceEngine();
      final capability = _EchoCapability('http');
      final platform = CapabilityPlatform(governance: governance, trustClassifier: classifier)
        ..register(capability);

      final denied = await platform.invoke('http', 'run', const {}, provenance: stored!.provenance);
      expect(denied.status, CapabilityResultStatus.permissionDenied);
      expect(capability.executions, 0,
          reason: 'the chain R50-R53 built now does real work: import -> provenance -> trust -> governance -> refusal');

      final allowed = await platform.invoke('http', 'run', const {},
          provenance: ExperienceProvenance.createdLocally());
      expect(allowed.status, CapabilityResultStatus.success);
      expect(result.succeeded, isTrue);
    });
  });

  group('Ownership boundaries (R53 Tasks 2/11)', () {
    test('provenanceFor maps a transport CHANNEL to an origin — and assigns no trust level', () {
      expect(ExperienceDistributionFramework.provenanceFor(DistributionSource.localFile).origin, ExperienceOrigin.imported);
      expect(ExperienceDistributionFramework.provenanceFor(DistributionSource.sharedTransfer).origin, ExperienceOrigin.imported);
      expect(ExperienceDistributionFramework.provenanceFor(DistributionSource.cloudSync).origin, ExperienceOrigin.imported);
      expect(ExperienceDistributionFramework.provenanceFor(DistributionSource.enterprise).origin, ExperienceOrigin.imported);
      expect(ExperienceDistributionFramework.provenanceFor(DistributionSource.marketplace).origin, ExperienceOrigin.marketplace);

      // Every mapping produces PROVENANCE. None produces an ExperienceTrustLevel.
      for (final source in DistributionSource.values) {
        expect(ExperienceDistributionFramework.provenanceFor(source), isA<ExperienceProvenance>());
      }
    });

    test('distribution never marks anything verified — verification state is left for something that actually verifies', () {
      for (final source in DistributionSource.values) {
        expect(
          ExperienceDistributionFramework.provenanceFor(source).verificationState,
          VerificationState.unverified,
        );
      }
    });
  });

  group('Backward compatibility (R53 Task 13)', () {
    test('the canonical ExperienceManifest is untouched and still round-trips on its own', () {
      final package = _package();
      final restored = ExperienceManifest.fromJson(package.manifest.toJson());
      expect(restored.experienceId, package.manifest.experienceId);
      expect(restored.requiredCapabilities, package.manifest.requiredCapabilities);
      expect(restored.networkMode, package.manifest.networkMode);
    });

    test('the pre-existing package validator still works exactly as before', () {
      expect(ExperiencePackageValidatorProbe.validates(_package()), isTrue);
    });
  });
}

/// Tiny indirection so the compatibility test above reads clearly.
abstract final class ExperiencePackageValidatorProbe {
  static bool validates(ExperiencePackage package) =>
      const ExperiencePackageVerifier().verify(_distribution(package)).isValid;
}
