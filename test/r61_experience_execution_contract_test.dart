/// Implementation Specification IS-R61 — Canonical Experience Execution
/// Contract.
///
/// WHAT THE PHASE 1 AUDIT FOUND. Almost everything Phase 2 lists already
/// existed and was owned elsewhere: capabilities by the canonical manifest,
/// compatibility by `ExperienceCompatibilityEvaluator` (R54), suspend/resume/
/// terminate by `RuntimePolicyAction` + `WorkspaceLifecyclePolicyEngine` (R39),
/// background ELIGIBILITY by `BackgroundExecutionRule` (R51 governance), and
/// enforcement by `CapabilityPlatform`.
///
/// Only ONE thing was missing anywhere in `lib/`: an execution MODE.
///
/// So the contract DERIVES rather than duplicates, and these tests exist mostly
/// to prove it cannot decide anything.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/app/experience_execution_contract.dart';
import 'package:anything/creation/experience_package.dart';

ExperienceManifest _manifest({
  String id = 'exp-1',
  String entryPoint = 's1',
  List<String> required = const [],
  List<String> optional = const [],
}) {
  final now = DateTime(2026, 8, 8);
  return ExperienceManifest(
    experienceId: id,
    name: 'Test',
    description: 'd',
    category: 'general',
    entryPoint: entryPoint,
    version: '1.0.0',
    requiredCapabilities: required,
    optionalCapabilities: optional,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const validator = ExperienceExecutionValidator();

  group('Derivation, not duplication (IS-R61 Phase 2)', () {
    test(
      'the contract EMBEDS the canonical manifest rather than copying it',
      () {
        final manifest = _manifest();
        final contract = ExperienceExecutionContract(manifest: manifest);

        expect(
          contract.manifest,
          same(manifest),
          reason: 'the canonical manifest is carried, not re-declared',
        );
        expect(contract.experienceId, 'exp-1');
      },
    );

    test('capabilities are READ THROUGH the manifest, never re-declared', () {
      final contract = ExperienceExecutionContract(
        manifest: _manifest(required: ['http'], optional: ['notifications']),
      );

      expect(contract.requiredCapabilities, ['http']);
      expect(contract.optionalCapabilities, ['notifications']);

      // Changing the manifest changes the contract, because there is only one
      // declaration. A copied list would have drifted here.
      final other = ExperienceExecutionContract(
        manifest: _manifest(required: ['clock']),
      );
      expect(other.requiredCapabilities, ['clock']);
    });

    test('an Experience that declares nothing gets a truthful default', () {
      // Every Experience in this repository today declares no execution
      // preferences. The default must be honest rather than fabricated.
      final contract = ExperienceExecutionContract.defaultFor(_manifest());

      expect(contract.mode, ExecutionMode.foreground);
      expect(contract.isolation, IsolationPolicy.standard);
      expect(contract.onInterruption, InterruptionPolicy.unspecified);
      expect(contract.recoverable, isFalse);
      expect(
        contract.requirements.memoryBytes,
        isNull,
        reason: 'undeclared must mean UNDECLARED, never a fabricated ceiling',
      );
    });

    test('round-trips through JSON with every field intact', () {
      final original = ExperienceExecutionContract(
        manifest: _manifest(required: ['http']),
        mode: ExecutionMode.background,
        requirements: const ExecutionRequirements(
          memoryBytes: 1024,
          storageBytes: 2048,
          requiredExperiences: ['dep-a'],
          requiresProtection: true,
        ),
        onInterruption: InterruptionPolicy.suspend,
        isolation: IsolationPolicy.strict,
        recoverable: true,
        extensions: const {'future': 'value'},
      );

      final restored = ExperienceExecutionContract.fromJson(original.toJson());

      expect(restored.mode, ExecutionMode.background);
      expect(restored.requirements.memoryBytes, 1024);
      expect(restored.requirements.requiredExperiences, ['dep-a']);
      expect(restored.requirements.requiresProtection, isTrue);
      expect(restored.onInterruption, InterruptionPolicy.suspend);
      expect(restored.isolation, IsolationPolicy.strict);
      expect(restored.recoverable, isTrue);
      expect(restored.extensions, {'future': 'value'});
      expect(restored.requiredCapabilities, ['http']);
    });

    test('an unknown mode degrades to foreground rather than throwing', () {
      final json = ExperienceExecutionContract.defaultFor(_manifest()).toJson();
      json['mode'] = 'teleport';
      expect(
        ExperienceExecutionContract.fromJson(json).mode,
        ExecutionMode.foreground,
        reason: 'a contract from an unknown future build must degrade safely',
      );
    });
  });

  group('Validation (IS-R61 Phase 4)', () {
    test('a default contract is valid', () {
      expect(
        validator
            .validate(ExperienceExecutionContract.defaultFor(_manifest()))
            .isValid,
        isTrue,
      );
    });

    test(
      'a capability declared BOTH required and optional is contradictory',
      () {
        // The Experience has not decided whether it can run without it, and the
        // two answers lead to different enforcement outcomes.
        final result = validator.validate(
          ExperienceExecutionContract(
            manifest: _manifest(required: ['http'], optional: ['http']),
          ),
        );
        expect(result.isValid, isFalse);
        expect(
          result.findings.single.fault,
          ExecutionContractFault.contradictoryCapabilities,
        );
      },
    );

    test('a missing entryPoint is caught — there is nothing to execute', () {
      final result = validator.validate(
        ExperienceExecutionContract(manifest: _manifest(entryPoint: '')),
      );
      expect(
        result.findings.single.fault,
        ExecutionContractFault.manifestIncomplete,
      );
    });

    test('RESERVED modes are REFUSED, not silently accepted', () {
      // Accepting one would promise execution semantics no runtime implements.
      for (final mode in [ExecutionMode.headless, ExecutionMode.autonomous]) {
        final result = validator.validate(
          ExperienceExecutionContract(manifest: _manifest(), mode: mode),
        );
        expect(result.isValid, isFalse, reason: '$mode must be refused');
        expect(
          result.findings.single.fault,
          ExecutionContractFault.reservedModeNotImplemented,
        );
      }
    });

    test('implemented modes are accepted', () {
      for (final mode in [
        ExecutionMode.foreground,
        ExecutionMode.background,
        ExecutionMode.scheduled,
        ExecutionMode.transient,
        ExecutionMode.persistent,
      ]) {
        expect(
          validator
              .validate(
                ExperienceExecutionContract(manifest: _manifest(), mode: mode),
              )
              .isValid,
          isTrue,
          reason: '$mode is declarable',
        );
      }
    });

    test('a self-requirement is circular and refused', () {
      final result = validator.validate(
        ExperienceExecutionContract(
          manifest: _manifest(id: 'exp-1'),
          requirements: const ExecutionRequirements(
            requiredExperiences: ['exp-1'],
          ),
        ),
      );
      expect(
        result.findings.single.fault,
        ExecutionContractFault.circularRequirement,
      );
    });

    test('a declared requirement must be a sane value', () {
      final result = validator.validate(
        ExperienceExecutionContract(
          manifest: _manifest(),
          requirements: const ExecutionRequirements(
            memoryBytes: 0,
            storageBytes: -1,
          ),
        ),
      );
      expect(result.findings.length, 2);
      expect(
        result.findings.every(
          (f) => f.fault == ExecutionContractFault.invalidRequirement,
        ),
        isTrue,
      );
    });

    test(
      'a newer contract version is refused rather than parsed hopefully',
      () {
        final result = validator.validate(
          ExperienceExecutionContract(
            manifest: _manifest(),
            contractVersion: 99,
          ),
        );
        expect(
          result.findings.single.fault,
          ExecutionContractFault.unsupportedContractVersion,
        );
      },
    );
  });

  group('The contract DECIDES nothing (IS-R61 Phase 8)', () {
    test(
      'declaring background does NOT grant background — governance does',
      () {
        // BackgroundExecutionRule (R51) refuses background work below `local`
        // trust. A contract asking for it is a request, not a grant.
        final contract = ExperienceExecutionContract(
          manifest: _manifest(),
          mode: ExecutionMode.background,
        );
        final result = validator.validate(contract);

        expect(
          result.isValid,
          isTrue,
          reason: 'the DECLARATION is well formed...',
        );
        // ...and the contract exposes no decision, no outcome and no grant.
        expect(contract.mode, ExecutionMode.background);
        expect(contract.toJson().containsKey('allowed'), isFalse);
        expect(contract.toJson().containsKey('granted'), isFalse);
      },
    );

    test(
      'declaring a capability does NOT grant it — the platform enforces',
      () {
        final contract = ExperienceExecutionContract(
          manifest: _manifest(required: ['ai', 'http', 'file']),
        );
        // Validation passes on a contract asking for everything: the contract
        // layer is not where that is refused.
        expect(validator.validate(contract).isValid, isTrue);
        expect(contract.requiredCapabilities, ['ai', 'http', 'file']);
      },
    );

    test('requiresProtection is a REQUEST — nothing here can protect', () {
      final contract = ExperienceExecutionContract(
        manifest: _manifest(),
        requirements: const ExecutionRequirements(requiresProtection: true),
      );
      expect(validator.validate(contract).isValid, isTrue);
      expect(contract.requirements.requiresProtection, isTrue);
      // ExperienceProtectionService remains the sole owner; the contract
      // exposes no way to change protection state.
      expect(contract.toJson()['requirements']['requiresProtection'], isTrue);
    });

    test('THE VALIDATOR IS PURE — it holds nothing it could execute with', () {
      // Asserted on the live object: it is const-constructible with no
      // dependencies at all, so it cannot schedule, execute or persist.
      const a = ExperienceExecutionValidator();
      const b = ExperienceExecutionValidator();
      expect(
        identical(a, b),
        isTrue,
        reason: 'a const validator has no state to carry a runtime in',
      );
    });
  });
}
