/// Orchestration result types — Implementation Specification IS-R25,
/// extended IS-R26.
library;

import '../creation/experience_package.dart';
import '../execution_planning/execution_strategy.dart';
import '../generator_framework/artifact.dart';

/// Real, checked completion — `succeeded` requires the underlying
/// pipeline to have produced a package, the compiler's own diagnostics to
/// carry no error, AND the package to pass the real, unmodified
/// `ExperiencePackageValidator` — never a boolean rubber stamp over just
/// one of those three (Implementation Specification IS-R25's "Completion
/// Criteria").
enum StageStatus {
  succeeded,
  failed,
  skippedNotApplicable,
  skippedNoGenerator,
}

/// One target's real, structured execution outcome.
class StageOutcome {
  final ExecutionTargetKind target;
  final StageStatus status;

  /// 1 for a stage that succeeded or failed on its first attempt; >1 only
  /// when real retries were consumed (see
  /// `SolutionExecutionOrchestrator`'s own doc comment on why retry
  /// rarely changes a deterministic pipeline's outcome). 0 for skipped
  /// stages — no attempt was ever made.
  final int attempts;

  final ExperiencePackage? package;

  /// Real, additive (Implementation Specification IS-R26, reused
  /// unmodified by IS-R27): a Backend Service or REST API stage's real,
  /// typed `Artifact` output — never an `ExperiencePackage` (structurally
  /// different artifact shape), so this stays a SEPARATE, nullable field
  /// rather than overloading [package]. Backend Service and REST API
  /// stages both produce a real `List<Artifact>` — the SAME structural
  /// shape — so this one field covers both; a caller distinguishes which
  /// generator produced it via [target] itself, never a second,
  /// structurally-identical field. A Runtime Experience stage always
  /// leaves this `null`; a Backend Service/REST API stage always leaves
  /// [package] `null`.
  final List<Artifact>? backendArtifacts;

  /// Real, named reasons this stage did not reach `succeeded` — validator
  /// errors, compiler diagnostics, or (for skipped stages) the real
  /// `ExecutionTargetPlan.reason` this milestone's own `SolutionExecutionPlanner`
  /// (R18) already computed.
  final List<String> errors;

  final Duration latency;

  const StageOutcome({
    required this.target,
    required this.status,
    required this.attempts,
    this.package,
    this.backendArtifacts,
    this.errors = const [],
    this.latency = Duration.zero,
  });

  bool get completionCriteriaMet => status == StageStatus.succeeded;
}

/// Corpus-level real result — every field is a plain, traceable read of
/// [stages], never a separately-computed summary that could drift from
/// the real per-stage record.
class OrchestrationReport {
  final List<List<ExecutionTargetKind>> levels;
  final bool levelOrderingComplete;
  final List<StageOutcome> stages;

  const OrchestrationReport({required this.levels, required this.levelOrderingComplete, required this.stages});

  bool get succeeded => levelOrderingComplete && stages.every((s) => s.status != StageStatus.failed);

  List<StageOutcome> get failedStages => stages.where((s) => s.status == StageStatus.failed).toList();

  StageOutcome? outcomeFor(ExecutionTargetKind target) => stages.where((s) => s.target == target).firstOrNull;
}
