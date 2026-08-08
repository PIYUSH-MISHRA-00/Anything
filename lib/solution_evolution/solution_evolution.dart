/// SolutionEvolutionEngine — Implementation Specification IS-R29. A pure
/// DECISION layer over already-real, already-tested machinery — never a
/// new diff algorithm, never a new executor, never a second Compiler.
///
/// REALITY this milestone builds on: `RequirementGraphDiffer` (R3),
/// `ArchitectureDiffer` (R4), `AffectedEntityAnalyzer` (R24),
/// `IncrementalCompilerSynthesizer` (R24), `SolutionExecutionOrchestrator`
/// (R25-R27), and `ArtifactIntelligenceEngine` (R28) each already do real
/// work, but nothing combines them into one "what should happen next"
/// decision. This engine is that missing composition — it NEVER calls
/// `SolutionExecutionOrchestrator.execute()`, `IncrementalCompilerSynthesizer
/// .synthesize()`, `runCompilerPipeline`/`runGeneratorPipeline`, or any
/// generator directly. It returns a real, typed, inspectable plan a caller
/// acts on separately — the exact "decide, never invoke" precedent
/// `SolutionExecutionPlanner` (R18) already established for target
/// selection, applied here one layer up, to REGENERATION selection.
///
/// The one real, structural asymmetry (verified by reading
/// `lib/engineering_intelligence/incremental_compiler_synthesis.dart` and
/// `lib/compiler_integration/compiler_pipeline_runner.dart`):
/// `IncrementalCompilerSynthesizer` only ever scopes and re-runs
/// `runCompilerPipeline`, which is STILL hardcoded to
/// `RuntimeExperienceGenerator` (R19, unchanged through R26/R27's own
/// generalization of the sibling `runGeneratorPipeline`). There is no
/// incremental path anywhere for Backend Service or REST API — any real
/// change reaching either of those targets can only ever be resolved by a
/// FULL `SolutionExecutionOrchestrator.execute()` re-run. This engine
/// reports that asymmetry honestly via [CompilationMode]: incremental is
/// only ever offered when Runtime Experience is the sole regeneration
/// target; anything touching Backend Service/REST API forces full.
///
/// Target applicability is read from the caller-supplied, ALREADY-REAL
/// `ExecutionStrategy` for the "after" state (`SolutionExecutionPlanner`,
/// R18) rather than re-derived per affected entity: `CanonicalImplementationPlanner`
/// (R9) builds `repositories`/`controllers` from `BackendEngineeringPlan
/// .database`/`.api` UNCONDITIONALLY (independent of whether the solution
/// actually needs a backend — confirmed by reading `_planRepositories`/
/// `_planControllers`), so "does this affected entity have a repository"
/// is NOT a reliable per-entity signal for "does Backend Service need to
/// regenerate." `requiresBackend`/`hasApi` are real, whole-SOLUTION-level
/// decisions `SolutionExecutionPlanner` already makes correctly — reusing
/// its output is the honest design; re-deriving a finer-grained per-entity
/// version would fabricate precision the underlying data doesn't have.
library;

import '../artifact_intelligence/artifact_intelligence.dart';
import '../engineering_intelligence/affected_entities.dart';
import '../execution_planning/execution_strategy.dart';
import '../software_architect/architecture_candidate.dart';
import '../software_architect/architecture_candidate_diff.dart';
import '../software_architect/requirement_graph.dart';
import '../software_architect/requirement_graph_diff.dart';

/// One real action this engine recommends — never an instruction to
/// execute anything itself.
enum EvolutionAction {
  noAction,
  validate,
  regenerateRuntime,
  regenerateBackend,
  regenerateRestApi,
}

/// Whether a caller should use `IncrementalCompilerSynthesizer` (R24) or
/// a full `SolutionExecutionOrchestrator.execute()` (R25-R27) run —
/// `none` when there is nothing to regenerate at all.
enum CompilationMode { none, incremental, full }

enum DeploymentDecision { allowed, blocked }

/// Real, typed, inspectable output — every field traceable to the real
/// diff/analysis that produced it, never a fabricated summary.
class RegenerationPlan {
  final Set<EvolutionAction> actions;
  final CompilationMode compilationMode;
  final AffectedEntities affectedEntities;
  final RequirementGraphDiff requirementDiff;
  final ArchitectureDiff architectureDiff;

  const RegenerationPlan({
    required this.actions,
    required this.compilationMode,
    required this.affectedEntities,
    required this.requirementDiff,
    required this.architectureDiff,
  });

