/// Generation Pipeline — Implementation Milestone R10, updated R11.
/// The real, small orchestrator: `CanonicalImplementationModel` ->
/// (Implementation Milestone R11) `UniversalBuildGraph` -> selected
/// [Generator] -> [GenerationResult]. Deliberately thin — it does not
/// itself know anything about any target; it only assembles a real
/// [GeneratorContext] and delegates. This is NOT a second Kernel/Planner:
/// it has no reasoning, no AI call, no multi-stage decision-making of its
/// own — one real, deterministic dispatch, mirroring how
/// `EvolutionDiffPlanBuilder` (R4)/`BackendEngineeringPlanner` (R8)/
/// `CanonicalImplementationPlanner` (R9)/`BuildGraphBuilder` (R11) are
/// each a single, real, focused assembly step, never a rival orchestrator
/// to `AnythingKernel`.
library;

import '../build_graph/universal_build_graph.dart';
import 'generation_result.dart';
import 'generator.dart';

class GenerationPipeline {
  const GenerationPipeline();

  /// Runs [generator] against [buildGraph] for [target]. Real and
  /// deterministic: the same (`buildGraph`, `generator`, `target`,
  /// `options`) always produces the same [GenerationResult], since this
  /// method adds no randomness/timestamps/IO of its own — verified
  /// directly by this milestone's determinism test, not merely assumed.
  GenerationResult run({
    required UniversalBuildGraph buildGraph,
    required Generator generator,
    required GeneratorTarget target,
    GeneratorOptions options = GeneratorOptions.empty,
  }) {
    final context = GeneratorContext(
      buildGraph: buildGraph,
      target: target,
      options: options,
    );
    return generator.generate(context);
  }
}
