/// ArtifactIntelligenceEngine — Implementation Specification IS-R28.
///
/// REALITY this milestone builds on: `SolutionExecutionOrchestrator`
/// (R25, extended R26/R27) already produces a real, structured
/// `OrchestrationReport` after running an `ExecutionStrategy` (R18)
/// through the 3 real generators (Runtime Experience/Backend Service/REST
/// API). `OrchestrationReport.succeeded` is already real but COARSE: it
/// is `levelOrderingComplete && stages.every((s) => s.status !=
/// StageStatus.failed)` — it does NOT check that a succeeded stage's
/// real, structural DEPENDENCIES (`ExecutionTargetPlan.dependencies`,
/// R18) were themselves fulfilled. A dependency that was merely
/// `skippedNoGenerator`/`skippedNotApplicable` (never `failed`) would let
/// `succeeded` report `true` even though the dependent stage's real
/// prerequisite never actually produced anything.
///
/// `GenerationResult.dependencyManifest`/`DependencyReference` (R10,
/// `lib/generator_framework/generation_result.dart`) is a second, real,
/// pre-existing "artifact dependency" concept — confirmed by grep, never
/// populated by any of the 3 real generators. Investigated and NOT used
/// as this milestone's integration point: it models per-artifact
/// ecosystem package dependencies (e.g. `http-client >=1.0.0`), a
/// different real concern than EXECUTION dependencies between targets.
/// Populating it with invented package names for generators that emit no
/// real ecosystem-package signal would fabricate data. `ArtifactKnowledge`
/// below is deliberately built over `ExecutionTargetPlan.dependencies`
/// instead — the real, already-populated, already-tested (R18/R26/R27)
/// structural dependency data.
///
/// Design: `ArtifactIntelligenceEngine` is a pure, additive, POST-hoc
/// analysis over an ALREADY-COMPLETED `OrchestrationReport` +
/// the `ExecutionStrategy` that produced it — it never re-plans, never
/// re-executes, never touches `SolutionExecutionOrchestrator.execute()`
/// (confirmed unmodified). Artifact provenance (which real
/// `GeneratorMetadata.id` produced a stage's output) is read directly off
/// `ExecutionStrategy.forTarget(target).requiredGenerators` — the SAME
/// real data `SolutionExecutionPlanner` (R18) already populated — never a
/// new field threaded through `StageOutcome`.
library;

import 'dart:convert';

import '../execution_planning/execution_strategy.dart';
import '../generator_framework/artifact.dart';
import '../solution_orchestration/orchestration_result.dart';

/// One target's real, derived artifact knowledge — never a copy of
/// `StageOutcome`'s own fields, a real VIEW joining it against
/// `ExecutionStrategy`.
class ArtifactKnowledge {
  final ExecutionTargetKind target;
  final StageStatus status;

  /// The real `GeneratorMetadata.id` that produced this target's output —
  /// empty when the target was never `applicableWithGenerator` (skipped/
  /// not-applicable targets have no real generator to name).
  final List<String> producedBy;

  /// Real structural dependency edges (`ExecutionTargetPlan.dependencies`,
  /// R18) — the targets this one's artifact depends on.
  final List<ExecutionTargetKind> dependsOn;

  /// The inverse edge — real, derived by scanning every OTHER target's
  /// `dependencies` for this one.
  final List<ExecutionTargetKind> consumedBy;

  final bool completionCriteriaMet;
  final List<String> errors;

  const ArtifactKnowledge({
    required this.target,
    required this.status,
    required this.producedBy,
    required this.dependsOn,
    required this.consumedBy,
    required this.completionCriteriaMet,
    required this.errors,
  });
}

/// One real, checkable cross-artifact invariant and its real result —
/// never a fabricated compatibility claim between artifacts with no
/// actual shared upstream data to compare.
class CompatibilityCheck {
  final String name;
  final bool passed;
  final String description;

  const CompatibilityCheck({
    required this.name,
    required this.passed,
    required this.description,
  });
}

/// The real, corpus-level result — every field is a plain, traceable
/// derivation from the input `OrchestrationReport`/`ExecutionStrategy`,
/// never a separately-computed summary that could drift.
class ArtifactIntelligenceReport {
  final List<ArtifactKnowledge> knowledge;
  final List<CompatibilityCheck> compatibilityChecks;

  /// Real, RICHER readiness than `OrchestrationReport.succeeded` alone:
  /// also requires every succeeded stage's real dependencies to have
  /// themselves succeeded — see this file's own top-level doc comment.
  final bool deploymentReady;

  final List<String> deploymentBlockers;

  const ArtifactIntelligenceReport({
    required this.knowledge,
    required this.compatibilityChecks,
    required this.deploymentReady,
    required this.deploymentBlockers,
  });

  ArtifactKnowledge? knowledgeFor(ExecutionTargetKind target) =>
      knowledge.where((k) => k.target == target).firstOrNull;

  bool get allCompatibilityChecksPassed =>
      compatibilityChecks.every((c) => c.passed);
}

class ArtifactIntelligenceEngine {
  const ArtifactIntelligenceEngine();

