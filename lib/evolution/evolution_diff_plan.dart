/// EvolutionDiffPlan — Implementation Milestone R4's composed output:
/// ordered, deterministic mutations derived from real structural diffs,
/// planning-only (no runtime patching — see `requirement_graph_diff.dart`
/// for the scope statement this file's own diff inputs already carry).
///
/// Deliberately NOT named `EvolutionPlan` and deliberately NOT built by
/// extending `EvolutionProposal`/`EvolutionRoadmap` (Vision Milestone
/// V7) — investigated first, per Rule 2/Rule 3. `EvolutionCandidate`
/// requires an `EvolutionOpportunity` (something `EvolutionObserver`
/// itself detected) plus cost/risk/benefit ESTIMATES; forcing an
/// explicit, already-diffed modification request into that shape would
/// mean fabricating an "opportunity" and cost/benefit scores for
/// something that isn't a proactive suggestion at all — it's the
/// deterministic structural CONSEQUENCE of a decision already made
/// (Rule 5: no fabricated data). `EvolutionRoadmap`/`EvolutionProposal`
/// answer "what SHOULD change and is it worth it"; `EvolutionDiffPlan`
/// answers a genuinely different, complementary question: "given a
/// change that's already been decided (by a user request OR an approved
/// `EvolutionProposal`), what is the exact, ordered, deterministic
/// sequence of structural mutations, with real rollback data." This is
/// new because the codebase had no diff-composition concept before R3/R4
/// — not because the existing Evolution vocabulary was insufficient for
/// its own, different job. `EvolutionMutation.expectedImpact` reuses the
/// existing `RiskLevel` enum from `software_architect/confidence.dart`
/// directly rather than inventing a parallel severity scale.
library;

import '../application_engineering/engineering_candidate_diff.dart';
import '../application_engineering/engineering_memory_summary.dart';
import '../creation/experience_package.dart';
import '../creation/experience_package_diff.dart';
import '../software_architect/architecture_candidate.dart';
import '../software_architect/architecture_candidate_diff.dart';
import '../software_architect/confidence.dart' show RiskLevel;
import '../software_architect/requirement_graph.dart';
import '../software_architect/requirement_graph_diff.dart';

/// Real, persisted engineering history for an Experience (Implementation
/// Milestone R5), surfaced by [EvolutionDiffPlan.historicalEngineeringMemory]
/// — see that field's doc comment for why this is history, not a diff.
class HistoricalEngineeringMemory {
  final RequirementGraph? requirementGraph;
  final ArchitectureCandidate? architectureCandidate;
  final EngineeringMemorySummary? engineeringSummary;

  const HistoricalEngineeringMemory({
    this.requirementGraph,
    this.architectureCandidate,
    this.engineeringSummary,
  });
}

/// One deterministic mutation in the plan, always traceable to a real
/// source diff — never a bare instruction with no evidence.
class EvolutionMutation {
  final String reason;
  final String sourceDiffDescription;
  final String targetObject;
  final RiskLevel expectedImpact;
  final List<String> dependencies;
  final String rollbackInfo;

  const EvolutionMutation({
    required this.reason,
    required this.sourceDiffDescription,
    required this.targetObject,
    required this.expectedImpact,
    this.dependencies = const [],
    required this.rollbackInfo,
  });
}

class EvolutionDiffPlan {
  final String experienceId;
  final RequirementGraphDiff? requirementDiff;
  final ArchitectureDiff? architectureDiff;
  final EngineeringDiff? engineeringDiff;
  final ExperienceDiff experienceDiff;
  final List<EvolutionMutation> mutations;
  final DateTime generatedAt;

