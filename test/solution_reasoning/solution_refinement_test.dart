/// Vision V5 MSRA — SolutionRefinement: drop auto-fixable-critical
/// candidates iteratively, deterministic termination, never drop every
/// candidate.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:anything/feature_discovery/dependency_resolver.dart';
import 'package:anything/feature_discovery/feature_discovery_context.dart';
import 'package:anything/feature_discovery/feature_discovery_engine.dart';
import 'package:anything/kernel/classification/intent_category.dart';
import 'package:anything/kernel/specification/experience_spec.dart'
    show NetworkNeed;
import 'package:anything/kernel/understanding/intent_understanding.dart';
import 'package:anything/software_architect/architecture_planner.dart';
import 'package:anything/software_architect/architecture_types.dart'
    show OfflineCapability;
import 'package:anything/software_architect/confidence.dart';
import 'package:anything/software_architect/refinement_planner.dart';
import 'package:anything/software_architect/requirement_extractor.dart';
import 'package:anything/solution_reasoning/solution_exploration_context.dart';
import 'package:anything/solution_reasoning/solution_generator.dart';
import 'package:anything/solution_reasoning/solution_history.dart';
import 'package:anything/solution_reasoning/solution_refinement.dart';
import 'package:anything/solution_reasoning/solution_score.dart';
import 'package:anything/solution_reasoning/solution_variation_types.dart';
import 'package:anything/synthesis/app_blueprint.dart';
import 'package:anything/synthesis/application_reasoner.dart';

const _architecturePlanner = ArchitecturePlanner();
const _refinementPlanner = RefinementPlanner();
const _requirementExtractor = RequirementExtractor();
const _featureEngine = FeatureDiscoveryEngine();
const _generator = SolutionGenerator();

IntentUnderstanding _understanding() {
  return IntentUnderstanding(
    intentId: 'test-${DateTime.now().microsecondsSinceEpoch}',
    objective: 'test',
    category: IntentCategory.create,
    existingExperience: const ExistingExperienceResolution(
      status: ExistingExperienceStatus.notChecked,
    ),
    desiredOutcome: '',
    confidence: 0.9,
    networkNeed: NetworkNeed.none,
    creationNeed: CreationNeed.definitelyNeeded,
    modificationNeed: ModificationNeed.notNeeded,
  );
}

SemanticApp _app() {
  return SemanticApp(
    name: 'Field Survey Log',
    purpose: 'p',
    entities: [
      const SemanticEntity(
        id: 'entry',
        name: 'Entry',
        fields: [
          SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
          ),
        ],
      ),
    ],
  );
}

SolutionScore _score(double v) {
  final c = Confidence(score: v, reason: 'test');
  return SolutionScore(
    overall: c,
    engineering: c,
    architecture: c,
    maintainability: c,
    runtime: c,
    performance: c,
    security: c,
    offline: c,
    userExperience: c,
    accessibility: c,
    futureEvolution: c,
  );
}

void main() {
  final app = _app();
  final requirements = _requirementExtractor.extract(
    app: app,
    understanding: _understanding(),
  );
  final featureGraph = _featureEngine.plan(
    FeatureDiscoveryContext(app: app, requirements: requirements),
  );
  final dependencyGraph = const DependencyGraphBuilder().build(
    featureGraph.nodes.map((n) => n.candidate).toList(),
  );
  final context = SolutionExplorationContext(
    app: app,
    featureGraph: featureGraph,
    dependencyGraph: dependencyGraph,
  );
  final baseline = _refinementPlanner
      .refine(_architecturePlanner.plan(app))
      .finalCandidate;

  test('a clean candidate list is approved with a single review pass', () {
    final a = _generator
        .build(
          baseline: baseline,
          variation: ArchitectureVariation(
            label: 'A',
            navigationTopology: NavigationTopology.hierarchical,
            capabilityRichness: CapabilityRichness.full,
            offlineStrategy: baseline.offline.capability,
            synchronizationStrategy: baseline.synchronization.strategy,
            rationale: 'r',
          ),
          context: context,
        )
        .copyWith(score: _score(0.8));
    final history = const SolutionRefinement().refine([a]);
    expect(history.outcome, SolutionRefinementOutcome.approved);
    expect(history.reviewHistory, hasLength(1));
  });

  test('drops a structurally-impossible candidate and approves the rest', () {
    final good = _generator
        .build(
          baseline: baseline,
          variation: ArchitectureVariation(
            label: 'Good',
            navigationTopology: NavigationTopology.hierarchical,
            capabilityRichness: CapabilityRichness.full,
            offlineStrategy: baseline.offline.capability,
            synchronizationStrategy: baseline.synchronization.strategy,
            rationale: 'r',
          ),
          context: context,
        )
        .copyWith(score: _score(0.8));
    final impossible = _generator
        .build(
          baseline: baseline,
          variation: ArchitectureVariation(
            label: 'Impossible',
            navigationTopology: NavigationTopology.hierarchical,
            capabilityRichness: CapabilityRichness.full,
            offlineStrategy: OfflineCapability.onlineRequired,
            synchronizationStrategy: baseline.synchronization.strategy,
            rationale: 'r',
          ),
          context: context,
        )
        .copyWith(score: _score(0.8));

    final history = const SolutionRefinement().refine([good, impossible]);
    expect(history.outcome, SolutionRefinementOutcome.approved);
    expect(history.finalCandidates.map((c) => c.label), ['Good']);
  });

  test('never drops every candidate even if all are duplicates', () {
    final a = _generator
        .build(
          baseline: baseline,
          variation: ArchitectureVariation(
            label: 'A',
            navigationTopology: NavigationTopology.hierarchical,
            capabilityRichness: CapabilityRichness.full,
            offlineStrategy: baseline.offline.capability,
            synchronizationStrategy: baseline.synchronization.strategy,
            rationale: 'r',
          ),
          context: context,
        )
        .copyWith(score: _score(0.8));
    final b = _generator
        .build(
          baseline: baseline,
          variation: ArchitectureVariation(
            label: 'B',
            navigationTopology: NavigationTopology.hierarchical,
            capabilityRichness: CapabilityRichness.full,
            offlineStrategy: baseline.offline.capability,
            synchronizationStrategy: baseline.synchronization.strategy,
            rationale: 'r',
          ),
          context: context,
        )
        .copyWith(score: _score(0.8));

    final history = const SolutionRefinement().refine([a, b]);
    expect(history.finalCandidates, isNotEmpty);
  });
}