  ArtifactIntelligenceReport analyze(
    OrchestrationReport report,
    ExecutionStrategy strategy,
  ) {
    final knowledge = [
      for (final stage in report.stages) _knowledgeFor(stage, strategy),
    ];
    final compatibilityChecks = _compatibilityChecks(report);
    final blockers = _deploymentBlockers(report, strategy);

    return ArtifactIntelligenceReport(
      knowledge: knowledge,
      compatibilityChecks: compatibilityChecks,
      deploymentReady:
          report.succeeded &&
          blockers.isEmpty &&
          compatibilityChecks.every((c) => c.passed),
      deploymentBlockers: blockers,
    );
  }

  ArtifactKnowledge _knowledgeFor(
    StageOutcome stage,
    ExecutionStrategy strategy,
  ) {
    final plan = strategy.targets
        .where((t) => t.target == stage.target)
        .firstOrNull;
    final consumedBy = [
      for (final other in strategy.targets)
        if (other.dependencies.contains(stage.target)) other.target,
    ];
    return ArtifactKnowledge(
      target: stage.target,
      status: stage.status,
      producedBy: plan?.requiredGenerators ?? const [],
      dependsOn: plan?.dependencies ?? const [],
      consumedBy: consumedBy,
      completionCriteriaMet: stage.completionCriteriaMet,
      errors: stage.errors,
    );
  }

  /// Real deployment-readiness check `OrchestrationReport.succeeded`
  /// alone does not make: every SUCCEEDED stage's real, structural
  /// dependencies must have themselves succeeded — a dependency that was
  /// only skipped (never `failed`) would otherwise pass `succeeded`
  /// silently.
  List<String> _deploymentBlockers(
    OrchestrationReport report,
    ExecutionStrategy strategy,
  ) {
    final blockers = <String>[];
    for (final stage in report.stages) {
      if (stage.status != StageStatus.succeeded) continue;
      final plan = strategy.targets
          .where((t) => t.target == stage.target)
          .firstOrNull;
      if (plan == null) continue;
      for (final dep in plan.dependencies) {
        final depOutcome = report.outcomeFor(dep);
        if (depOutcome == null || depOutcome.status != StageStatus.succeeded) {
          blockers.add(
            '${stage.target.name} succeeded but its real dependency ${dep.name} did not '
            '(status: ${depOutcome?.status.name ?? 'missing'}) — the produced artifact set is not deployable as-is.',
          );
        }
      }
    }
    return blockers;
  }

  /// The ONE real, checkable cross-artifact invariant among the 3 real
  /// generators: Backend Service and REST API both serialize
  /// `BackendEngineeringPlan.authentication` under an identical
  /// `'authentication'` JSON key (confirmed by reading
  /// `backend_engineering_serialization.dart`/`rest_api_generator.dart`)
  /// — for one real orchestration run, both artifacts derive from the
  /// SAME `BackendEngineeringPlan`, so they must agree. No other real,
  /// derivable cross-artifact invariant exists among the 3 real
  /// generators today (Runtime Experience's manifest carries no
  /// backend-derived signal to cross-check — `RuntimeExperienceGenerator`
  /// hardcodes `networkMode: NetworkMode.none` regardless of backend
  /// presence, confirmed by reading it — checking it against backend
  /// presence would be comparing against a constant, not real signal).
  List<CompatibilityCheck> _compatibilityChecks(OrchestrationReport report) {
    final backend = report.outcomeFor(ExecutionTargetKind.backendService);
    final restApi = report.outcomeFor(ExecutionTargetKind.restApi);
    if (backend?.status != StageStatus.succeeded ||
        restApi?.status != StageStatus.succeeded) {
      return const [];
    }
    final backendAuth = _authSection(backend?.backendArtifacts);
    final restApiAuth = _authSection(restApi?.backendArtifacts);
    if (backendAuth == null || restApiAuth == null) return const [];

    final matches = const DeepCollectionEquality().equals(
      backendAuth,
      restApiAuth,
    );
    return [
      CompatibilityCheck(
        name: 'backendService.authentication == restApi.authentication',
        passed: matches,
        description: matches
            ? 'Both artifacts agree on requiresCredentials/providerIndependent — real, since both derive from the same BackendEngineeringPlan.'
            : 'Backend Service and REST API artifacts disagree on authentication — a real inconsistency, never silently ignored.',
      ),
    ];
  }

  Map<String, dynamic>? _authSection(List<Artifact>? artifacts) {
    if (artifacts == null || artifacts.isEmpty) return null;
    for (final artifact in artifacts) {
      final content = artifact.content;
      if (content == null) continue;
      try {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        if (decoded['authentication'] is Map<String, dynamic>) {
          return decoded['authentication'] as Map<String, dynamic>;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

/// Minimal, real, dependency-free deep-equality for two decoded JSON
/// `Map<String, dynamic>`s — both real authentication sections here are
/// flat (`{requiresCredentials: bool, providerIndependent: bool}`), so a
/// real recursive Map/List/primitive comparison is sufficient; never a
/// new package dependency for what a few lines already cover (this
/// codebase's own established convention — see
/// `EquivalenceComparator._deepEquals`, R19).
class DeepCollectionEquality {
  const DeepCollectionEquality();

  bool equals(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !equals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!equals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
