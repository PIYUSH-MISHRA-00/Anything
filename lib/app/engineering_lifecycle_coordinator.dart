/// EngineeringLifecycleCoordinator — Implementation Specification IS-R30.
/// The first real production caller of `SolutionEvolutionEngine` (R29) —
/// confirmed by grep before writing this file: `SolutionEvolutionEngine(`
/// appeared only in its own defining file and in `test/r29_solution_evolution_test.dart`.
/// `IncrementalCompilerSynthesizer.buildEvolutionPlan()` (R24) was ALSO
/// zero-production-caller until now — confirmed the same way.
///
/// This coordinator is a pure COMPOSITION over already-real, already-tested
/// subsystems — it never re-implements diffing, execution, artifact
/// analysis, or persistence/rollback logic:
///
///   AnythingKernel.processIntent() (unchanged, the ONE reasoning call)
///     -> SolutionEvolutionEngine.planRegeneration() (R29, unchanged)
///     -> IncrementalCompilerSynthesizer.synthesize() (R24, unchanged)
///        OR SolutionExecutionOrchestrator.execute() (R25-R27, unchanged)
///     -> ArtifactIntelligenceEngine.analyze() (R28, unchanged; FULL path only,
///        see "Deployment Flow" below for why)
///     -> SolutionEvolutionEngine.decideDeployment() (R29, unchanged; FULL path)
///     -> ExperienceModificationCoordinator.applyEvolutionPlan() (R6, unchanged)
///        on `allowed`, never called on `blocked`.
///
/// COMMIT MECHANISM: `IncrementalCompilerSynthesizer.buildEvolutionPlan()`
/// (R24) already builds a real `EvolutionDiffPlan` from an
/// `IncrementalSynthesisResult` via the existing `ExperienceDiffer`/
/// `EvolutionDiffPlanBuilder` (R4) — reused unmodified for the incremental
/// path. No analogous helper existed for the FULL path (an
/// `OrchestrationReport`'s Runtime Experience package), so this file adds
/// one small, coordinator-local method (`_buildEvolutionPlanFromReport`)
/// that mirrors `buildEvolutionPlan()`'s exact body, sourcing the candidate
/// package from `OrchestrationReport.outcomeFor(runtimeExperience)?.package`
/// instead — never a modification to `IncrementalCompilerSynthesizer`/
/// `SolutionExecutionOrchestrator` themselves (both remain unchanged, per
/// this specification's own explicit rule).
///
/// ROLLBACK FLOW (Design A, chosen deliberately): `ExperienceModificationCoordinator
/// .rollback()`'s real contract (confirmed by reading it) is "restore an
/// already-persisted PRIOR package" — it has no concept of "prevent a
/// persist that hasn't happened yet." `applyEvolutionPlan()`'s own
/// validate-then-persist is atomic (nothing between them can fail once
/// validation passes). Since this coordinator ALWAYS runs
/// `ArtifactIntelligenceEngine`/`decideDeployment()` (or the incremental
/// path's equivalent real validity check) BEFORE ever calling
/// `applyEvolutionPlan()`, a `blocked` decision means `applyEvolutionPlan()`
/// is simply never invoked — the prior package remains authoritative,
/// untouched. There is therefore no real, reachable scenario within THIS
/// coordinator's own single `evolveExperience()` call where a persist
/// happens and then needs undoing — `LifecycleResult.rollbackPerformed` is
/// always `false` from this method's own internal flow, stated honestly
/// rather than fabricating a scenario to force `true`. `rollback()` itself
/// remains real, tested, and reachable — a caller holding a returned
/// `LifecycleResult.previousPackage` after a `deployed` outcome can
/// separately invoke `ExperienceModificationCoordinator.rollback()` later
/// (e.g. a user tapping "Undo" — the exact same UI-level pattern R7 already
/// established for `applyEvolutionPlan()`'s own `previousPackage`), proven
/// in this milestone's own tests.
///
/// DEPLOYMENT FLOW, the FULL-vs-INCREMENTAL asymmetry stated honestly:
/// `ArtifactIntelligenceEngine.analyze()` is built for a COMPLETE
/// `OrchestrationReport` where every applicable target was genuinely
/// attempted this cycle — its cross-target dependency check
/// (`_deploymentBlockers`) reads `report.outcomeFor(dep)` for every real
/// structural dependency `ExecutionTargetPlan.dependencies` names. For an
/// INCREMENTAL (Runtime-Experience-only) run, `runtimeExperience`'s own
/// `ExecutionTargetPlan.dependencies` may still legitimately name
/// `backendService`/`restApi` (a real, app-level fact — the solution HAS a
/// backend — independent of whether THIS diff touched it). Constructing a
/// synthetic `OrchestrationReport` with only the one real incremental stage
/// would either (a) omit those dependency targets entirely, making
/// `_deploymentBlockers` treat them as "missing" and incorrectly block a
/// perfectly good incremental change, or (b) require fabricating a
/// "succeeded" status for a dependency that was NOT actually re-verified
/// this cycle — both dishonest. The incremental path therefore uses its own
/// simpler, real, honest deployment gate instead: `IncrementalSynthesisResult
/// .succeeded` (package produced, zero compiler diagnostic errors) AND a
/// real `ExperiencePackageValidator.validate()` re-check (the SAME real
/// check `SolutionExecutionOrchestrator._runRuntimeExperienceStage` already
/// performs internally for a full run) — never routed through
/// `ArtifactIntelligenceEngine`/`decideDeployment()`, which are reserved for
/// the FULL path where they have a genuinely complete report to analyze.
/// `LifecycleResult.artifactIntelligenceReport` is therefore always `null`
/// for an incremental-path result — named honestly, not silently omitted.
library;