  /// Persisted "before" engineering memory (Implementation Milestone R5),
  /// when available — real, historical `RequirementGraph`/
  /// `ArchitectureCandidate` this Experience was actually engineered
  /// from. Deliberately NOT a diff: computing [requirementDiff]/
  /// [architectureDiff] would require re-deriving a genuine "after" state
  /// by re-running Requirement/Architecture planning against the
  /// modification, which `ExperienceModificationCoordinator` does not do
  /// (it patches `ExperiencePackage` directly, never re-invoking the
  /// Kernel's planning stages) — doing so without a real, non-fabricated
  /// path would mean inventing data. Exposing the real historical state
  /// here still closes R5's core objective ("Anything must no longer
  /// forget how an Experience was engineered") honestly, without
  /// overclaiming a diff that isn't genuinely computable this milestone
  /// (see Known Limitations).
  final HistoricalEngineeringMemory? historicalEngineeringMemory;

  /// The already-computed, not-yet-validated-or-persisted candidate
  /// package this plan was derived from (Implementation Milestone R6).
  /// REALITY: `planEvolution()` already computes this via
  /// `ModificationEngine.modify()` — R4/R5 simply discarded it after
  /// building the plan, forcing any "apply" caller to hypothetically
  /// re-run modification logic a second time. Carrying it here lets
  /// `ExperienceModificationCoordinator.applyEvolutionPlan()` validate and
  /// persist the SAME candidate the plan already describes — never a
  /// second modification computation, never silently re-deriving a
  /// possibly-different candidate from a stale expression string.
  /// Nullable so pre-R6 callers/tests that build a plan directly (without
  /// going through `planEvolution()`) are unaffected — `applyEvolutionPlan()`
  /// honestly rejects a plan with no candidate rather than crashing.
  final ExperiencePackage? candidatePackage;

  const EvolutionDiffPlan({
    required this.experienceId,
    this.requirementDiff,
    this.architectureDiff,
    this.engineeringDiff,
    required this.experienceDiff,
    required this.mutations,
    required this.generatedAt,
    this.historicalEngineeringMemory,
    this.candidatePackage,
  });

  bool get isEmpty => mutations.isEmpty;
}

class EvolutionDiffPlanBuilder {
  const EvolutionDiffPlanBuilder();

