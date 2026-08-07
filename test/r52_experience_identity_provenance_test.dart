/// Implementation Specification IS-R52 — Canonical Experience Identity,
/// Provenance and Trust Classification.
///
/// REALITY before R52: R51 built a governance framework whose trust model was
/// dormant. `ExperienceMetadataRecord` had NO provenance fields at all, there
/// was exactly ONE production creation site and it recorded nothing about
/// origin, and `ExperienceTrustLevel` defaulted to `local` everywhere because
/// nothing computed anything else. The rules were real and enforced; they
/// simply never had a reason to fire.
///
/// R52 makes trust COMPUTED. These tests prove the four-verb ownership split
/// holds end to end:
///
///     ExperienceTrustClassifier   COMPUTES
///     OperatingSystemGovernanceEngine  CONSUMES
///     CapabilityPlatform          ENFORCES
///     SqliteExperienceRepository  STORES
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:anything/app/experience_provenance.dart';
import 'package:anything/app/governance_engine.dart';
import 'package:anything/capabilities/platform/capability_platform.dart';
import 'package:anything/storage/sqlite_experience_repository.dart';

class _EchoCapability extends PlatformCapability {
  int executions = 0;
  _EchoCapability(String id)
    : super(id: id, name: id, description: 'test', supportedOperations: const ['run']);

  @override
  Future<CapabilityInvocationResult> execute(String operation, Map<String, dynamic> params) async {
    executions++;
    return CapabilityInvocationResult.success();
  }
}

var _dbSeq = 0;
String _freshDbName() => 'r52_${_dbSeq++}_${DateTime.now().microsecondsSinceEpoch}.db';

ExperienceMetadataRecord _record(String id, {ExperienceProvenance? provenance}) {
  final now = DateTime(2026, 8, 7, 10);
  return ExperienceMetadataRecord(
    id: id,
    name: 'Experience $id',
    description: 'd',
    category: 'general',
    createdAt: now,
    updatedAt: now,
    provenance: provenance ?? const ExperienceProvenance(),
  );
}