import '../artifact_intelligence/artifact_intelligence.dart';
import '../backend_engineering/backend_engineering_plan.dart';
import '../core/contracts/intent.dart';
import '../creation/experience_package.dart';
import '../creation/experience_package_diff.dart';
import '../creation/package_validator.dart';
import '../engineering_intelligence/incremental_compiler_synthesis.dart';
import '../evolution/evolution_diff_plan.dart';
import '../execution_planning/execution_strategy.dart';
import '../implementation_model/canonical_implementation_model.dart';
import '../kernel/anything_kernel.dart';
import '../kernel/outcomes/kernel_outcome.dart';
import '../solution_evolution/solution_evolution.dart';
import '../solution_orchestration/orchestration_result.dart';
import '../solution_orchestration/solution_execution_orchestrator.dart';
import '../storage/engineering_memory_repository.dart';
import '../storage/sqlite_experience_repository.dart';
import 'experience_modification_coordinator.dart';

/// Real, structured, terminal outcome of one [EngineeringLifecycleCoordinator
/// .evolveExperience] call — every case traceable to a real decision point
/// in the flow documented above.
enum LifecycleOutcome {
  /// [RegenerationPlan.isNoOp] — the diff was structurally empty. No
  /// execution primitive was ever invoked.
  noChangeDetected,

  /// A real, structural change was detected, but it touches nothing this
  /// solution has a real generator for (`RegenerationPlan.actions ==
  /// {validate}`, `CompilationMode.none`). No execution primitive was ever
  /// invoked.
  noActionableTarget,

  /// The regenerated candidate passed its real deployment gate and was
  /// committed via `applyEvolutionPlan()`.
  deployed,

  /// The regenerated candidate failed its real deployment gate — never
  /// persisted, the prior package remains authoritative.
  blocked,

  /// No real `EngineeringMemoryRecord` (or an incomplete one — missing
  /// `requirementGraph`/`architectureCandidate`) exists for this
  /// experienceId — a real, honest limitation (see this file's own
  /// "before"-state doc comment on [evolveExperience]), never a fabricated
  /// empty-graph fallback.
  noEngineeringMemory,

  /// The experience/package itself could not be loaded, or the fresh
  /// Kernel run did not reach `ExecutionPlanReady` (e.g. clarification
  /// required, provider missing) — a real, honest early exit.
  cannotEvolve,

  /// The candidate passed its deployment gate, but `applyEvolutionPlan()`
  /// itself rejected it (a real, defensive re-validation failure — see
  /// `ExperienceModificationCoordinator.applyEvolutionPlan()`'s own doc
  /// comment on why it never trusts a pre-validated candidate blindly).
  commitFailed,
}