  /// Composes whichever diffs are available into one ordered, real,
  /// deterministic plan — same inputs always produce the same mutation
  /// list, in the same order (Rule 7). [requirementDiff]/
  /// [architectureDiff]/[engineeringDiff] are optional: `ExperienceSpec`/
  /// `ArchitectureCandidate`/`EngineeringCandidate` are transient,
  /// Kernel-internal, per-request artifacts today (never persisted per
  /// Experience) — a caller only has "before" and "after" instances of
  /// them when it happens to have re-run planning for both, which is a
  /// real, honest limitation, not silently glossed over (see this
  /// milestone's Known Limitations). [experienceDiff] is always required
  /// since `ExperiencePackage` — unlike the three transient types above —
  /// IS the real, persisted artifact `ExperienceModificationCoordinator`
  /// already has a genuine "before" and "after" of on every call.
  EvolutionDiffPlan build({
    required String experienceId,
    RequirementGraphDiff? requirementDiff,
    ArchitectureDiff? architectureDiff,
    EngineeringDiff? engineeringDiff,
    required ExperienceDiff experienceDiff,
    HistoricalEngineeringMemory? historicalEngineeringMemory,
    ExperiencePackage? candidatePackage,
  }) {
    final mutations = <EvolutionMutation>[];
    String? previousStage;

    if (requirementDiff != null && !requirementDiff.isEmpty) {
      mutations.add(
        EvolutionMutation(
          reason:
              '${requirementDiff.addedNodes.length} requirement(s) added, '
              '${requirementDiff.removedNodes.length} removed.',
          sourceDiffDescription: 'RequirementGraphDiff',
          targetObject: 'RequirementGraph',
          expectedImpact: _impactFor(
            requirementDiff.addedNodes.length +
                requirementDiff.removedNodes.length,
          ),
          rollbackInfo:
              'Swap addedNodes/removedNodes and addedRelations/removedRelations.',
        ),
      );
      previousStage = 'RequirementGraph';
    }

    if (architectureDiff != null && !architectureDiff.isEmpty) {
      final changeCount =
          architectureDiff.addedEntities.length +
          architectureDiff.removedEntities.length +
          architectureDiff.addedCapabilities.length +
          architectureDiff.removedCapabilities.length;
      mutations.add(
        EvolutionMutation(
          reason:
              '${architectureDiff.addedEntities.length} entity(ies) added, '
              '${architectureDiff.removedEntities.length} removed; '
              '${architectureDiff.addedCapabilities.length} capability(ies) added.',
          sourceDiffDescription: 'ArchitectureDiff',
          targetObject: 'ArchitectureCandidate',
          expectedImpact: _impactFor(changeCount),
          dependencies: previousStage != null ? [previousStage] : const [],
          rollbackInfo:
              'Swap added*/removed* lists and restore prior security/offline/synchronization decisions.',
        ),
      );
      previousStage = 'ArchitectureCandidate';
    }

    if (engineeringDiff != null && !engineeringDiff.isEmpty) {
      mutations.add(
        EvolutionMutation(
          reason:
              '${engineeringDiff.addedBindings.length} binding(s) added, '
              '${engineeringDiff.removedBindings.length} removed; '
              '${engineeringDiff.addedValidations.length} validation(s) changed.',
          sourceDiffDescription: 'EngineeringDiff',
          targetObject: 'EngineeringCandidate',
          expectedImpact: _impactFor(
            engineeringDiff.addedBindings.length +
                engineeringDiff.removedBindings.length,
          ),
          dependencies: previousStage != null ? [previousStage] : const [],
          rollbackInfo:
              'Swap addedBindings/removedBindings and restore prior *Change decision strings.',
        ),
      );
      previousStage = 'EngineeringCandidate';
    }

    if (!experienceDiff.isEmpty) {
      final changeCount =
          experienceDiff.addedScreens.length +
          experienceDiff.removedScreens.length +
          experienceDiff.addedComponents.length +
          experienceDiff.removedComponents.length +
          experienceDiff.addedCapabilities.length +
          experienceDiff.removedCapabilities.length;
      mutations.add(
        EvolutionMutation(
          reason:
              '${experienceDiff.addedScreens.length} screen(s) added, '
              '${experienceDiff.addedComponents.length} component(s) added, '
              '${experienceDiff.removedComponents.length} removed'
              '${experienceDiff.behaviorChanged ? '; behavior changed' : ''}'
              '${experienceDiff.stateChanged ? '; state changed' : ''}'
              '${experienceDiff.dataSchemaChanged ? '; data schema changed' : ''}.',
          sourceDiffDescription: 'ExperienceDiff',
          targetObject: 'ExperiencePackage',
          expectedImpact: _impactFor(
            changeCount,
            structuralFlagsChanged:
                experienceDiff.behaviorChanged ||
                experienceDiff.dataSchemaChanged,
          ),
          dependencies: previousStage != null ? [previousStage] : const [],
          rollbackInfo:
              'Restore the prior ExperiencePackage version (ModificationEngine keeps the old package until validation succeeds).',
        ),
      );
    }

    return EvolutionDiffPlan(
      experienceId: experienceId,
      requirementDiff: requirementDiff,
      architectureDiff: architectureDiff,
      engineeringDiff: engineeringDiff,
      experienceDiff: experienceDiff,
      mutations: mutations,
      generatedAt: DateTime.now(),
      historicalEngineeringMemory: historicalEngineeringMemory,
      candidatePackage: candidatePackage,
    );
  }

  /// Real, bounded, deterministic heuristic — never a fabricated score.
  /// A data-schema or behavior change is inherently riskier than a purely
  /// additive UI change, independent of raw count.
  RiskLevel _impactFor(int changeCount, {bool structuralFlagsChanged = false}) {
    if (structuralFlagsChanged || changeCount > 10) return RiskLevel.high;
    if (changeCount > 3) return RiskLevel.medium;
    if (changeCount > 0) return RiskLevel.low;
    return RiskLevel.none;
  }
}