  bool get isNoOp => actions.contains(EvolutionAction.noAction);
}

class SolutionEvolutionEngine {
  const SolutionEvolutionEngine();

  static const _analyzer = AffectedEntityAnalyzer();
  static const _requirementDiffer = RequirementGraphDiffer();
  static const _architectureDiffer = ArchitectureDiffer();

  /// Pure: computes real diffs (R3/R4), translates to real `AffectedEntities`
  /// (R24), and recommends real actions from the caller-supplied,
  /// already-real `afterExecutionStrategy` (R18) — never executes, never
  /// re-plans that strategy itself.
  RegenerationPlan planRegeneration({
    required RequirementGraph beforeRequirements,
    required RequirementGraph afterRequirements,
    required ArchitectureCandidate beforeArchitecture,
    required ArchitectureCandidate afterArchitecture,
    required ExecutionStrategy afterExecutionStrategy,
  }) {
    final requirementDiff = _requirementDiffer.diff(
      beforeRequirements,
      afterRequirements,
    );
    final architectureDiff = _architectureDiffer.diff(
      beforeArchitecture,
      afterArchitecture,
    );
    final affected = _analyzer
        .fromRequirementDiff(requirementDiff)
        .merge(_analyzer.fromArchitectureDiff(architectureDiff));

    if (affected.isEmpty) {
      return RegenerationPlan(
        actions: const {EvolutionAction.noAction},
        compilationMode: CompilationMode.none,
        affectedEntities: affected,
        requirementDiff: requirementDiff,
        architectureDiff: architectureDiff,
      );
    }

    final actions = <EvolutionAction>{};
    if (_applicable(
      afterExecutionStrategy,
      ExecutionTargetKind.runtimeExperience,
    )) {
      actions.add(EvolutionAction.regenerateRuntime);
    }
    if (_applicable(
      afterExecutionStrategy,
      ExecutionTargetKind.backendService,
    )) {
      actions.add(EvolutionAction.regenerateBackend);
    }
    if (_applicable(afterExecutionStrategy, ExecutionTargetKind.restApi)) {
      actions.add(EvolutionAction.regenerateRestApi);
    }

    if (actions.isEmpty) {
      // Real entities changed, but nothing in this solution is
      // actionable (no target applies with a real generator) — honest:
      // there is nothing to regenerate, so no compilation mode either.
      // `validate` still names the real, distinct fact that something
      // structurally changed and is worth a look, even with nothing to
      // regenerate.
      return RegenerationPlan(
        actions: const {EvolutionAction.validate},
        compilationMode: CompilationMode.none,
        affectedEntities: affected,
        requirementDiff: requirementDiff,
        architectureDiff: architectureDiff,
      );
    }

    // `validate` — real, distinct meaning: a caller should re-run
    // validation (`ExperiencePackageValidator`/`ArtifactIntelligenceEngine`)
    // after ANY regeneration, so it is always paired with a real
    // regenerate* action, never a substitute for one and never present
    // without one.
    actions.add(EvolutionAction.validate);

    // The real asymmetry: Backend Service/REST API have no incremental
    // path (see this file's own top-level doc comment) — their presence
    // forces a full compilation; Runtime-Experience-only changes may use
    // the real incremental path.
    final needsFull =
        actions.contains(EvolutionAction.regenerateBackend) ||
        actions.contains(EvolutionAction.regenerateRestApi);
    final mode = needsFull ? CompilationMode.full : CompilationMode.incremental;

    return RegenerationPlan(
      actions: actions,
      compilationMode: mode,
      affectedEntities: affected,
      requirementDiff: requirementDiff,
      architectureDiff: architectureDiff,
    );
  }

  bool _applicable(ExecutionStrategy strategy, ExecutionTargetKind target) {
    final plan = strategy.targets.where((t) => t.target == target).firstOrNull;
    return plan?.classification ==
        ExecutionTargetClassification.applicableWithGenerator;
  }

  /// Pure, honest restatement of `ArtifactIntelligenceReport.deploymentReady`
  /// (R28) as one of this engine's own named action types — never new
  /// readiness logic; `ArtifactIntelligenceEngine` already computes the
  /// real, richer readiness signal (including the real dependency-fulfilment
  /// check `OrchestrationReport.succeeded` alone does not make).
  DeploymentDecision decideDeployment(ArtifactIntelligenceReport report) =>
      report.deploymentReady
      ? DeploymentDecision.allowed
      : DeploymentDecision.blocked;
}