void main() {
  const classifier = ExperienceTrustClassifier();

  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('Trust classification (R52 Task 4/6) — computed, not assumed', () {
    test('a locally-created Experience classifies as LOCAL', () {
      expect(classifier.classify(ExperienceProvenance.createdLocally()), ExperienceTrustLevel.local);
    });

    test('an IMPORTED Experience classifies as imported — NOT local, which is the whole point of R52', () {
      expect(classifier.classify(ExperienceProvenance.imported()), ExperienceTrustLevel.imported);
    });

    test('a first-party Experience classifies as TRUSTED', () {
      expect(classifier.classify(ExperienceProvenance.firstParty()), ExperienceTrustLevel.trusted);
    });

    test('a VERIFIED marketplace Experience classifies as verified; an unverified one only as imported', () {
      const verified = ExperienceProvenance(
        origin: ExperienceOrigin.marketplace,
        verificationState: VerificationState.verified,
      );
      const unverified = ExperienceProvenance(origin: ExperienceOrigin.marketplace);

      expect(classifier.classify(verified), ExperienceTrustLevel.verified);
      expect(classifier.classify(unverified), ExperienceTrustLevel.imported,
          reason: 'marketplace origin alone is a claim, not proof');
    });

    test('UNKNOWN origin classifies as experimental — weaker than imported, but not untrusted', () {
      expect(classifier.classify(const ExperienceProvenance()), ExperienceTrustLevel.experimental,
          reason: '"we do not know" is weaker than "we know it was imported"');
      expect(classifier.classify(const ExperienceProvenance()), isNot(ExperienceTrustLevel.untrusted),
          reason: 'untrusted is reserved for an explicit decision, never an absence of information');
    });

    test('QUARANTINE and REVOCATION outrank origin — even a first-party Experience becomes untrusted', () {
      expect(classifier.classify(ExperienceProvenance.firstParty().quarantined()), ExperienceTrustLevel.untrusted);
      expect(classifier.classify(ExperienceProvenance.firstParty().revoked()), ExperienceTrustLevel.untrusted);
      expect(classifier.classify(ExperienceProvenance.createdLocally().quarantined()), ExperienceTrustLevel.untrusted);
    });

    test('verification state can LOWER trust but never RAISE it', () {
      // Marking an imported Experience "verified" does not promote it, because
      // R52 verifies nothing yet — the signature field is a recorded claim.
      final claimed = ExperienceProvenance.imported(signature: 'not-actually-checked').verified();
      expect(classifier.classify(claimed), ExperienceTrustLevel.imported,
          reason: 'an unchecked claim must not manufacture trust');
    });

    test('classification is deterministic and total — every origin yields a level', () {
      for (final origin in ExperienceOrigin.values) {
        final level = classifier.classify(ExperienceProvenance(origin: origin));
        expect(ExperienceTrustLevel.values, contains(level));
        expect(classifier.classify(ExperienceProvenance(origin: origin)), level, reason: 'stable across calls');
      }
    });
  });

  group('Trust transitions (R52 Task 8)', () {
    test('verify / revoke / quarantine / promote / demote each produce a NEW provenance, never a mutation', () {
      final original = ExperienceProvenance.imported();
      expect(original.verificationState, VerificationState.unverified);

      expect(original.verified().verificationState, VerificationState.verified);
      expect(original.revoked().verificationState, VerificationState.revoked);
      expect(original.quarantined().verificationState, VerificationState.quarantined);
      expect(original.demoted().verificationState, VerificationState.quarantined);

      expect(original.verificationState, VerificationState.unverified,
          reason: 'the original value object must be untouched — transitions are replacements');
    });

    test('promote lifts a quarantine to UNVERIFIED, not straight to verified', () {
      final restored = ExperienceProvenance.imported().quarantined().promoted();
      expect(restored.verificationState, VerificationState.unverified,
          reason: 'promotion restores eligibility; it does not manufacture proof');
      expect(classifier.classify(restored), ExperienceTrustLevel.imported);
    });

    test('a quarantine round-trip genuinely changes what a capability may do', () {
      final quarantined = ExperienceProvenance.createdLocally().quarantined();
      expect(classifier.classify(quarantined), ExperienceTrustLevel.untrusted);
      expect(classifier.classify(quarantined.promoted()), ExperienceTrustLevel.local);
    });
  });

  group('Persistence (R52 Task 7) — no migration break', () {
    test('provenance SURVIVES a genuine restart', () async {
      final dbName = _freshDbName();
      final imported = ExperienceProvenance.imported(
        at: DateTime(2026, 8, 1),
        source: '/tmp/shared/app.anything',
        author: 'someone-else',
        fingerprint: const ExperienceFingerprint('abc123'),
      );

      final repo1 = SqliteExperienceRepository(dbName: dbName);
      await repo1.saveMetadata(_record('exp-a', provenance: imported));
      await repo1.close();

      final repo2 = SqliteExperienceRepository(dbName: dbName);
      addTearDown(repo2.close);
      final restored = await repo2.getMetadata('exp-a');

      expect(restored, isNotNull);
      expect(restored!.provenance.origin, ExperienceOrigin.imported);
      expect(restored.provenance.installationSource, '/tmp/shared/app.anything');
      expect(restored.provenance.author, 'someone-else');
      expect(restored.provenance.importedAt, DateTime(2026, 8, 1));
      expect(restored.provenance.fingerprint.value, 'abc123');

      // And the trust computed from it survives with it.
      expect(classifier.classify(restored.provenance), ExperienceTrustLevel.imported);
    });

    test('a record written WITHOUT provenance reads back as unknown origin — truthful, not fabricated', () async {
      final repo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repo.close);

      await repo.saveMetadata(_record('exp-legacy'));
      final restored = await repo.getMetadata('exp-legacy');

      expect(restored!.provenance.origin, ExperienceOrigin.unknown);
      expect(classifier.classify(restored.provenance), ExperienceTrustLevel.experimental);
    });

    test('a corrupt provenance blob degrades to unknown rather than failing the metadata read', () async {
      final dbName = _freshDbName();
      final repo = SqliteExperienceRepository(dbName: dbName);
      addTearDown(repo.close);
      await repo.saveMetadata(_record('exp-a', provenance: ExperienceProvenance.imported()));

      final db = await repo.database;
      await db.update('experiences', {'provenance': '{ not valid json'}, where: 'id = ?', whereArgs: ['exp-a']);

      final restored = await repo.getMetadata('exp-a');
      expect(restored, isNotNull, reason: 'a metadata read must not fail because provenance is unreadable');
      expect(restored!.provenance.origin, ExperienceOrigin.unknown);
      expect(restored.name, 'Experience exp-a', reason: 'the rest of the record is intact');
    });

    test('listAll() carries provenance too, not just getMetadata()', () async {
      final repo = SqliteExperienceRepository(dbName: _freshDbName());
      addTearDown(repo.close);

      await repo.saveMetadata(_record('exp-a', provenance: ExperienceProvenance.firstParty()));
      await repo.saveMetadata(_record('exp-b', provenance: ExperienceProvenance.imported()));

      final all = await repo.listAll();
      final byId = {for (final r in all) r.id: r};
      expect(byId['exp-a']!.provenance.origin, ExperienceOrigin.firstParty);
      expect(byId['exp-b']!.provenance.origin, ExperienceOrigin.imported);
    });

    test('provenance round-trips through toJson/fromJson with every field preserved', () {
      const original = ExperienceProvenance(
        origin: ExperienceOrigin.marketplace,
        installationSource: 'store',
        author: 'a',
        signature: 'sig',
        verificationState: VerificationState.verified,
        marketplaceId: 'm-1',
        cloudId: 'c-1',
        fingerprint: ExperienceFingerprint('fp'),
      );
      final restored = ExperienceProvenance.fromJson(original.toJson());

      expect(restored.origin, original.origin);
      expect(restored.installationSource, original.installationSource);
      expect(restored.author, original.author);
      expect(restored.signature, original.signature);
      expect(restored.verificationState, original.verificationState);
      expect(restored.marketplaceId, original.marketplaceId);
      expect(restored.cloudId, original.cloudId);
      expect(restored.fingerprint, original.fingerprint);
    });
  });

  group('Governance integration (R52 Task 5) — classifier computes, governance consumes, platform enforces', () {
    const governance = OperatingSystemGovernanceEngine();

    test('an IMPORTED Experience is refused a capability an untrusted-floor rule guards', () async {
      // http requires `local`; imported sits below it.
      final capability = _EchoCapability('http');
      final platform = CapabilityPlatform(governance: governance, trustClassifier: classifier)
        ..register(capability);

      final result = await platform.invoke(
        'http', 'run', const {},
        provenance: ExperienceProvenance.imported(),
      );

      expect(result.status, CapabilityResultStatus.permissionDenied);
      expect(capability.executions, 0, reason: 'computed trust genuinely changes what runs');
    });

    test('the SAME capability succeeds for a locally-created Experience', () async {
      final capability = _EchoCapability('http');
      final platform = CapabilityPlatform(governance: governance, trustClassifier: classifier)
        ..register(capability);

      final result = await platform.invoke(
        'http', 'run', const {},
        provenance: ExperienceProvenance.createdLocally(),
      );

      expect(result.status, CapabilityResultStatus.success);
      expect(capability.executions, 1);
    });

    test('quarantining a locally-created Experience revokes its capability access', () async {
      final capability = _EchoCapability('files');
      final platform = CapabilityPlatform(governance: governance, trustClassifier: classifier)
        ..register(capability);

      final allowed = await platform.invoke('files', 'run', const {},
          provenance: ExperienceProvenance.createdLocally());
      expect(allowed.status, CapabilityResultStatus.success);

      final denied = await platform.invoke('files', 'run', const {},
          provenance: ExperienceProvenance.createdLocally().quarantined());
      expect(denied.status, CapabilityResultStatus.permissionDenied,
          reason: 'a quarantine must take effect at the capability boundary');
    });

    test('PROVENANCE WINS over a caller-asserted trust level — trust must be computed, not claimed', () async {
      final capability = _EchoCapability('http');
      final platform = CapabilityPlatform(governance: governance, trustClassifier: classifier)
        ..register(capability);

      // A caller claims `trusted` while handing in imported provenance.
      final result = await platform.invoke(
        'http', 'run', const {},
        trustLevel: ExperienceTrustLevel.trusted,
        provenance: ExperienceProvenance.imported(),
      );

      expect(result.status, CapabilityResultStatus.permissionDenied,
          reason: 'a caller must not be able to assert its way past classification');
      expect(capability.executions, 0);
    });

    test('trustFor() exposes the canonical computation, and falls back safely with no classifier', () {
      final withClassifier = CapabilityPlatform(trustClassifier: classifier);
      expect(withClassifier.trustFor(ExperienceProvenance.imported()), ExperienceTrustLevel.imported);

      final without = CapabilityPlatform();
      expect(without.trustFor(ExperienceProvenance.imported()), ExperienceTrustLevel.local,
          reason: 'a platform built without a classifier behaves exactly as pre-R52');
    });
  });

  group('Backward compatibility (R52 Task 13)', () {
    test('ExperienceMetadataRecord constructed WITHOUT provenance still works and defaults to unknown', () {
      final record = _record('exp-a');
      expect(record.provenance.origin, ExperienceOrigin.unknown);
      expect(record.identity.experienceId, 'exp-a');
      expect(record.identity.fingerprint.isPresent, isFalse);
    });

    test('invoke() with no provenance uses the pre-R52 trustLevel path unchanged', () async {
      const governance = OperatingSystemGovernanceEngine();
      final capability = _EchoCapability('http');
      final platform = CapabilityPlatform(governance: governance, trustClassifier: classifier)
        ..register(capability);

      final result = await platform.invoke('http', 'run', const {});
      expect(result.status, CapabilityResultStatus.success,
          reason: 'the default trust level must keep ordinary callers working');
    });

    test('copyWith replaces provenance without disturbing the rest of the record', () {
      final original = _record('exp-a', provenance: ExperienceProvenance.createdLocally());
      final updated = original.copyWith(provenance: ExperienceProvenance.imported());

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.createdAt, original.createdAt);
      expect(updated.provenance.origin, ExperienceOrigin.imported);
      expect(original.provenance.origin, ExperienceOrigin.createdLocally, reason: 'original untouched');
    });

    test('the fingerprint type distinguishes absent from empty and compares by value', () {
      expect(ExperienceFingerprint.none.isPresent, isFalse);
      expect(const ExperienceFingerprint('x').isPresent, isTrue);
      expect(const ExperienceFingerprint('x'), const ExperienceFingerprint('x'));
      expect(const ExperienceFingerprint('x'), isNot(const ExperienceFingerprint('y')));
    });
  });
}
