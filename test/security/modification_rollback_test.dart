/// M2 — Modification engine rollback/data-preservation adversarial tests.
///
/// ModificationEngine.modify() is purely functional: every stage (manifest,
/// interface, behavior, state, data) builds a brand-new object from the
/// existing package's fields, and the existing package instance itself is
/// never mutated. This proves "old package remains active on failure" by
/// construction rather than by an explicit rollback step — this test
/// certifies that property holds even when a candidate is malicious enough
/// to fail ExperiencePackageValidator, matching the real coordinator's
/// validate-before-persist ordering (see
/// lib/app/experience_modification_coordinator.dart: validate() runs before
/// any _repository.savePackage() call; on failure, savePackage is never
/// invoked and the old row is untouched).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/creation/modification/experience_modification_spec.dart';
import 'package:anything/creation/modification/modification_engine.dart';
import 'package:anything/creation/package_validator.dart';
import 'package:anything/runtime/golden_paths/calculator_package.dart';
import 'package:anything/security/runtime_security_limits.dart';

void main() {
  group(
    'Modification produces an invalid candidate without touching the original',
    () {
      test('a modification spec that would blow the behavior-node budget is '
          'rejected by the validator, and the pre-existing package instance is '
          'byte-for-byte unchanged', () async {
        final original = createCalculatorPackage();
        final originalJsonBefore = original.toJson().toString();

        final maliciousOps = List.generate(
          RuntimeSecurityLimits.maxBehaviorNodesPerPackage + 10,
          (i) => const ModificationOperation(
            type: ModificationType.addBehavior,
            params: {'nodeType': 'stateWrite', 'config': {}},
          ),
        );

        final spec = ExperienceModificationSpec(
          targetExperienceId: original.manifest.experienceId,
          basePackageVersion: original.manifest.version,
          objective: 'Malicious bulk behavior injection',
          operations: maliciousOps,
        );

        final engine = ModificationEngine();
        final result = await engine.modify(original, spec);

        // The engine itself is permissive (it just applies operations) —
        // the trust boundary is the validator, run before persistence.
        expect(result, isA<ModificationReady>());
        final candidate = (result as ModificationReady).updatedPackage;

        final validation = ExperiencePackageValidator.validate(candidate);
        expect(validation.isValid, isFalse);
        expect(
          validation.errors.any(
            (e) => e.contains('behavior_node_count_exceeded'),
          ),
          isTrue,
        );

        // The original package object was never mutated by modify().
        expect(original.toJson().toString(), originalJsonBefore);
        expect(
          original.behavior.nodes.length,
          lessThan(candidate.behavior.nodes.length),
        );
      });

      test(
        'experience ID is preserved across a successful modification',
        () async {
          final original = createCalculatorPackage();
          final spec = ExperienceModificationSpec(
            targetExperienceId: original.manifest.experienceId,
            basePackageVersion: original.manifest.version,
            objective: 'Add a button',
            operations: const [
              ModificationOperation(
                type: ModificationType.addUiNode,
                params: {
                  'screenId': 'calculator',
                  'nodeType': 'button',
                  'label': '%',
                },
              ),
            ],
          );

          final result = await ModificationEngine().modify(original, spec);
          expect(result, isA<ModificationReady>());
          final candidate = (result as ModificationReady).updatedPackage;

          expect(
            candidate.manifest.experienceId,
            original.manifest.experienceId,
          );
          expect(candidate.manifest.version, isNot(original.manifest.version));
        },
      );
    },
  );
}