/// Real, typed, inspectable result — every field traceable to the real
/// step that produced it, per this specification's own requested vocabulary
/// (RegenerationPlan/CompilationMode/ExecutionReport/ArtifactIntelligenceReport/
/// DeploymentDecision/RollbackPerformed/ExecutionDuration).
class LifecycleResult {
  final LifecycleOutcome outcome;
  final String message;
  final RegenerationPlan? regenerationPlan;
  final CompilationMode compilationMode;

  /// Populated only for a `CompilationMode.full` run — `null` for
  /// incremental, no-op, or not-actionable results.
  final OrchestrationReport? orchestrationReport;

  /// Populated only for a `CompilationMode.incremental` run.
  final IncrementalSynthesisResult? incrementalResult;

  /// Populated only for the FULL path (see this file's own "Deployment
  /// Flow" doc comment for why the incremental path never produces one).
  final ArtifactIntelligenceReport? artifactIntelligenceReport;

  final DeploymentDecision? deploymentDecision;

  /// Always `false` from this coordinator's own internal flow (Design A —
  /// see this file's own top-level doc comment). Real, reachable, and
  /// tested via a SEPARATE, caller-invoked `rollback()` call using
  /// [previousPackage] — never fabricated `true` here.
  final bool rollbackPerformed;

  final Duration executionDuration;

  /// The package that was authoritative before this call — real, useful to
  /// a caller wanting to later invoke `ExperienceModificationCoordinator
  /// .rollback()` after a `deployed` outcome. `null` when the experience
  /// itself could not be loaded.
  final ExperiencePackage? previousPackage;

  const LifecycleResult({
    required this.outcome,
    required this.message,
    this.regenerationPlan,
    this.compilationMode = CompilationMode.none,
    this.orchestrationReport,
    this.incrementalResult,
    this.artifactIntelligenceReport,
    this.deploymentDecision,
    this.rollbackPerformed = false,
    required this.executionDuration,
    this.previousPackage,
  });

  bool get succeeded => outcome == LifecycleOutcome.deployed || outcome == LifecycleOutcome.noChangeDetected;
}

class EngineeringLifecycleCoordinator {
  final AnythingKernel _kernel;
  final EngineeringMemoryRepository _engineeringMemory;
  final SqliteExperienceRepository _repository;
  final ExperienceModificationCoordinator _modificationCoordinator;

  static const _evolutionEngine = SolutionEvolutionEngine();
  static const _incrementalSynthesizer = IncrementalCompilerSynthesizer();
  static const _orchestrator = SolutionExecutionOrchestrator();
  static const _artifactIntelligence = ArtifactIntelligenceEngine();

  /// [engineeringMemory] is required (unlike its optional-elsewhere
  /// injection pattern in `ExperienceCreationCoordinator`/
  /// `ExperienceModificationCoordinator`) — it is this coordinator's whole
  /// real "before" state source, not an optional enrichment.
  EngineeringLifecycleCoordinator({
    required AnythingKernel kernel,
    required EngineeringMemoryRepository engineeringMemory,
    SqliteExperienceRepository? repository,
    ExperienceModificationCoordinator? modificationCoordinator,
  }) : _kernel = kernel,
       _engineeringMemory = engineeringMemory,
       _repository = repository ?? SqliteExperienceRepository(),
       _modificationCoordinator = modificationCoordinator ?? ExperienceModificationCoordinator();

