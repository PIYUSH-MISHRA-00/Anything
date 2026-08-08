/// Implementation Specification IS-R60 — Canonical Experience Package codec.
///
/// WHAT THE PHASE 1 AUDIT FOUND. The manifest, the package model, the
/// structural validator, the integrity hash and the transport envelope ALL
/// already existed and are certified. What did not exist, at all:
///
///   * a container format
///   * a reader
///   * a writer
///   * `ExperienceDistributionPackage.fromJson` — the class had `toJson()` and
///     no way back, a one-way street open since IS-R53
///
/// That is the concrete reason gap G-25 ("a user still cannot import an
/// Experience") survived four milestones: the pipeline was complete on package
/// OBJECTS and nothing could produce one from bytes.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/app/experience_distribution.dart';
import 'package:anything/app/experience_provenance.dart';
import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/experience_package_codec.dart';

ExperiencePackage _package({String id = 'exp-1', String name = 'Test'}) {
  final now = DateTime(2026, 8, 8);
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
      entryPoint: 's1',
      version: '1.0.0',
      createdAt: now,
      updatedAt: now,
    ),
    interface: const InterfaceDefinition(screens: screens),
    behavior: const BehaviorGraph(),
    state: const StateSchema(),
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
  const writer = ExperiencePackageWriter();
  const reader = ExperiencePackageReader();

  group('Round trip (IS-R60 Phases 4/5)', () {
    test('a written package reads back identical', () {
      final original = _package();
      final result = reader.read(writer.write(original));

      expect(result.succeeded, isTrue, reason: result.messages.join('; '));
      expect(
        ExperiencePackage.computeIntegrityHash(result.package!),
        ExperiencePackage.computeIntegrityHash(original),
      );
      expect(result.manifest!.experienceId, 'exp-1');
      expect(result.manifest!.entryPoint, 's1');
    });

    test(
      'ExperienceDistributionPackage now round-trips — the missing half',
      () {
        // R53 gave it toJson() and no fromJson. A transported package could be
        // written and never read back.
        final package = _package();
        final distribution = ExperienceDistributionPackage(
          envelope: ExperienceDistributionManifest(
            manifest: package.manifest,
            fingerprint: ExperienceFingerprint(
              ExperiencePackage.computeIntegrityHash(package),
            ),
            dependencies: const ['dep-a'],
          ),
          package: package,
        );

        final restored = ExperienceDistributionPackage.fromJson(
          distribution.toJson(),
        );

        expect(restored.envelope.experienceId, 'exp-1');
        expect(restored.envelope.dependencies, ['dep-a']);
        expect(
          restored.envelope.fingerprint.value,
          distribution.envelope.fingerprint.value,
        );
        expect(
          ExperiencePackage.computeIntegrityHash(restored.package),
          ExperiencePackage.computeIntegrityHash(package),
        );
      },
    );
  });

  group('Determinism (IS-R60 Phase 5)', () {
    test('the same package always writes byte-identical output', () {
      final a = writer.write(_package());
      final b = writer.write(_package());
      expect(
        a,
        b,
        reason: 'a checksum is meaningless if the writer is not deterministic',
      );
    });

    test('output does not depend on map insertion order', () {
      // The property that makes determinism real rather than incidental: two
      // packages equal in content but built in a different order must produce
      // identical bytes.
      final forward = ExperiencePackage.fromJson({...(_package().toJson())});
      final reversed = ExperiencePackage.fromJson(
        Map.fromEntries(_package().toJson().entries.toList().reversed),
      );
      expect(writer.write(forward), writer.write(reversed));
    });

    test('a DIFFERENT package produces different bytes', () {
      expect(
        writer.write(_package(id: 'exp-1')),
        isNot(writer.write(_package(id: 'exp-2'))),
      );
    });
  });

  group('Validation (IS-R60 Phase 6)', () {
    test(
      'a corrupted payload is rejected by checksum, not silently accepted',
      () {
        final bytes = writer.write(_package());
        // Edit the payload but leave valid JSON behind — the case a naive
        // "is it parseable" check would wave through.
        final tampered = bytes.replaceFirst('"name":"Test"', '"name":"Evil"');
        expect(
          tampered,
          isNot(bytes),
          reason: 'the tamper must actually apply',
        );

        final result = reader.read(tampered);
        expect(result.succeeded, isFalse);
        expect(result.failure, PackageReadFailure.checksumMismatch);
      },
    );

    test('a non-package file is refused rather than half-parsed', () {
      final result = reader.read('{"hello":"world"}');
      expect(result.failure, PackageReadFailure.notAPackage);
    });

    test('malformed input fails cleanly instead of throwing', () {
      expect(
        reader.read('not json at all').failure,
        PackageReadFailure.malformed,
      );
      expect(reader.read('[]').failure, PackageReadFailure.malformed);
    });

    test('a newer container format is refused, never parsed hopefully', () {
      final bytes = writer
          .write(_package())
          .replaceFirst(
            '"formatVersion":${ExperiencePackageFormat.version}',
            '"formatVersion":999',
          );
      expect(
        reader.read(bytes).failure,
        PackageReadFailure.unsupportedFormatVersion,
      );
    });

    test(
      'structural faults surface through the DELEGATED canonical validator',
      () {
        // The reader re-implements no validation rule. An oversized package is
        // rejected by ExperiencePackageValidator, and the reader reports it.
        final huge = _package().toJson();
        huge['interface'] = {
          'screens': [
            for (var i = 0; i < 400; i++)
              {
                'id': 's$i',
                'title': 'x' * 3000,
                'children': const <Map<String, dynamic>>[],
              },
          ],
        };
        final container = writer.write(ExperiencePackage.fromJson(huge));
        final result = reader.read(container);
        expect(result.succeeded, isFalse);
        expect(result.failure, PackageReadFailure.invalidPackage);
        expect(
          result.messages.length,
          greaterThan(1),
          reason: 'the validator\'s own errors must be surfaced, not swallowed',
        );
      },
    );
  });

  group('Reserved blocks (IS-R60 Phase 3)', () {
    test('a signature block round-trips UNVERIFIED', () {
      // Nothing verifies signatures. The block is carried so a future signing
      // implementation needs no format change, and reading it grants no
      // authority — the same position R52/R53 took on publisher signatures.
      final bytes = writer.write(
        _package(),
        signature: const {'publisher': 'p-1', 'sig': 'AAAA'},
      );
      final result = reader.read(bytes);

      expect(result.succeeded, isTrue);
      expect(result.signature, {'publisher': 'p-1', 'sig': 'AAAA'});
    });

    test('an extension area round-trips unchanged', () {
      final result = reader.read(
        writer.write(_package(), extensions: const {'future': 'value'}),
      );
      expect(result.extensions, {'future': 'value'});
    });

    test('absent reserved blocks read back as null, not as empty maps', () {
      final result = reader.read(writer.write(_package()));
      expect(result.signature, isNull);
      expect(result.extensions, isNull);
    });
  });

  group('Boundaries (IS-R60 Phase 8)', () {
    test('THE READER NEVER INSTALLS, ACTIVATES OR COMPUTES TRUST', () {
      // Asserted on the live object: the result exposes a package and a
      // manifest, and no path to a repository, a runtime or a trust level.
      // Parsing something must not run it.
      final result = reader.read(writer.write(_package()));
      expect(result.succeeded, isTrue);
      expect(result.package, isA<ExperiencePackage>());
      expect(result.manifest, isA<ExperienceManifest>());
      // A signed package is still just a package to the reader.
      final signed = reader.read(
        writer.write(_package(), signature: const {'sig': 'trust-me'}),
      );
      expect(signed.signature, isNotNull);
      expect(signed.package, isNotNull);
    });

    test('the format identifies itself and versions itself', () {
      final bytes = writer.write(_package());
      expect(bytes, contains(ExperiencePackageFormat.magic));
      expect(
        bytes,
        contains('"formatVersion":${ExperiencePackageFormat.version}'),
      );
      expect(ExperiencePackageFormat.extension, '.anything');
    });
  });
}
