/// EvolutionExecutor — compiles an approved [EvolutionProposal] down into
/// the EXISTING, untyped [ModificationOperation] vocabulary and hands it
/// to the existing [ModificationEngine] — the same "typed layer compiles
/// down into pre-existing runtime vocabulary" pattern already used by
/// EngineeringToBlueprintAugmenter (V3). Never a second modification
/// engine, never a rewrite of ModificationEngine's internals.
///
/// Honest about what can and cannot execute today: only categories
/// ModificationEngine already has a real operation for (capabilities,
/// generic UI/workflow additions) compile to something real. Cross-
/// cutting posture changes (offline/synchronization) and pure review-
/// signal improvements (accessibility/performance/maintainability) have
/// no corresponding ModificationOperation today and are reported as
/// [EvolutionNotExecutable] rather than fabricating a no-op operation.
library;

import '../creation/experience_package.dart';
import '../creation/modification/experience_modification_spec.dart';
import '../creation/modification/modification_engine.dart';
import 'evolution_candidate.dart';
import 'evolution_types.dart';

sealed class EvolutionExecutionPlan {
  const EvolutionExecutionPlan();
}

class EvolutionExecutable extends EvolutionExecutionPlan {
  final ExperienceModificationSpec spec;
  const EvolutionExecutable({required this.spec});
}

class EvolutionNotExecutable extends EvolutionExecutionPlan {
  final String reason;
  const EvolutionNotExecutable({required this.reason});
}

class EvolutionExecutor {
  final ModificationEngine _engine;

  EvolutionExecutor({ModificationEngine? engine}) : _engine = engine ?? ModificationEngine();

  /// Compiles the proposal into a typed [ExperienceModificationSpec], or
  /// honestly reports why it cannot compile one today.
  EvolutionExecutionPlan compile(EvolutionProposal proposal, String targetExperienceId, String basePackageVersion) {
    if (!proposal.approvedForExecution) {
      return const EvolutionNotExecutable(reason: 'Proposal has not been explicitly approved for execution.');
    }

    final opportunity = proposal.candidate.opportunity;
    final entityId = opportunity.reason.evidence.affectedNodeId;

    switch (opportunity.category) {
      case EvolutionOpportunityCategory.missingCapability:
        final featureId = opportunity.reason.evidence.sourceFeatureId;
        if (featureId == null || !featureId.startsWith('feature:capability:')) {
          return const EvolutionNotExecutable(reason: 'No capability id could be derived from this proposal.');
        }
        final capabilityId = featureId.replaceFirst('feature:capability:', '');
        return EvolutionExecutable(
          spec: ExperienceModificationSpec(
            targetExperienceId: targetExperienceId,
            basePackageVersion: basePackageVersion,
            objective: opportunity.description,
            operations: const [],
            requiredCapabilities: [capabilityId],
          ),
        );

      case EvolutionOpportunityCategory.missingWorkflow:
      case EvolutionOpportunityCategory.missingNavigation:
      case EvolutionOpportunityCategory.missingSearch:
      case EvolutionOpportunityCategory.missingFiltering:
        return EvolutionExecutable(
          spec: ExperienceModificationSpec(
            targetExperienceId: targetExperienceId,
            basePackageVersion: basePackageVersion,
            objective: opportunity.description,
            operations: [
              ModificationOperation(
                type: ModificationType.addUiNode,
                params: {'entityId': entityId, 'nodeType': 'button', 'label': opportunity.description},
              ),
            ],
          ),
        );

      case EvolutionOpportunityCategory.missingAccessibility:
      case EvolutionOpportunityCategory.missingPerformance:
      case EvolutionOpportunityCategory.missingMaintainability:
      case EvolutionOpportunityCategory.missingOffline:
      case EvolutionOpportunityCategory.missingSynchronization:
        return EvolutionNotExecutable(
          reason: 'No ModificationOperation exists yet for ${opportunity.category.name} — this proposal is '
              'roadmap-only until ModificationEngine gains a real operation for it.',
        );
    }
  }

  /// Executes an already-compiled plan against the existing package —
  /// delegates entirely to the real ModificationEngine.
  Future<ModificationResult> execute(ExperiencePackage package, ExperienceModificationSpec spec) {
    return _engine.modify(package, spec);
  }
}
