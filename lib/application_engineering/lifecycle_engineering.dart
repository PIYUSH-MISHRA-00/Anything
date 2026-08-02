/// Lifecycle Engineering — maps the real, M1-certified Experience
/// lifecycle (create -> persist -> trusted open -> runtime -> close ->
/// reopen) into typed hooks. Documents what already exists and is
/// exercised end-to-end by
/// test/stage11/stage11_final_production_certification_test.dart; does
/// not invent new lifecycle behavior.
library;

import '../software_architect/confidence.dart';
import 'engineering_types.dart';

enum LifecycleHookKind { onCreate, onPersist, onOpen, onClose, onReopen }

class LifecycleHook {
  final LifecycleHookKind kind;
  final String realizedBy;
  final EngineeringDecision decision;

  const LifecycleHook({required this.kind, required this.realizedBy, required this.decision});
}

class LifecycleEngineeringResult {
  final List<LifecycleHook> hooks;
  const LifecycleEngineeringResult({this.hooks = const []});
}

class LifecycleEngineering {
  const LifecycleEngineering();

  static const Map<LifecycleHookKind, String> _realizedBy = {
    LifecycleHookKind.onCreate: 'CreationEngine.create()',
    LifecycleHookKind.onPersist: 'SqliteExperienceRepository.savePackage()',
    LifecycleHookKind.onOpen: 'ExperienceOpeningCoordinator (trusted opening)',
    LifecycleHookKind.onClose: 'AnythingRuntime + ExperienceDatabase.close()',
    LifecycleHookKind.onReopen: 'Fresh ExperienceOpeningCoordinator + fresh ExperienceDatabase at the same path',
  };

  LifecycleEngineeringResult plan() {
    final hooks = _realizedBy.entries.map((entry) {
      return LifecycleHook(
        kind: entry.key,
        realizedBy: entry.value,
        decision: EngineeringDecision(
          id: 'lifecycle:${entry.key.name}',
          category: EngineeringDecisionCategory.lifecycle,
          subjectId: entry.key.name,
          decision: '${entry.key.name} is realized by ${entry.value}',
          rationale:
              'Exercised end-to-end for a real, novel domain by '
              'test/stage11/stage11_final_production_certification_test.dart '
              '(M1) — this hook already exists and is certified, not newly '
              'introduced by this milestone.',
          confidence: Confidence.full,
        ),
      );
    }).toList();
    return LifecycleEngineeringResult(hooks: hooks);
  }
}
