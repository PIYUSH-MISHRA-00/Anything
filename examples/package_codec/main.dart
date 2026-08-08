// ignore_for_file: avoid_print
// Examples print to stdout on purpose: their whole output IS the lesson.
// Scoped to this file so the repository-wide lint keeps protecting app code.

/// Writing and reading a `.anything` package — determinism and tamper
/// detection.
///
///     flutter test examples/package_codec/main.dart
///
/// NOT `dart run`: this example reaches `ExperiencePackageValidator`, whose
/// import chain touches `package:flutter/material.dart`. Under the plain Dart
/// VM that trips the FFI transformer on this project's plugin set. `flutter
/// test` executes a bare `main()` happily and prints "No tests ran" at the
/// end — that line is expected and is not a failure.
///
/// THIS MACHINERY IS NOT YET REACHABLE FROM THE APP'S UI. The format, writer,
/// reader, validator and installer are all built and certified; nothing calls
/// them. Wiring them to an Import/Export action is the next milestone. This
/// example is the clearest way to see what already works.
library;

import 'package:anything/creation/experience_package.dart';
import 'package:anything/creation/experience_package_codec.dart';

ExperiencePackage build({String name = 'Water Tracker'}) {
  final now = DateTime.utc(2026, 1, 1);
  return ExperiencePackage(
    manifest: ExperienceManifest(
      experienceId: 'water-tracker',
      name: name,
      description: 'Logs daily water intake',
      category: 'health',
      entryPoint: 'home',
      version: '1.0.0',
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
  const writer = ExperiencePackageWriter();
  const reader = ExperiencePackageReader();

  print('── The container identifies and versions itself ──');
  print('  magic         : ${ExperiencePackageFormat.magic}');
  print('  formatVersion : ${ExperiencePackageFormat.version}');
  print('  extension     : ${ExperiencePackageFormat.extension}');

  final bytes = writer.write(build());
  print('  written       : ${bytes.length} bytes');

  print('');
  print('── Round trip ──');
  final result = reader.read(bytes);
  print('  succeeded : ${result.succeeded}');
  print('  id        : ${result.manifest?.experienceId}');

  // Determinism is what makes a checksum — and later a signature — mean
  // anything. Every map is emitted with sorted keys, so output does not depend
  // on insertion order. Lists keep their order, because element order is data.
  print('');
  print('── Deterministic by construction ──');
  print(
    '  same package, written twice → identical bytes : '
    '${writer.write(build()) == writer.write(build())}',
  );
  print(
    '  a DIFFERENT package → different bytes         : '
    '${writer.write(build(name: "Hydration")) != writer.write(build())}',
  );

  // The checksum is verified against the REBUILT package, not the raw text.
  // That catches an edit made in transit even when it leaves valid JSON.
  print('');
  print('── Tampering is caught, even when it stays valid JSON ──');
  final tampered = bytes.replaceFirst(
    '"name":"Water Tracker"',
    '"name":"Evil"',
  );
  print('  tamper applied : ${tampered != bytes}');
  final tamperedResult = reader.read(tampered);
  print('  succeeded      : ${tamperedResult.succeeded}');
  print('  failure        : ${tamperedResult.failure?.name}');

  print('');
  print('── Every other way a read can fail ──');
  for (final entry in {
    'not JSON at all': 'not json',
    'JSON, but not a package': '{"hello":"world"}',
    'a newer container format': bytes.replaceFirst(
      '"formatVersion":${ExperiencePackageFormat.version}',
      '"formatVersion":999',
    ),
  }.entries) {
    print(
      '  ${entry.key.padRight(24)} → '
      '${reader.read(entry.value).failure?.name}',
    );
  }

  // A signature block round-trips UNVERIFIED. Nothing checks it, and reading
  // one grants no authority — a well-formed package must not be able to argue
  // itself into trust by being well-formed.
  print('');
  print('── Reserved signature block: carried, never verified ──');
  final signed = reader.read(
    writer.write(build(), signature: const {'publisher': 'p-1'}),
  );
  print('  signature read back : ${signed.signature}');
  print('  package still just a package : ${signed.package != null}');

  print('');
  print('("No tests ran" below is expected — this is an example, not a test.)');
}
