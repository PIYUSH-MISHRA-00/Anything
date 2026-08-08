// ignore_for_file: avoid_print
// Examples print to stdout on purpose: their whole output IS the lesson.
// Scoped to this file so the repository-wide lint keeps protecting app code.

/// The smallest valid Experience, and what makes it identifiable.
///
///     dart run examples/minimal_experience/main.dart
///
/// An Experience is DATA, not code. That is the whole design: it can be
/// inspected, hashed, serialised and refused before anything runs it.
library;

import 'package:anything/creation/experience_package.dart';

ExperiencePackage buildMinimal({
  String entryPoint = 'home',
  String name = 'Water Tracker',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: 'water-tracker',
      name: name,
      description: 'Logs daily water intake',
      category: 'health',
      entryPoint: entryPoint,
      version: '1.0.0',
      requiredCapabilities: const ['clock'],
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
      creationEngineVersion: 'example',
      specVersion: 1,
      planVersion: 1,
    ),
    integrity: PackageIntegrity(contentHash: 'example', computedAt: now),
  );
}

void main() {
  final package = buildMinimal();

  print('── A minimal Experience ──');
  print('  id                   : ${package.manifest.experienceId}');
  print('  entryPoint           : ${package.manifest.entryPoint}');
  print('  screens              : ${package.interface.screens.length}');
  print('  requiredCapabilities : ${package.manifest.requiredCapabilities}');

  // `entryPoint` must name a real screen. Nothing enforces that here — the
  // canonical validator does, and every layer that needs structural validation
  // delegates to it rather than re-implementing the rule (certified I-59).
  final entryExists = package.interface.screens.any(
    (s) => s.id == package.manifest.entryPoint,
  );
  print('  entryPoint resolves  : $entryExists');

  // Identity is STRUCTURAL. Two packages with the same content hash to the
  // same value regardless of how they were built.
  print('');
  print('── Identity is structural, not incidental ──');
  final again = buildMinimal();
  print(
    '  hash(package)  : ${ExperiencePackage.computeIntegrityHash(package)}',
  );
  print('  hash(rebuilt)  : ${ExperiencePackage.computeIntegrityHash(again)}');
  print(
    '  identical      : '
    '${ExperiencePackage.computeIntegrityHash(package) == ExperiencePackage.computeIntegrityHash(again)}',
  );

  final renamed = buildMinimal(name: 'Hydration');
  print(
    '  hash(renamed)  : ${ExperiencePackage.computeIntegrityHash(renamed)}',
  );
  print(
    '  changed        : '
    '${ExperiencePackage.computeIntegrityHash(renamed) != ExperiencePackage.computeIntegrityHash(package)}',
  );

  // The package round-trips through JSON with full fidelity. This is what
  // makes it transportable, and what the .anything container is built on.
  print('');
  print('── Round-trips with full fidelity ──');
  final restored = ExperiencePackage.fromJson(package.toJson());
  print('  restored id    : ${restored.manifest.experienceId}');
  print(
    '  hash preserved : '
    '${ExperiencePackage.computeIntegrityHash(restored) == ExperiencePackage.computeIntegrityHash(package)}',
  );

  print('');
  print('Next: examples/execution_contract');
}