  /// The real, single production entry point this specification exists for.
  /// "Before" state: real, persisted `EngineeringMemoryRecord.requirementGraph`/
  /// `.architectureCandidate` (R5/R8/R9) — NEVER a fabricated empty graph
  /// when absent (see [LifecycleOutcome.noEngineeringMemory]'s own doc
  /// comment). "After" state: a fresh run of the SAME, unmodified, single
  /// `AnythingKernel.processIntent()` reasoning call every other production
  /// path already uses — zero new AI call.
  Future<LifecycleResult> evolveExperience({required String experienceId, required Intent intent}) async {
    final stopwatch = Stopwatch()..start();

    final record = await _engineeringMemory.load(experienceId);
    if (record == null || record.requirementGraph == null || record.architectureCandidate == null) {
      stopwatch.stop();
      return LifecycleResult(
        outcome: LifecycleOutcome.noEngineeringMemory,
        message: 'No historical engineering memory is available for this experience — a diff-based evolution '
            'plan cannot be honestly computed without a real "before" state.',
        executionDuration: stopwatch.elapsed,
      );
    }

    final metadata = await _repository.getMetadata(experienceId);
    final previousPackage = await _repository.getPackage(experienceId);
    if (metadata == null || previousPackage == null) {
      stopwatch.stop();
      return LifecycleResult(outcome: LifecycleOutcome.cannotEvolve, message: 'App not found', executionDuration: stopwatch.elapsed);
    }

    final kernelOutcome = await _kernel.processIntent(intent);
    if (kernelOutcome is! ExecutionPlanReady ||
        kernelOutcome.requirementGraph == null ||
        kernelOutcome.solutionDecision == null ||
        kernelOutcome.executionStrategy == null ||
        kernelOutcome.canonicalImplementationModel == null) {
      stopwatch.stop();
      return LifecycleResult(
        outcome: LifecycleOutcome.cannotEvolve,
        message: 'The fresh reasoning pass for this intent did not reach a complete execution plan.',
        executionDuration: stopwatch.elapsed,
        previousPackage: previousPackage,
      );
    }

    final afterExecutionStrategy = kernelOutcome.executionStrategy!;
    final afterModel = kernelOutcome.canonicalImplementationModel!;

    final plan = _evolutionEngine.planRegeneration(
      beforeRequirements: record.requirementGraph!,
      afterRequirements: kernelOutcome.requirementGraph!,
      beforeArchitecture: record.architectureCandidate!,
      afterArchitecture: kernelOutcome.solutionDecision!.selected.architecture,
      afterExecutionStrategy: afterExecutionStrategy,
    );

    if (plan.isNoOp) {
      stopwatch.stop();
      return LifecycleResult(
        outcome: LifecycleOutcome.noChangeDetected,
        message: 'No structural change detected — nothing to regenerate.',
        regenerationPlan: plan,
        compilationMode: CompilationMode.none,
        executionDuration: stopwatch.elapsed,
        previousPackage: previousPackage,
      );
    }

    if (plan.compilationMode == CompilationMode.none) {
      stopwatch.stop();
      return LifecycleResult(
        outcome: LifecycleOutcome.noActionableTarget,
        message: 'A real structural change was detected, but no target with a real generator was affected.',
        regenerationPlan: plan,
        compilationMode: CompilationMode.none,
        executionDuration: stopwatch.elapsed,
        previousPackage: previousPackage,
      );
    }

    if (plan.compilationMode == CompilationMode.incremental) {
      return _runIncremental(experienceId: experienceId, name: metadata.name, plan: plan, afterModel: afterModel, previousPackage: previousPackage, stopwatch: stopwatch);
    }

    return _runFull(
      experienceId: experienceId,
      name: metadata.name,
      plan: plan,
      afterModel: afterModel,
      afterExecutionStrategy: afterExecutionStrategy,
      backendPlan: kernelOutcome.backendEngineeringPlan,
      previousPackage: previousPackage,
      stopwatch: stopwatch,
    );
  }

  Future<LifecycleResult> _runIncremental({
    required String experienceId,
    required String name,
    required RegenerationPlan plan,
    required CanonicalImplementationModel afterModel,
    required ExperiencePackage previousPackage,
    required Stopwatch stopwatch,
  }) async {
    final result = _incrementalSynthesizer.synthesize(fullModel: afterModel, affected: plan.affectedEntities, id: experienceId, name: name);

    // Real, honest deployment gate for the incremental path — see this
    // file's own top-level "Deployment Flow" doc comment for why
    // ArtifactIntelligenceEngine is not used here.
    final candidate = result.package;
    final valid = result.succeeded && candidate != null && ExperiencePackageValidator.validate(candidate).isValid;
    final decision = valid ? DeploymentDecision.allowed : DeploymentDecision.blocked;

    if (!valid) {
      stopwatch.stop();
      return LifecycleResult(
        outcome: LifecycleOutcome.blocked,
        message: 'The incrementally-regenerated candidate did not pass its real deployment gate.',
        regenerationPlan: plan,
        compilationMode: CompilationMode.incremental,
        incrementalResult: result,
        deploymentDecision: decision,
        executionDuration: stopwatch.elapsed,
        previousPackage: previousPackage,
      );
    }

    final evolutionPlan = _incrementalSynthesizer.buildEvolutionPlan(experienceId: experienceId, previousPackage: previousPackage, result: result);
    final commitOutcome = await _commit(evolutionPlan);
    stopwatch.stop();

    return LifecycleResult(
      outcome: commitOutcome ? LifecycleOutcome.deployed : LifecycleOutcome.commitFailed,
      message: commitOutcome ? 'Incremental regeneration deployed.' : "The regenerated candidate passed its deployment gate but couldn't be committed.",
      regenerationPlan: plan,
      compilationMode: CompilationMode.incremental,
      incrementalResult: result,
      deploymentDecision: decision,
      executionDuration: stopwatch.elapsed,
      previousPackage: previousPackage,
    );
  }

