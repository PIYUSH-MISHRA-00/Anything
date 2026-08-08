// ignore_for_file: avoid_print
// Examples print to stdout on purpose: their whole output IS the lesson.
// Scoped to this file so the repository-wide lint keeps protecting app code.

/// Declaring HOW an Experience runs — and why declaring is never granting.
///
///     dart run examples/execution_contract/main.dart
///
/// THE LOAD-BEARING IDEA. A contract travels INSIDE a package, and a package
/// is untrusted input. If a contract could decide its own eligibility, then
/// anyone able to write a manifest could reach a governance decision — the
/// authority would flow from the artefact instead of from the platform.
///
/// So a contract states what an Experience ASKS FOR. Governance still decides,
/// the capability platform still enforces, and the scheduler still schedules.
/// Certified by I-90.
library;

import 'package:anything/app/experience_execution_contract.dart';
import 'package:anything/creation/experience_package.dart';

ExperienceManifest manifest({
  String entryPoint = 'home',
  List<String> required = const [],
  List<String> optional = const [],
}) {
  final now = DateTime.utc(2026, 1, 1);
  return ExperienceManifest(
    experienceId: 'water-tracker',
    name: 'Water Tracker',
    description: 'Logs daily water intake',
    category: 'health',
    entryPoint: entryPoint,
    version: '1.0.0',
    requiredCapabilities: required,
    optionalCapabilities: optional,
    createdAt: now,
    updatedAt: now,
  );
}

void show(String label, ExecutionContractValidation v) {
  print('  $label');
  print('    valid : ${v.isValid}');
  for (final f in v.findings) {
    print('    fault : ${f.fault.name} — ${f.detail}');
  }
}

void main() {
  const validator = ExperienceExecutionValidator();

  // An Experience that declares nothing gets a TRUTHFUL default, not a
  // fabricated one. Every Experience in the repository today declares nothing.
  print('── The default is honest ──');
  final plain = ExperienceExecutionContract.defaultFor(manifest());
  print('  mode           : ${plain.mode.name}');
  print('  isolation      : ${plain.isolation.name}');
  print('  onInterruption : ${plain.onInterruption.name}');
  print(
    '  memoryBytes    : ${plain.requirements.memoryBytes}  '
    '← null means UNDECLARED, never "no limit"',
  );

  // The contract EMBEDS the canonical manifest and reads capabilities THROUGH
  // it. There is still exactly one manifest (I-60); nothing is copied.
  print('');
  print('── Capabilities are read through the manifest, never re-declared ──');
  final withCaps = ExperienceExecutionContract(
    manifest: manifest(required: const ['http'], optional: const ['clock']),
  );
  print('  required : ${withCaps.requiredCapabilities}');
  print('  optional : ${withCaps.optionalCapabilities}');
  print(
    '  same object as the manifest\'s : '
    '${identical(withCaps.requiredCapabilities, withCaps.manifest.requiredCapabilities)}',
  );

  print('');
  print('── What the validator refuses ──');

  show(
    'a capability declared BOTH required and optional',
    validator.validate(
      ExperienceExecutionContract(
        manifest: manifest(required: const ['http'], optional: const ['http']),
      ),
    ),
  );

  show(
    'an entryPoint that is empty — nothing to execute',
    validator.validate(
      ExperienceExecutionContract(manifest: manifest(entryPoint: '')),
    ),
  );

  show(
    'a RESERVED mode (headless) — refused, not silently accepted',
    validator.validate(
      ExperienceExecutionContract(
        manifest: manifest(),
        mode: ExecutionMode.headless,
      ),
    ),
  );

  show(
    'memoryBytes: 0 — omit the field instead',
    validator.validate(
      ExperienceExecutionContract(
        manifest: manifest(),
        requirements: const ExecutionRequirements(memoryBytes: 0),
      ),
    ),
  );

  // Declaring `background` is a REQUEST. It is a well-formed declaration, and
  // it grants nothing: BackgroundExecutionRule still refuses background work
  // below `local` trust.
  print('');
  print('── Declaring background does NOT grant background ──');
  final wantsBackground = ExperienceExecutionContract(
    manifest: manifest(),
    mode: ExecutionMode.background,
  );
  final decision = validator.validate(wantsBackground);
  print('  declaration well-formed : ${decision.isValid}');
  print('  mode requested          : ${wantsBackground.mode.name}');
  print(
    '  contract exposes "granted"? '
    '${wantsBackground.toJson().containsKey("granted")}   ← it cannot grant',
  );

  // A contract written by a newer build stays readable: an unknown mode
  // degrades to foreground rather than throwing.
  print('');
  print('── Forward compatibility ──');
  final json = plain.toJson()..['mode'] = 'teleport';
  print(
    '  unknown mode "teleport" reads back as : '
    '${ExperienceExecutionContract.fromJson(json).mode.name}',
  );

  print('');
  print(
    'See also: docs/EXPERIENCE_GUIDE.md, '
    'docs/architecture/EXPERIENCE_ORCHESTRATION.md',
  );
}
