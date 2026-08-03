/// Generation Pipeline — Implementation Milestone R10. The real, small
/// orchestrator: `CanonicalImplementationModel` -> selected [Generator]
/// -> [GenerationResult]. Deliberately thin — it does not itself know
/// anything about any target; it only assembles a real [GeneratorContext]
/// and delegates. This is NOT a second Kernel/Planner: it has no
/// reasoning, no AI call, no multi-stage decision-making of its own —
/// one real, deterministic dispatch, mirroring how
/// `EvolutionDiffPlanBuilder` (R4)/`BackendEngineeringPlanner` (R8)/
/// `CanonicalImplementationPlanner` (R9) are each a single, real, focused
/// assembly step, never a rival orchestrator to `AnythingKernel`.
library;

import '../implementation_model/canonical_implementation_model.dart';
import 'generation_result.dart';
import 'generator.dart';

class GenerationPipeline {
  const GenerationPipeline();

  /// Runs [generator] against [model] for [target]. Real and
  /// deterministic: the same (`model`, `generator`, `target`, `options`)
  /// always produces the same [GenerationResult], since this method adds
  /// no randomness/timestamps/IO of its own — verified directly by this
  /// milestone's determinism test, not merely assumed.
  GenerationResult run({
    required CanonicalImplementationModel model,
    required Generator generator,
    required GeneratorTarget target,
    GeneratorOptions options = GeneratorOptions.empty,
  }) {
    final context = GeneratorContext(model: model, target: target, options: options);
    return generator.generate(context);
  }
}
