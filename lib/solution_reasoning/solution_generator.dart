/// Solution Generator — materializes one full SolutionCandidate from one
/// ArchitectureVariation, applied as honest, structurally-real overrides
/// on top of the SAME self-critiqued baseline ArchitectureCandidate every
/// candidate shares (reusing ArchitecturePlanner/RefinementPlanner's real
/// output — never a second, parallel architecture-planning implementation).
library;

import '../application_engineering/engineering_context.dart';
import '../application_engineering/engineering_planner.dart';
import '../application_engineering/engineering_refinement.dart';
import '../feature_discovery/feature_types.dart'
    show ComplexityLevel, FeatureComplexity;
import '../software_architect/architecture_candidate.dart';
import '../software_architect/architecture_types.dart';
import 'solution_exploration_context.dart';
import 'solution_explanation.dart';
import 'solution_types.dart';
import 'solution_variation_types.dart';

class SolutionGenerator {
  const SolutionGenerator();

  SolutionCandidate build({
    required ArchitectureCandidate baseline,
    required ArchitectureVariation variation,
    required SolutionExplorationContext context,
  }) {
    final architecture = _applyVariation(baseline, variation);

    final engineeringCandidate = const EngineeringPlanner().plan(
      EngineeringContext(
        architecture: architecture,
        app: context.app,
        featureGraph: context.featureGraph,
      ),
    );
    final engineeringPlan = const EngineeringRefinement().refine(
      engineeringCandidate,
    );

    final id =
        'solution:${variation.label.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';

    return SolutionCandidate(
      id: id,
      label: variation.label,
      architecture: architecture,
      architectureVariation: variation,
      engineeringVariation: EngineeringVariation(plan: engineeringPlan),
      navigationVariation: NavigationVariation(
        topology: variation.navigationTopology,
        rationale:
            variation.navigationTopology == NavigationTopology.hierarchical
            ? 'Matches NavigationPlanner\'s real inferred edge shape (list -> detail/form).'
            : 'Every list view also gets a direct entry from the home screen.',
      ),
      capabilityVariation: CapabilityVariation(
        richness: variation.capabilityRichness,
        rationale: variation.capabilityRichness == CapabilityRichness.full
            ? 'Search/filter/sort enabled per InteractionPlanner\'s structural detection.'
            : 'Search/filter/sort deliberately omitted for a leaner first version.',
      ),
      offlineVariation: OfflineVariation(
        strategy: variation.offlineStrategy,
        rationale: variation.rationale,
      ),
      synchronizationVariation: SynchronizationVariation(
        strategy: variation.synchronizationStrategy,
        rationale:
            'Architecture-only — no server/cloud sync implementation exists or is planned (see V3).',
      ),
      storageVariation: const StorageVariation(
        description: 'Single generic SQLite table (ExperienceDatabase)',
        rationale:
            'Only one real storage backend exists in this codebase; not independently variable today.',
      ),
      stateVariation: const StateVariation(
        description:
            'Reactive/computed/persistent state assigned by StatePlanner from entity/derived-value shape',
        rationale:
            'Correct-by-construction given the app\'s own shape; not a preference a solution could vary.',
      ),
      dependencies: context.dependencyGraph,
      complexity: _complexityFor(variation),
      confidence: architecture.overallConfidence,
      explanation: SolutionExplanation(
        solutionId: id,
        whyGenerated: variation.rationale,
      ),
    );
  }

  ArchitectureCandidate _applyVariation(
    ArchitectureCandidate baseline,
    ArchitectureVariation variation,
  ) {
    var candidate = baseline;

    if (variation.capabilityRichness == CapabilityRichness.minimal) {
      final stripped = candidate.interactions
          .map(
            (i) => InteractionDecision(
              entityId: i.entityId,
              canCreate: i.canCreate,
              canRead: i.canRead,
              canUpdate: i.canUpdate,
              canDelete: i.canDelete,
              supportsSearch: false,
              supportsFilter: false,
              supportsSort: false,
              supportsPagination: i.supportsPagination,
              decision: i.decision,
            ),
          )
          .toList();
      candidate = candidate.copyWith(interactions: stripped);
    }

    if (variation.navigationTopology == NavigationTopology.flat) {
      final flatEdges = candidate.navigation.screenIds
          .where((id) => id != candidate.navigation.entryScreenId)
          .map(
            (id) => NavigationEdge(
              fromScreenId: candidate.navigation.entryScreenId,
              toScreenId: id,
              trigger: 'flatEntry',
            ),
          )
          .toList();
      candidate = candidate.copyWith(
        navigation: NavigationGraph(
          entryScreenId: candidate.navigation.entryScreenId,
          screenIds: candidate.navigation.screenIds,
          edges: flatEdges,
          decision: candidate.navigation.decision,
        ),
      );
    }

    candidate = candidate.copyWith(
      offline: OfflineDecision(
        capability: variation.offlineStrategy,
        decision: candidate.offline.decision,
      ),
      synchronization: SynchronizationDecision(
        strategy: variation.synchronizationStrategy,
        decision: candidate.synchronization.decision,
      ),
    );

    return candidate;
  }

  FeatureComplexity _complexityFor(ArchitectureVariation variation) {
    final capabilityLevel =
        variation.capabilityRichness == CapabilityRichness.full
        ? ComplexityLevel.medium
        : ComplexityLevel.low;
    final offlineLevel =
        variation.offlineStrategy == OfflineCapability.cacheThenOnline
        ? ComplexityLevel.medium
        : ComplexityLevel.low;

    ComplexityLevel worst(List<ComplexityLevel> levels) =>
        levels.reduce((a, b) => a.index > b.index ? a : b);

    return FeatureComplexity(
      implementation: worst([capabilityLevel, offlineLevel]),
      engineering: worst([capabilityLevel, offlineLevel]),
      runtime: capabilityLevel,
      memoryCost: capabilityLevel,
      storageCost: ComplexityLevel.low,
      batteryCost: offlineLevel == ComplexityLevel.medium
          ? ComplexityLevel.low
          : ComplexityLevel.none,
      networkCost: variation.offlineStrategy == OfflineCapability.onlineRequired
          ? ComplexityLevel.medium
          : ComplexityLevel.low,
      maintenanceCost: worst([capabilityLevel, offlineLevel]),
      modificationCost: capabilityLevel,
    );
  }
}