  Future<LifecycleResult> _runFull({
    required String experienceId,
    required String name,
    required RegenerationPlan plan,
    required CanonicalImplementationModel afterModel,
    required ExecutionStrategy afterExecutionStrategy,
    required BackendEngineeringPlan? backendPlan,
    required ExperiencePackage previousPackage,
    required Stopwatch stopwatch,
  }) async {
    final report = await _orchestrator.execute(strategy: afterExecutionStrategy, model: afterModel, id: experienceId, name: name, backendPlan: backendPlan);
    final artifactReport = _artifactIntelligence.analyze(report, afterExecutionStrategy);
    final decision = _evolutionEngine.decideDeployment(artifactReport);

    if (decision == DeploymentDecision.blocked) {
      stopwatch.stop();
      return LifecycleResult(
        outcome: LifecycleOutcome.blocked,
        message: 'The regenerated artifact set did not pass its real deployment gate: ${artifactReport.deploymentBlockers.join('; ')}',
        regenerationPlan: plan,
        compilationMode: CompilationMode.full,
        orchestrationReport: report,
        artifactIntelligenceReport: artifactReport,
        deploymentDecision: decision,
        executionDuration: stopwatch.elapsed,
        previousPackage: previousPackage,
      );
    }

    final evolutionPlan = _buildEvolutionPlanFromReport(experienceId: experienceId, previousPackage: previousPackage, report: report);
    final commitOutcome = await _commit(evolutionPlan);
    stopwatch.stop();

    return LifecycleResult(
      outcome: commitOutcome ? LifecycleOutcome.deployed : LifecycleOutcome.commitFailed,
      message: commitOutcome ? 'Full regeneration deployed.' : "The regenerated artifact set passed its deployment gate but couldn't be committed.",
      regenerationPlan: plan,
      compilationMode: CompilationMode.full,
      orchestrationReport: report,
      artifactIntelligenceReport: artifactReport,
      deploymentDecision: decision,
      executionDuration: stopwatch.elapsed,
      previousPackage: previousPackage,
    );
  }

  /// Mirrors `IncrementalCompilerSynthesizer.buildEvolutionPlan()`'s exact
  /// body (R24) — the SAME `ExperienceDiffer`/`EvolutionDiffPlanBuilder`
  /// (R4), just sourcing the candidate from an `OrchestrationReport`'s
  /// Runtime Experience stage instead of an `IncrementalSynthesisResult`.
  /// Coordinator-local glue only — never a change to either existing
  /// subsystem.
  EvolutionDiffPlan? _buildEvolutionPlanFromReport({required String experienceId, required ExperiencePackage previousPackage, required OrchestrationReport report}) {
    final newPackage = report.outcomeFor(ExecutionTargetKind.runtimeExperience)?.package;
    if (newPackage == null) return null;
    final experienceDiff = const ExperienceDiffer().diff(previousPackage, newPackage);
    return const EvolutionDiffPlanBuilder().build(experienceId: experienceId, experienceDiff: experienceDiff, candidatePackage: newPackage);
  }

  Future<bool> _commit(EvolutionDiffPlan? evolutionPlan) async {
    if (evolutionPlan == null) return false;
    final result = await _modificationCoordinator.applyEvolutionPlan(evolutionPlan);
    return result is ModificationCoordinatorSucceeded;
  }
}
