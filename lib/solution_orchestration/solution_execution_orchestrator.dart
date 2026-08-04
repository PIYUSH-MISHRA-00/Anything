/// SolutionExecutionOrchestrator — Implementation Specification IS-R25.
///
/// REALITY (see `docs/architecture/SOLUTION_ORCHESTRATION.md` for the full
/// audit): `SolutionExecutionPlanner` (R18) already produces a real
/// `ExecutionStrategy` — target/classification/reason/priority/dependencies/
/// executionOrder/requiredGenerators/validationRequirements/buildRequirements/
/// deploymentRequirements — but deliberately never EXECUTES it (its own
/// doc comment: "this planner only decides WHAT should be executed... a
/// caller invokes [the compiler] using this plan's requiredGenerators/
/// actionableTargets"). Nothing in this codebase, before this
/// specification, ever walked `ExecutionStrategy.actionableTargets` and
/// actually ran a stage. This orchestrator is that missing caller — never
/// a second planner, never a second compiler: it dispatches through the
/// EXISTING `runCompilerPipeline` (R19) / `IncrementalCompilerSynthesizer`
/// (R24), validates through the EXISTING, UNMODIFIED
/// `ExperiencePackageValidator`, and never embeds generator logic itself.
///
/// Of R18's 12 execution targets, only Runtime Experience ever reaches
/// `applicableWithGenerator` today (confirmed by re-reading
/// `SolutionExecutionPlanner`) — real production `ExecutionStrategy`s
/// therefore only ever produce ONE actionable stage. The level-ordering/
/// concurrent-dispatch machinery below is real and correctness-tested on
/// synthetic multi-target fixtures, but has no real multi-stage instance
/// to run today — stated honestly, never overclaimed.
///
/// PARALLEL EXECUTION, stated precisely: stages within one level are
/// dispatched via `Future.wait`, a real Dart concurrency primitive — but
/// Dart runs on a single isolate, and both real execution primitives
/// (`runCompilerPipeline`/`IncrementalCompilerSynthesizer`) are
/// synchronous, CPU-bound, in-memory computations with no internal
/// `await`. `Future.wait` over purely synchronous work does not achieve
/// genuine multi-core speedup — what it DOES real and correctly provide
/// is dependency-safe ORDERING (nothing in a later level starts before
/// every stage in every earlier level has completed) and a real
/// concurrency-ready shape for a FUTURE generator that does perform
/// genuine async I/O. True CPU parallelism would require Dart Isolates —
/// out of scope here, named for a future milestone.
///
/// RETRY, stated precisely: `runCompilerPipeline`/`IncrementalCompilerSynthesizer`
/// are pure, deterministic functions of their input (proven since R13/R19/
/// R24's own determinism tests) with no I/O of their own — a retry of an
/// identical input can only ever reproduce an identical outcome. Retry
/// exists here as real, tested, bounded infrastructure (never an infinite
/// loop, always a real structured failure once exhausted) for a stage
/// type that has a genuine transient-failure surface — it is honestly NOT
/// expected to change today's deterministic pipeline's result, and this
/// file says so rather than fabricating retry/backoff sophistication with
/// no real failure signal behind it.
///
/// ROLLBACK: the real, existing `ExperienceModificationCoordinator.rollback()`
/// (R6) is reused, never reimplemented — but this orchestrator lives
/// beneath `lib/app/`, and `ExperienceModificationCoordinator` lives
/// inside it (the established layering direction: `lib/app/` composes
/// lower-level `lib/` subsystems, never the reverse — confirmed by every
/// prior milestone's coordinator, e.g. `SoftwareCognitionCoordinator`
/// never imports `ExperienceCreationCoordinator`). This orchestrator
/// therefore does not call `rollback()` itself; it reports failure via
/// [OrchestrationReport.failedStages], and a caller in `lib/app/` (proven
/// end-to-end in `test/r25_solution_orchestrator_test.dart`) uses that
/// report to invoke the real, unmodified `rollback()` on a modification
/// request's prior package.
library;

import '../compiler_integration/compiler_pipeline_runner.dart';
import '../creation/experience_package.dart';
import '../creation/package_validator.dart';
import '../engineering_intelligence/affected_entities.dart';
import '../engineering_intelligence/incremental_compiler_synthesis.dart';
import '../execution_planning/execution_strategy.dart';
import '../generator_framework/generation_result.dart';
import '../implementation_model/canonical_implementation_model.dart';
import 'execution_ordering.dart';
import 'orchestration_result.dart';

class SolutionExecutionOrchestrator {
  const SolutionExecutionOrchestrator();

  /// [affected]: when supplied and non-empty, every stage dispatches
  /// through the real, existing `IncrementalCompilerSynthesizer` (R24)
  /// instead of a full `runCompilerPipeline` (R19) run — a real,
  /// observable dispatch choice, never a heuristic guess.
  /// [maxAttempts]: bounded retry count per stage, default 1 (no retry) —
  /// see this file's own top-level doc comment on why retry is honestly
  /// unlikely to change a deterministic pipeline's outcome; a caller with
  /// a genuine transient-failure-prone future generator can raise this.
  Future<OrchestrationReport> execute({
    required ExecutionStrategy strategy,
    required CanonicalImplementationModel model,
    required String id,
    required String name,
    AffectedEntities? affected,
    int maxAttempts = 1,
  }) async {
    final levels = const ExecutionTargetOrderer().order(strategy);
    final stages = <StageOutcome>[];

    // Non-actionable targets never enter the level ordering above (only
    // `applicableTargets` do) — recorded here as real, honest, zero-attempt
    // skips so a caller sees the full 12-target picture, not just the
    // executed subset.
    for (final plan in strategy.targets) {
      if (plan.classification == ExecutionTargetClassification.notApplicable) {
        stages.add(StageOutcome(target: plan.target, status: StageStatus.skippedNotApplicable, attempts: 0, errors: [plan.reason]));
      } else if (plan.classification == ExecutionTargetClassification.applicableNoGenerator) {
        stages.add(StageOutcome(target: plan.target, status: StageStatus.skippedNoGenerator, attempts: 0, errors: [plan.reason]));
      }
    }

    for (final level in levels.levels) {
      final actionable = level.where((t) => strategy.forTarget(t).classification == ExecutionTargetClassification.applicableWithGenerator);
      final results = await Future.wait(actionable.map((target) => _runStage(target: target, model: model, id: id, name: name, affected: affected, maxAttempts: maxAttempts)));
      stages.addAll(results);
    }

    return OrchestrationReport(levels: levels.levels, levelOrderingComplete: levels.isComplete, stages: stages);
  }

  Future<StageOutcome> _runStage({
    required ExecutionTargetKind target,
    required CanonicalImplementationModel model,
    required String id,
    required String name,
    required AffectedEntities? affected,
    required int maxAttempts,
  }) async {
    final stopwatch = Stopwatch()..start();
    var attempt = 0;
    while (true) {
      attempt++;
      final ExperiencePackage? package;
      final GenerationResult compilerResult;
      if (affected != null && !affected.isEmpty) {
        final result = const IncrementalCompilerSynthesizer().synthesize(fullModel: model, affected: affected, id: id, name: name);
        package = result.package;
        compilerResult = result.compilerResult;
      } else {
        final result = runCompilerPipeline(model, id: id, name: name);
        package = result.package;
        compilerResult = result.result;
      }

      final compilerErrors = compilerResult.diagnostics.where((d) => d.severity == DiagnosticSeverity.error).map((d) => d.message).toList();
      final validation = package != null ? ExperiencePackageValidator.validate(package) : null;

      final succeeded = package != null && compilerErrors.isEmpty && (validation?.isValid ?? false);
      if (succeeded) {
        stopwatch.stop();
        return StageOutcome(target: target, status: StageStatus.succeeded, attempts: attempt, package: package, latency: stopwatch.elapsed);
      }
      if (attempt >= maxAttempts) {
        stopwatch.stop();
        final errors = [...compilerErrors, ...?validation?.errors, if (package == null && compilerErrors.isEmpty) 'Compiler pipeline produced no artifact for this target.'];
        return StageOutcome(target: target, status: StageStatus.failed, attempts: attempt, errors: errors, latency: stopwatch.elapsed);
      }
      // Real bounded retry — see this file's own doc comment on why this
      // rarely changes a deterministic pipeline's outcome.
    }
  }
}
